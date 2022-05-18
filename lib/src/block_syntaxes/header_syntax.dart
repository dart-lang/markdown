// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const HeaderSyntax();

  @override
  Node parse(BlockParser parser) {
    final start = parser.current.start;
    final end = parser.current.start;
    final tokens = tokenize(parser);

    parser.advance();

    final level = tokens[0].length;
    final contents = UnparsedContent.fromSpan(tokens[1].trim());

    return Element(
      'atxHeading',
      markers: [
        tokens[0],
        if (tokens.length == 3) tokens[2],
      ],
      children: [contents],
      start: start,
      end: end,
      attributes: {'level': '$level'},
    );
  }
}
