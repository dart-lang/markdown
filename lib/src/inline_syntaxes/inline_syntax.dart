// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../parsers/inline_parser.dart';

/// Represents one kind of Markdown tag that can be parsed.
abstract class InlineSyntax {
  final RegExp pattern;

  /// The first character of [pattern], to be used as an efficient first check
  /// that this syntax matches the current parser position.
  final int? _startCharacter;

  /// Create a new [InlineSyntax] which matches text on [pattern].
  ///
  /// If [startCharacter] is passed, it is used as a pre-matching check which
  /// is faster than matching against [pattern].
  /// the [pattern].
  InlineSyntax(
    this.pattern, {
    int? startCharacter,
  }) : _startCharacter = startCharacter;

  /// Tries to match at the postion [start] if is offered, otherwise start
  /// matching from parser's current position.
  Match? tryMatch(InlineParser parser, [int? start]) {
    start ??= parser.position;

    // Before matching with the regular expression [pattern], which can be
    // expensive on some platforms, check if even the first character matches
    // this syntax.
    if (_startCharacter != null && parser.charAt(start) != _startCharacter) {
      return null;
    }

    return parser.matchFromStart(pattern, start);
  }

  /// Possibly creating a [Node] and advancing [parser].
  Node? parse(InlineParser parser, Match match);
}
