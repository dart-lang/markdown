// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../extensions.dart';
import '../parsers/inline_parser.dart';
import 'inline_syntax.dart';

/// Matches stuff that should just be passed through as straight text.
class TextSyntax extends InlineSyntax {
  TextSyntax(String pattern, {int? startCharacter})
      : super(RegExp(pattern, multiLine: true), startCharacter: startCharacter);

  @override
  Node? parse(InlineParser parser, Match match) {
    parser.advanceBy(match.match.length);
    return null;
  }
}
