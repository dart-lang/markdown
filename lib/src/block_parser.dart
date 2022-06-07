// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import 'ast.dart';
import 'block_syntaxes/atx_heading_syntax.dart';
import 'block_syntaxes/blank_line_syntax.dart';
import 'block_syntaxes/block_syntax.dart';
import 'block_syntaxes/blockquote_syntax.dart';
import 'block_syntaxes/code_block_syntax.dart';
import 'block_syntaxes/dummy_block_syntax.dart';
import 'block_syntaxes/html_block_syntax.dart';
import 'block_syntaxes/ordered_list_syntax.dart';
import 'block_syntaxes/paragraph_syntax.dart';
import 'block_syntaxes/setext_heading_syntax.dart';
import 'block_syntaxes/thematic_break_syntax.dart';
import 'block_syntaxes/unordered_list_syntax.dart';
import 'document.dart';
import 'extensions.dart';

/// Maintains the internal state needed to parse a series of lines into blocks
/// of Markdown suitable for further inline parsing.
class BlockParser {
  final List<Line> _lines;

  /// The Markdown document this parser is parsing.
  final Document document;

  /// The enabled block syntaxes.
  ///
  /// To turn a series of lines into blocks, each of these will be tried in
  /// turn. Order matters here.
  final List<BlockSyntax> blockSyntaxes = [];

  /// Index of the current line.
  int _pos = 0;

  /// Whether the parser has encountered a blank line between two block-level
  /// elements.
  bool encounteredBlankLine = false;

  /// The collection of built-in block parsers.
  final List<BlockSyntax> standardBlockSyntaxes = [
    const BlankLineSyntax(),
    const HtmlBlockSyntax(),
    const SetextHeadingSyntax(),
    const AtxHeadingSyntax(),
    const CodeBlockSyntax(),
    const BlockquoteSyntax(),
    const ThematicBreakSyntax(),
    const UnorderedListSyntax(),
    const OrderedListSyntax(),
    const ParagraphSyntax()
  ];

  BlockParser(List<Line> lines, this.document) : _lines = lines {
    blockSyntaxes.addAll(document.blockSyntaxes);
    if (document.withDefaultBlockSyntaxes) {
      blockSyntaxes.addAll(standardBlockSyntaxes);
    } else {
      blockSyntaxes.add(const DummyBlockSyntax());
    }
  }

  /// Gets the current line.
  Line get current => _lines[_pos];

  /// Gets the line after the current one or `null` if there is none.
  Line? get next {
    // Don't read past the end.
    if (_pos >= _lines.length - 1) return null;
    return _lines[_pos + 1];
  }

  /// Gets the line that is [linesAhead] lines ahead of the current one, or
  /// `null` if there is none.
  ///
  /// `peek(0)` is equivalent to [current].
  ///
  /// `peek(1)` is equivalent to [next].
  Line? peek(int linesAhead) {
    if (linesAhead < 0) {
      throw ArgumentError('Invalid linesAhead: $linesAhead; must be >= 0.');
    }
    // Don't read past the end.
    if (_pos >= _lines.length - linesAhead) return null;
    return _lines[_pos + linesAhead];
  }

  /// Temporarily stores the lines of the current syntax.
  final List<Line> linesBuffer = [];

  /// The [BlockSyntax] which is running now.
  BlockSyntax? get currentSyntax => _currentSyntax;
  BlockSyntax? _currentSyntax;

  /// The parent [BlockSyntax] when it is running in a nested syntax.
  BlockSyntax? get parentSyntax => _parentSyntax;
  BlockSyntax? _parentSyntax;

  /// If the [SetextHeadingSyntax] is disabled temporarily
  bool get setextHeadingDisabled => _setextHeadingDisabled;
  bool _setextHeadingDisabled = false;

  bool get isDone => _pos >= _lines.length;

  void advance() {
    _pos++;
  }

  void setLine(int line) => _pos = line;

  List<Node> parseLines({
    bool disabledSetextHeading = false,
    BlockSyntax? fromSyntax,
  }) {
    _setextHeadingDisabled = disabledSetextHeading;
    _parentSyntax = fromSyntax;

    final blocks = <Node>[];
    while (!isDone) {
      for (final syntax in blockSyntaxes) {
        if (syntax.canParse(this)) {
          _currentSyntax = syntax;
          final block = syntax.parse(this);
          if (block != null) blocks.add(block);
          break;
        }
      }
    }

    return blocks;
  }
}

// The definition of line:
// https://spec.commonmark.org/0.30/#line
class Line {
  /// A sequence of zero or more characters other than [lineEnding].
  final SourceSpan content;

  // The definition of line ending:
  // https://spec.commonmark.org/0.30/#line-ending
  // In our case there is only line feed, because the carriage return must have
  // been replaced with line feed.
  final SourceSpan? lineEnding;

  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  final int? tabRemaining;

  // The definition of blank line:
  // https://spec.commonmark.org/0.30/#blank-line
  bool get isBlankLine => content.text.trim().isEmpty;

  /// The start location of this [Line].
  SourceLocation get start => content.start;

  /// The end location of this [Line], exclusive.
  SourceLocation get end => lineEnding?.end ?? content.end;

  /// String line content ending with a line ending if there is one.
  String get text =>
      "${content.text}${lineEnding == null ? '' : lineEnding!.text}";

  const Line(
    this.content, {
    this.lineEnding,
    this.tabRemaining,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'content': content.toMap(),
        'lineEnding': lineEnding?.toMap(),
        'start': start.toMap(),
        'end': end.toMap(),
        'isBlankLine': isBlankLine,
        'tabRemaining': tabRemaining,
      };

  Match? firstMatch(RegExp pattern) => pattern.firstMatch(content.text);

  Match? matchAsPrefix(RegExp pattern, [int start = 0]) =>
      pattern.matchAsPrefix(content.text, start);

  bool hasMatch(RegExp pattern) => pattern.hasMatch(content.text);

  bool startsWith(Pattern pattern, [int index = 0]) =>
      content.text.startsWith(pattern, index);

  @override
  String toString() => toMap().toPrettyString();
}

extension LineListExtensions on List<Line> {
  List<SourceSpan> toSourceSpans() {
    final spans = <SourceSpan>[];
    for (final line in this) {
      spans.add(line.content);
      if (line.lineEnding != null) {
        spans.add(line.lineEnding!);
      }
    }
    return spans;
  }

  /// Converts a [Line] list to a AST [Node] list.
  ///
  /// Set [trimLeading] to `true` to remove leading whitespaces of the first
  /// node.
  ///
  /// Set [trimTrailing] to `true` to remove trailing whitespaces of the last
  /// node.
  ///
  /// Set [popLineEnding] to `true` to remove the line ending of the last [Line]
  /// and return this lineEnding in [_SourceFromLineList].
  _SourceFromLineList toNodes(
    Node Function(SourceSpan span) transfer, {
    bool trimLeading = false,
    bool trimTrailing = false,
    bool popLineEnding = false,
  }) {
    final spans = toSourceSpans();
    SourceSpan? lineEnding;
    if (popLineEnding) {
      lineEnding = spans.last.text == '\n' ? spans.removeLast() : null;
    }

    if (trimLeading) {
      spans.first = spans.first.trimLeft();
    }

    if (trimTrailing) {
      spans.last = spans.last.trimRight();
    }

    final nodes = spans.concatWhilePossible().map<Node>(transfer).toList();
    return _SourceFromLineList(nodes, lineEnding);
  }
}

class _SourceFromLineList {
  final List<Node> nodes;
  final SourceSpan? lineEnding;

  _SourceFromLineList(this.nodes, this.lineEnding);
}
