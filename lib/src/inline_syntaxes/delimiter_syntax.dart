// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../extensions.dart';
import '../parsers/inline_parser.dart';
import '../patterns.dart';
import 'inline_syntax.dart';

/// Matches syntax that has a pair of tags and becomes an element, like `*` for
/// `<em>`. Allows nested tags.
class DelimiterSyntax extends InlineSyntax {
  /// Whether this is parsed according to the same nesting rules as [emphasis
  /// delimiters][].
  ///
  /// [emphasis delimiters]: http://spec.commonmark.org/0.30/#can-open-emphasis
  final bool requiresDelimiterRun;

  /// Whether to allow intraword delimiter runs.
  ///
  /// CommonMark emphasis with `*` is
  /// permitted but disallowed for `_`.\
  /// GitHub-Flavored Markdown allows it on strikethrough.
  final bool allowIntraWord;

  final List<DelimiterTag>? tags;

  /// Creates a new [DelimiterSyntax] which matches text on [pattern].
  ///
  /// The [pattern] is used to find the matching text. If [requiresDelimiterRun]
  /// is passed, this syntax parses according to the same nesting rules as
  /// emphasis delimiters.  If [startCharacter] is passed, it is used as a
  /// pre-matching check which is faster than matching against [pattern].
  DelimiterSyntax(
    String pattern, {
    this.requiresDelimiterRun = false,
    int? startCharacter,
    this.allowIntraWord = false,
    this.tags,
  }) : super(RegExp(pattern), startCharacter: startCharacter);

  @override
  Node? parse(InlineParser parser, Match match) {
    final delimiterLength = match.match.length;
    final startPosition = parser.position;
    final endPosition = parser.position + delimiterLength;
    final delimiterNode = Text.fromSpan(
      parser.subspan(startPosition, endPosition).first,
    );

    if (!requiresDelimiterRun) {
      parser.pushDelimiter(SimpleDelimiter(
        node: delimiterNode,
        char: parser.charAt(startPosition),
        canOpen: true,
        canClose: false,
        syntax: this,
        startPosition: startPosition,
      ));
      parser.advanceBy(delimiterLength);
      return delimiterNode;
    }

    final delimiterRun = DelimiterRun.tryParse(
      parser,
      startPosition,
      endPosition,
      syntax: this,
      node: delimiterNode,
      allowIntraWord: allowIntraWord,
      tags: tags ?? [],
    );

    parser.advanceBy(delimiterLength);

    if (delimiterRun != null) {
      parser.pushDelimiter(delimiterRun);
      return delimiterNode;
    }

    return null;
  }

  /// Attempts to close this tag at the current position.
  ///
  /// If a tag cannot be closed at the current position (for example, if a link
  /// reference cannot be found for a link tag's label), then `null` is
  /// returned.
  ///
  /// If a tag can be closed at the current position, then this method calls
  /// [getChildren], in which [parser] parses any nested text into child nodes.
  /// The returned [Node] incorpororates these child nodes.
  Node? close(
    InlineParser parser,
    int startPosition, {
    required String type,
    required SourceSpan openMarker,
    required SourceSpan closeMarker,
    required List<Node> Function() getChildren,
  }) =>
      Element(
        type,
        children: getChildren(),
        markers: [openMarker, closeMarker],
      );
}

class DelimiterTag {
  final String type;
  final int indicatorLength;

  DelimiterTag(this.type, this.indicatorLength);
}

/// A delimiter indicating the possible "open" or possible "close" of a tag for
/// a [DelimiterSyntax].
abstract class Delimiter {
  /// The [Text] node representing the plain text representing this delimiter.
  Text get node;

  /// The type of delimiter.
  ///
  /// For the two-character image delimiter, `![`, this is `!`.
  int get char;

  /// The number of delimiters.
  int get length => node.length;

  /// The position where this [Delimiter] ends up in [InlineParser].
  int get startPosition;

  /// Whether the delimiter is active.
  ///
  /// Links cannot be nested, so we must "deactivate" any pending ones. For
  /// example, take the following text:
  ///
  ///     Text [link and [more](links)](links).
  ///
  /// Once we have parsed `Text [`, there is one (pending) link in the state
  /// stack.  It is, by default, active. Once we parse the next possible link,
  /// `[more](links)`, as a real link, we must deactive the pending links (just
  /// the one, in this case).
  abstract bool isActive;

  /// Whether this delimiter can open emphasis or strong emphasis.
  bool get canOpen;

  /// Whether this delimiter can close emphasis or strong emphasis.
  bool get canClose;

  /// The syntax which uses this delimiter to parse a tag.
  DelimiterSyntax get syntax;
}

/// A simple delimiter implements the [Delimiter] interface with basic fields,
/// and does not have the concept of "left-flanking" or "right-flanking".
class SimpleDelimiter extends Delimiter {
  @override
  Text node;

  @override
  final int char;

  @override
  bool isActive;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  @override
  final DelimiterSyntax syntax;

  @override
  final int startPosition;

  SimpleDelimiter({
    required this.node,
    required this.char,
    required this.canOpen,
    required this.canClose,
    required this.syntax,
    required this.startPosition,
  }) : isActive = true;
}

/// An implementation of [Delimiter] which uses concepts of "left-flanking" and
/// "right-flanking" to determine the values of [canOpen] and [canClose].
///
/// This is primarily used when parsing emphasis and strong emphasis, but can
/// also be used by other extensions of [DelimiterSyntax].
class DelimiterRun extends Delimiter {
  @override
  Text node;

  @override
  final int char;

  @override
  bool isActive;

  @override
  final DelimiterSyntax syntax;

  final bool allowIntraWord;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  @override
  final int startPosition;

  final List<DelimiterTag> tags;

  DelimiterRun._({
    required this.node,
    required this.char,
    required this.syntax,
    required this.tags,
    required bool isLeftFlanking,
    required bool isRightFlanking,
    required bool isPrecededByPunctuation,
    required bool isFollowedByPunctuation,
    required this.allowIntraWord,
    required this.startPosition,
  })  : canOpen = isLeftFlanking &&
            (!isRightFlanking || allowIntraWord || isPrecededByPunctuation),
        canClose = isRightFlanking &&
            (!isLeftFlanking || allowIntraWord || isFollowedByPunctuation),
        isActive = true;

  /// Tries to parse a delimiter run from [runStart] (inclusive) to [runEnd]
  /// (exclusive).
  static DelimiterRun? tryParse(
    InlineParser parser,
    int runStart,
    int runEnd, {
    required DelimiterSyntax syntax,
    required List<DelimiterTag> tags,
    required Text node,
    bool allowIntraWord = false,
  }) {
    bool precededByWhitespace;
    bool followedByWhitespace;
    bool precededByPunctuation;
    bool followedByPunctuation;

    if (runStart == 0) {
      precededByWhitespace = true;
      precededByPunctuation = false;
    } else {
      final preceding = parser.stringAt(runStart - 1);
      precededByWhitespace = unicodeWhitespaceCharacters.contains(preceding);
      precededByPunctuation = !precededByWhitespace &&
          unicodePunctuationPattern.hasMatch(preceding);
    }

    if (runEnd == parser.length) {
      followedByWhitespace = true;
      followedByPunctuation = false;
    } else {
      final following = parser.stringAt(runEnd);
      followedByWhitespace = unicodeWhitespaceCharacters.contains(following);
      followedByPunctuation = !followedByWhitespace &&
          unicodePunctuationPattern.hasMatch(following);
    }

    // If it is a left-flanking delimiter run, see
    // http://spec.commonmark.org/0.30/#left-flanking-delimiter-run.
    final leftFlanking = !followedByWhitespace &&
        (!followedByPunctuation ||
            precededByWhitespace ||
            precededByPunctuation);

    // If it is a right-flanking delimiter run, see
    // http://spec.commonmark.org/0.30/#right-flanking-delimiter-run.
    final rightFlanking = !precededByWhitespace &&
        (!precededByPunctuation ||
            followedByWhitespace ||
            followedByPunctuation);

    // Make sure the shorter delimiter takes precedence.
    tags.sort((a, b) => a.indicatorLength.compareTo(b.indicatorLength));

    return DelimiterRun._(
      node: node,
      char: parser.charAt(runStart),
      syntax: syntax,
      tags: tags,
      startPosition: runStart,
      isLeftFlanking: leftFlanking,
      isRightFlanking: rightFlanking,
      isPrecededByPunctuation: precededByPunctuation,
      isFollowedByPunctuation: followedByPunctuation,
      allowIntraWord: allowIntraWord,
    );
  }

  @override
  String toString() => '<char: $char, length: $length, canOpen: $canOpen, '
      'canClose: $canClose>';
}
