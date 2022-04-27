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
    if (!_interperableAsParagraph(parser.current)) return false;
    var i = 1;
    while (true) {
      final nextLine = parser.peek(i);
      if (nextLine == null) {
        // We never reached an underline.
        return false;
      }
      if (setextPattern.hasMatch(nextLine)) {
        return true;
      }
      // Ensure that we're still in something like paragraph text.
      if (!_interperableAsParagraph(nextLine)) {
        return false;
      }
      i++;
    }
  }

  @override
  Node parse(BlockParser parser) {
    final lines = <String>[];
    String? tag;
    while (!parser.isDone) {
      final match = setextPattern.firstMatch(parser.current);
      if (match == null) {
        // More text.
        lines.add(parser.current);
        parser.advance();
        continue;
      } else {
        // The underline.
        tag = (match[1]![0] == '=') ? 'h1' : 'h2';
        parser.advance();
        break;
      }
    }

    final contents = UnparsedContent(lines.join('\n').trimRight());

    return Element(tag!, [contents]);
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
