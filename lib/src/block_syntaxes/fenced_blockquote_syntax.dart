// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses lines fenced by `>>>` to blockquotes
class FencedBlockquoteSyntax extends BlockSyntax {
  const FencedBlockquoteSyntax();

  @override
  RegExp get pattern => blockquoteFencePattern;

  BlockSyntaxChildSource parseChildLines(BlockParser parser) {
    final childLines = <SourceSpan>[];
    parser.advance();

    while (!parser.isDone) {
      final match = pattern.hasMatch(parser.current.text);
      if (!match) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    return BlockSyntaxChildSource([], childLines);
  }

  @override
  Node? parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(
      childLines.lines,
      parser.document,
    ).parseLines();
    return Element.todo('fencedBlockquote', children: children);
  }
}
