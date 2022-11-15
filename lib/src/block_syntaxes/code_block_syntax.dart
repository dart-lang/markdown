// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks that are indented four spaces.
class CodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => indentPattern;

  @override
  bool canEndBlock(BlockParser parser) => false;

  const CodeBlockSyntax();

  @override
  List<String?> parseChildLines(BlockParser parser) {
    final childLines = <String?>[];

    while (!parser.isDone) {
      final isBlankLine = parser.current.isBlank;
      if (isBlankLine && _shouldEnd(parser)) {
        break;
      }

      if (!isBlankLine &&
          childLines.isNotEmpty &&
          pattern.hasMatch(parser.current) != true) {
        break;
      }
      childLines.add(parser.current.dedent().text);

      parser.advance();
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // The Markdown tests expect a trailing newline.
    childLines.add('');

    var content = childLines.join('\n');
    if (parser.document.encodeHtml) {
      content = escapeHtml(content);
    }

    return Element('pre', [Element.text('code', content)]);
  }

  bool _shouldEnd(BlockParser parser) {
    var i = 1;
    while (true) {
      final nextLine = parser.peek(i);
      // EOF
      if (nextLine == null) {
        return true;
      }

      // It does not matter how many blank lines between chunks:
      // https://spec.commonmark.org/0.30/#example-111
      if (nextLine.isBlank) {
        i++;
        continue;
      }

      return pattern.hasMatch(nextLine) == false;
    }
  }
}
