// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../extensions.dart';
import '../patterns.dart';
import 'block_syntax.dart';

@Deprecated('Use AtxHeadingSyntax instead')
class HeaderSyntax extends AtxHeadingSyntax {}

/// Parses atx-style headers: `## Header ##`.
class AtxHeadingSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const AtxHeadingSyntax();

  @override
  Node parse(BlockParser parser) {
    final lineEnding = parser.current.lineEnding;
    final tokens = tokenize(parser.current);

    parser.advance();

    final level = tokens[0]!.length;
    final contents = <Node>[];
    if (tokens[1] != null) {
      if (tokens[2] != null || !RegExp(r'^#+$').hasMatch(tokens[1]!.text)) {
        contents.add(UnparsedContent.fromSpan(tokens[1]!.trim()));
      }
    }

    return Element(
      'atxHeading',
      markers: [
        tokens[0]!,
        if (tokens[2] != null) tokens[2]!,
      ],
      children: contents,
      lineEndings: [if (lineEnding != null) lineEnding],
      attributes: {'level': '$level'},
    );
  }
}
