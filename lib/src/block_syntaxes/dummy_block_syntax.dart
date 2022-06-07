// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Walks the parser forward through the lines does not match any [BlockSyntax].
///
/// Returns a [UnparsedContent] with the unmatched lines as `textContent`.
class DummyBlockSyntax extends BlockSyntax {
  const DummyBlockSyntax();

  @override
  RegExp get pattern => dummyPattern;

  @override
  bool canInterrupt(BlockParser parser) => false;

  @override
  bool canParse(BlockParser parser) => true;

  @override
  Node? parse(BlockParser parser) {
    final childLines = <Line>[];

    while (!shouldEnd(parser)) {
      childLines.add(parser.current);
      parser.advance();
    }

    final content = childLines.toNodes(
      (span) => UnparsedContent.fromSpan(span),
      popLineEnding: true,
    );

    if (content.nodes.isEmpty) {
      return null;
    }
    assert(content.nodes.length == 1);
    return content.nodes.first;
  }
}
