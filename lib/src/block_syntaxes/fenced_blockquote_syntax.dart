// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses lines fenced by `>>>` to blockquotes
class FencedBlockquoteSyntax extends BlockSyntax {
  const FencedBlockquoteSyntax();

  @override
  RegExp get pattern => blockquoteFencePattern;

  BlockSyntaxChildSource parseChildLines(BlockParser parser) {
    final lines = <Line>[];
    final markders = [parser.current.content];
    final lineEndings = [parser.current.lineEnding!];

    parser.advance();

    while (!parser.isDone) {
      final match = parser.current.hasMatch(pattern);
      if (!match) {
        lines.add(parser.current);
        parser.advance();
      } else {
        markders.add(parser.current.content);
        if (parser.current.lineEnding != null) {
          lineEndings.add(parser.current.lineEnding!);
        }
        parser.advance();
        break;
      }
    }

    return BlockSyntaxChildSource(
      lines: lines,
      markers: markders,
      lineEndings: lineEndings,
    );
  }

  @override
  Node? parse(BlockParser parser) {
    final childSource = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(
      childSource.lines,
      parser.document,
    ).parseLines();

    return Element(
      'fencedBlockquote',
      children: children,
      lineEndings: childSource.lineEndings,
      markers: childSource.markers,
    );
  }
}
