// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import '../token.dart';
import 'block_syntax.dart';

/// Parses horizontal rules like `---`, `_ _ _`, `*  *  *`, etc.
class HorizontalRuleSyntax extends BlockSyntax {
  @override
  RegExp get pattern => hrPattern;

  const HorizontalRuleSyntax();

  @override
  Node parse(BlockParser parser) {
    final start = parser.current.start;
    final end = parser.current.end;
    final marker = Token(parser.current.text, start: start, end: end);

    parser.advance();

    return Element(
      'thematicBreak',
      markers: [marker.trim()],
      start: start,
      end: end,
    );
  }
}
