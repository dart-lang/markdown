// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'patterns.dart';

/// A [Line] is a sequence of zero or more characters other than line feed
/// (`U+000A`) or carriage return (`U+000D`), followed by a line ending or by
/// the end of file.
// See https://spec.commonmark.org/0.30/#line.
class Line {
  /// A sequence of zero or more characters other than the line ending.
  final String content;

  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  final int? tabRemaining;

  // A line containing no characters, or a line containing only spaces
  // (`U+0020`) or tabs (`U+0009`), is called a blank line.
  // https://spec.commonmark.org/0.30/#blank-line
  bool get isBlankLine => emptyPattern.hasMatch(content);

  const Line(
    this.content, {
    this.tabRemaining,
  });

  Map<String, dynamic> toMap() => {
        'content': content,
        'isBlankLine': isBlankLine,
        if (tabRemaining != null) 'tabRemaining': tabRemaining,
      };
}
