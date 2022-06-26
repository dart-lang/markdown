// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../extensions.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks that are indented four spaces.
class CodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => indentPattern;

  @override
  bool canInterrupt(BlockParser parser) => false;

  const CodeBlockSyntax();

  bool _shouldEndBlankLine(BlockParser parser) {
    var i = 1;
    while (true) {
      final nextLine = parser.peek(i);
      if (nextLine == null) {
        return true;
      }

      if (nextLine.isBlankLine) {
        i++;
        continue;
      }

      return nextLine.hasMatch(pattern) == false;
    }
  }

  BlockSyntaxChildSource parseChildLines(BlockParser parser) {
    final lines = <Line>[];

    while (!parser.isDone) {
      if (parser.current.isBlankLine && _shouldEndBlankLine(parser)) {
        break;
      }

      if (lines.isNotEmpty &&
          !parser.current.isBlankLine &&
          parser.current.hasMatch(pattern) != true) {
        break;
      }

      lines.add(Line(
        parser.current.content.indent().span,
        lineEnding: parser.current.lineEnding,
        tabRemaining: parser.current.tabRemaining,
      ));

      parser.advance();
    }

    return BlockSyntaxChildSource(
      lines: lines,
      markers: [],
    );
  }

  @override
  Node parse(BlockParser parser) {
    final childSource = parseChildLines(parser);

    final codeLines = childSource.lines.map<Node>((line) {
      var span = line.content;
      if (line.lineEnding != null) {
        span = span.union(line.lineEnding!);
      }

      return Text.fromSpan(
        span,
        tabRemaining: line.tabRemaining,
      );
    }).toList();

    return Element(
      'indentedCodeBlock',
      children: codeLines,
    );
  }
}
