// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parse HTML blocks.
// There are seven kinds of HTML block defined in the CommonMark spec:
// https://spec.commonmark.org/0.30/#html-blocks.
// These matching conditions and HTML block types mentioned in this syntax
// correspond to these ones in the CommonMark spec.
class HtmlBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => htmlBlockPattern;

  // All types of HTML blocks except type 7 may interrupt a paragraph, see the
  // second paragraph after https://spec.commonmark.org/0.30/#example-148 for
  // more detail.
  @override
  bool canEndBlock(BlockParser parser) =>
      pattern.firstMatch(parser.current)!.namedGroup('condition_7') == null;

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

  const HtmlBlockSyntax();

  @override
  List<String> parseChildLines(BlockParser parser) {
    final lines = <String>[];

    final match = pattern.firstMatch(parser.current);
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

      while (!parser.isDone && !endCondition.hasMatch(parser.current)) {
        lines.add(parser.current);
        parser.advance();
      }
    } else {
      while (!parser.isDone) {
        lines.add(parser.current);
        if (endCondition.hasMatch(parser.current)) {
          break;
        }
        parser.advance();
      }
      parser.advance();
    }

    // If the following lines start an HTML block again, put them together with
    // current HTML block.
    if (!parser.isDone &&
        parser.next != null &&
        pattern.hasMatch(parser.next!)) {
      parser.advance();
      lines.addAll(parseChildLines(parser));
    }

    return lines;
  }

  @override
  Node parse(BlockParser parser) {
    final childLines = parseChildLines(parser);
    return Text(childLines.join('\n').trimRight());
  }
}
