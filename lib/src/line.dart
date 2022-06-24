// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import 'ast.dart';
import 'extensions.dart';
import 'patterns.dart';

// A line is a sequence of zero or more characters other than line feed
// (`U+000A`) or carriage return (`U+000D`), followed by a line ending or by
// the end of file.
//
// NOTE: This package has removed carriage return before processing.
// See https://spec.commonmark.org/0.30/#line.
class Line {
  /// A sequence of zero or more characters other than [lineEnding].
  final SourceSpan content;

  // A line ending is a line feed (`U+000A`), a carriage return (`U+000D`) not
  // followed by a line feed, or a carriage return and a following line feed.
  // See https://spec.commonmark.org/0.30/#line-ending.
  // In our case there is only a line feed.
  /// A [SourceSpan] contains only a line feed (`U+000A`).
  final SourceSpan? lineEnding;

  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  final int? tabRemaining;

  // A line containing no characters, or a line containing only spaces
  // (`U+0020`) or tabs (`U+0009`), is called a blank line.
  // https://spec.commonmark.org/0.30/#blank-line
  bool get isBlankLine => emptyPattern.hasMatch(content.text);

  /// The start location of this [Line].
  SourceLocation get start => content.start;

  /// The end location of this [Line], exclusive.
  SourceLocation get end => lineEnding?.end ?? content.end;

  /// String line content ending with a line ending if there is one.
  String get text =>
      "${content.text}${lineEnding == null ? '' : lineEnding!.text}";

  Line(
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
  /// Extracts a list of [Line] lines to [SourceSpan] spans.
  ///
  /// NOTE: This method just simply output the content spans and line ending
  /// spans of lines, **_it does not combine the adjacent spans._**
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
  /// Set [trimLeft] to `true` to remove leading whitespaces of the each line.
  ///
  /// Set [trimLeading] to `true` to remove leading whitespaces of the first
  /// line.
  ///
  /// Set [trimTrailing] to `true` to remove trailing whitespaces of the last
  /// line(The line ending will be kept, set [popLineEnding] to `true` to
  /// remove the final line ending).
  ///
  /// Set [popLineEnding] to `true` to remove the line ending of the last [Line]
  /// and return this lineEnding in [_SourceFromLineList].
  _SourceFromLineList toNodes(
    Node Function(SourceSpan span) transfer, {
    bool trimLeft = false,
    bool trimLeading = false,
    bool trimTrailing = false,
    bool popLineEnding = false,
  }) {
    if (isEmpty) {
      return _SourceFromLineList(<Node>[], null);
    }
    var spans = toSourceSpans();

    // Pop the line ending from `spans` if there is one, no matter
    // `popLineEnding` parameter is `true` or `false`.
    // Otherwise the trimRight() later will trim only the line ending span if
    // the last span is a line ending span.
    final lineEnding = spans.last.isLineFeed ? spans.removeLast() : null;

    if (spans.isNotEmpty) {
      if (trimLeft) {
        spans = spans
            .map((span) => span.isLineFeed ? span : span.trimLeft())
            .toList();
      } else if (trimLeading) {
        spans.first = spans.first.trimLeft();
      }

      if (trimTrailing) {
        spans.last = spans.last.trimRight();
      }
    }

    // Put the line ending span back if `popLineEnding` is `false`.
    if (!popLineEnding && lineEnding != null) {
      spans.add(lineEnding);
    }

    final nodes = spans.concatWhilePossible().map<Node>(transfer).toList();
    return _SourceFromLineList(nodes, popLineEnding ? lineEnding : null);
  }

  List<Line> fromString() {
    return [];
  }
}

class _SourceFromLineList {
  final List<Node> nodes;
  final SourceSpan? lineEnding;

  _SourceFromLineList(this.nodes, this.lineEnding);
}
