// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

class HtmlBlockSyntax extends BlockSyntax {
  const HtmlBlockSyntax();

  static final _endConditions = [
    // For condition 1, it does not need to match the start tag, see
    // https://spec.commonmark.org/0.30/#end-condition
    RegExp('</(?:pre|script|style|textarea)>', caseSensitive: false),
    RegExp('-->'),
    RegExp(r'\?>'),
    RegExp('>'),
    RegExp(']]>'),
    emptyPattern,
    emptyPattern,
  ];

  @override
  RegExp get pattern => htmlBlockPattern;

  @override
  bool canInterrupt(BlockParser parser) =>
      parser.current.firstMatch(pattern)![7] == null;

  BlockSyntaxChildSource parseChildLines(BlockParser parser) {
    final lines = <Line>[];

    final match = parser.current.firstMatch(pattern);
    var matchedCondition = 0;
    for (var i = 0; i < match!.groupCount; i++) {
      if (match.group(i + 1) != null) {
        matchedCondition = i;
        break;
      }
    }

    final endCondition = _endConditions[matchedCondition];

    if (endCondition == emptyPattern) {
      lines.add(parser.current);
      parser.advance();

      while (!parser.isDone && !parser.current.hasMatch(endCondition)) {
        lines.add(parser.current);
        parser.advance();
      }
    } else {
      while (!parser.isDone) {
        lines.add(parser.current);
        if (parser.current.hasMatch(endCondition)) {
          break;
        }
        parser.advance();
      }
      parser.advance();
    }

    // If the following lines start a HTML block again, put them together with
    // current HTML block.
    if (!parser.isDone && (parser.next?.hasMatch(pattern) ?? false)) {
      parser.advance();
      final childLines = parseChildLines(parser);
      lines.addAll(childLines.lines);
    }

    return BlockSyntaxChildSource(
      lines: lines,
    );
  }

  @override
  Node parse(BlockParser parser) {
    final childSource = parseChildLines(parser);

    final content = childSource.lines.toNodes(
      (span) => Text.fromSpan(span),
      popLineEnding: true,
    );

    return Element(
      'htmlBlock',
      children: content.nodes,
    );
  }
}
