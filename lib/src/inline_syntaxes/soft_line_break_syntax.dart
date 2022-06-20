// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../parsers/inline_parser.dart';
import 'inline_syntax.dart';

/// The only thing this syntax does is removing the one space line ending.
class SoftLineBreakSyntax extends InlineSyntax {
  SoftLineBreakSyntax() : super(RegExp(' \n'), startCharacter: $space);

  @override
  Node? parse(InlineParser parser, Match match) {
    parser.skipWhitespace();
    return null;
  }
}
