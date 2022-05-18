// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses setext-style headers.
class SetextHeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => dummyPattern;

  const SetextHeaderSyntax();

  @override
  bool canParse(BlockParser parser) {
    if (!_interperableAsParagraph(parser.current.text)) return false;
    var i = 1;
    while (true) {
      final nextLine = parser.peek(i);
      if (nextLine == null) {
        // We never reached an underline.
        return false;
      }
      if (setextPattern.hasMatch(nextLine.text)) {
        return true;
      }
      // Ensure that we're still in something like paragraph text.
      if (!_interperableAsParagraph(nextLine.text)) {
        return false;
      }
      i++;
    }
  }

  @override
  Node parse(BlockParser parser) {
    final lines = <String>[];
    String? level;
    while (!parser.isDone) {
      final match = setextPattern.firstMatch(parser.current.text);
      if (match == null) {
        // More text.
        lines.add(parser.current.text);
        parser.advance();
        continue;
      } else {
        // The underline.
        level = (match[1]![0] == '=') ? '1' : '2';
        parser.advance();
        break;
      }
    }

    final contents = UnparsedContent.todo(lines.join('\n').trimRight());

    return Element.todo(
      'setextHeading',
      children: [contents],
      attributes: {'level': level!},
    );
  }

  bool _interperableAsParagraph(String line) =>
      !(indentPattern.hasMatch(line) ||
          codeFencePattern.hasMatch(line) ||
          headerPattern.hasMatch(line) ||
          blockquotePattern.hasMatch(line) ||
          hrPattern.hasMatch(line) ||
          ulPattern.hasMatch(line) ||
          olPattern.hasMatch(line) ||
          emptyPattern.hasMatch(line));
}
