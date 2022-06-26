// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../extensions.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

@Deprecated('Use ThematicBreakSyntax instead')
class HorizontalRuleSyntax extends ThematicBreakSyntax {}

/// Parses horizontal rules like `---`, `_ _ _`, `*  *  *`, etc.
class ThematicBreakSyntax extends BlockSyntax {
  @override
  RegExp get pattern => hrPattern;

  const ThematicBreakSyntax();

  @override
  Node parse(BlockParser parser) {
    final marker = parser.current.content;

    parser.advance();

    return Element(
      'thematicBreak',
      markers: [marker.trim()],
    );
  }
}
