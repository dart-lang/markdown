// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../document.dart';
import '../inline_syntaxes/autolink_syntax.dart';
import '../inline_syntaxes/backslash_escape_syntax.dart';
import '../inline_syntaxes/code_syntax.dart';
import '../inline_syntaxes/delimiter_syntax.dart';
import '../inline_syntaxes/emphasis_syntax.dart';
import '../inline_syntaxes/hard_line_break_syntax.dart';
import '../inline_syntaxes/image_syntax.dart';
import '../inline_syntaxes/inline_syntax.dart';
import '../inline_syntaxes/link_syntax.dart';
import '../inline_syntaxes/soft_line_break_syntax.dart';
import '../inline_syntaxes/text_syntax.dart';
import 'delimiter_processor.dart';
import 'source_parser.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
class InlineParser extends SourceParser {
  static final List<InlineSyntax> _defaultSyntaxes =
      List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    AutolinkSyntax(),
    HardLineBreakSyntax(),
    SoftLineBreakSyntax(),
    // Allow any punctuation to be escaped.
    BackslashEscapeSyntax(),
    // "*" surrounded by spaces is left alone.
    TextSyntax(r' \* ', startCharacter: $space),
    // "_" surrounded by spaces is left alone.
    TextSyntax(' _ ', startCharacter: $space),
    // Parse "**strong**" and "*emphasis*" tags.
    EmphasisSyntax.asterisk(),
    // Parse "__strong__" and "_emphasis_" tags.
    EmphasisSyntax.underscore(),
    CodeSyntax(),
    // We will add the LinkSyntax once we know about the specific link resolver.
  ]);

  /// The Markdown document this parser is parsing.
  final Document document;

  final List<InlineSyntax> syntaxes = <InlineSyntax>[];

  /// Starting position of the last unconsumed text.
  int _textStart = 0;

  late final DelimiterProcessor _delimiterProcessor;

  /// The tree of parsed HTML nodes.
  final _tree = <Node>[];

  InlineParser(List<UnparsedContent> source, this.document) : super(source) {
    // User specified syntaxes are the first syntaxes to be evaluated.
    syntaxes.addAll(document.inlineSyntaxes);

    // This first RegExp matches plain text to accelerate parsing. It's written
    // so that it does not match any prefix of any following syntaxes. Most
    // Markdown is plain text, so it's faster to match one RegExp per 'word'
    // rather than fail to match all the following RegExps at each non-syntax
    // character position.
    if (document.hasCustomInlineSyntaxes) {
      // We should be less aggressive in blowing past "words".
      syntaxes.add(TextSyntax(r'[A-Za-z0-9]+(?=\s)'));
    } else {
      syntaxes.add(TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9](?=\s)'));
    }

    if (document.withDefaultInlineSyntaxes) {
      // Custom link resolvers go after the generic text syntax.
      syntaxes.addAll([
        LinkSyntax(linkResolver: document.linkResolver),
        ImageSyntax(linkResolver: document.imageLinkResolver)
      ]);

      syntaxes.addAll(_defaultSyntaxes);
    }
  }

  List<Node> parse() {
    _delimiterProcessor = DelimiterProcessor(this, _tree);
    final neverMatch = <InlineSyntax>[];
    final hasLinkSyntax = (syntaxes.any(((e) => e is LinkSyntax)));
    int? dirtyPosition;

    while (!isDone) {
      // A right bracket (']') is special. Hitting this character triggers the
      // "look for link or image" procedure.
      // See https://spec.commonmark.org/0.29/#an-algorithm-for-parsing-nested-emphasis-and-links.
      if (hasLinkSyntax && charAt() == $rbracket) {
        writeText();
        if (_delimiterProcessor.buildLinkOrImage()) {
          _textStart = position;
        }
        continue;
      }

      // See if the current text matches any defined Markdown syntax.
      if (syntaxes.any((syntax) {
        if (dirtyPosition == position && neverMatch.contains(syntax)) {
          return false;
        }

        final match = syntax.tryMatch(this);
        if (match == null) {
          return false;
        }

        writeText();
        final positionBefore = position;
        final node = syntax.parse(this, match);

        // If the position was not changed after parsing, never match this
        // syntax again at the same position.
        //
        // It makes it possible that even though `tryMatch()` matched, the
        // `parse()` still have the chance to regret the match and leave the
        // matched content for other syntaxes.
        //
        // `EmojiSyntax` is an example of this feature.
        if (position > positionBefore) {
          neverMatch.clear();
        } else {
          dirtyPosition = position;
          neverMatch.add(syntax);
        }

        if (node != null) {
          _tree.add(node);
          _textStart = position;
        }

        return true;
      })) continue;

      advance();
    }

    // Write any trailing text content to a Text node.
    writeText();
    _delimiterProcessor.processDelimiterRun(-1);
    _combineAdjacentText(_tree);
    return _tree;
  }

  /// Combine all the adjacent [Text] nodes.
  void _combineAdjacentText(List<Node> nodes) {
    if (nodes.length < 2) {
      return;
    }

    Text? text;
    var startAt = 0;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];

      if (text != null && node is! Text) {
        nodes.replaceRange(startAt, i, [text]);
        i -= i - startAt;
        text = null;
      }

      if (node is Element) {
        _combineAdjacentText(node.children);
        continue;
      }

      if (node is Text) {
        if (text == null) {
          startAt = i;
          text = node;
        } else if (text.end.offset != node.start.offset) {
          nodes.replaceRange(startAt, i, [text]);
          i -= i - startAt;
          text = null;
        } else {
          text = text.concat(node);
        }
      }
    }
    if (text != null) {
      nodes.replaceRange(startAt, nodes.length, List<Text>.from([text]));
    }
  }

  void writeText() {
    if (position == _textStart) {
      return;
    }
    _tree.addAll(subspan(_textStart, position).map(
      (span) => Text.fromSpan(span),
    ));
    _textStart = position;
  }

  /// Skip a whitespace at current position.
  void skipWhitespace() {
    if (charAt() != $space || _textStart != position) {
      return;
    }
    advance();
    _textStart = position;
  }

  /// Push [delimiter] onto the stack of [Delimiter]s.
  void pushDelimiter(Delimiter delimiter) =>
      _delimiterProcessor.pushDelimiter(delimiter);
}
