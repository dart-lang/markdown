// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import 'block_html_syntax.dart';

/// A BlockHtmlSyntax that has a specific `endPattern`.
///
/// In practice this means that the syntax dominates; it is allowed to eat
/// many lines, including blank lines, before matching its `endPattern`.
class LongBlockHtmlSyntax extends BlockHtmlSyntax {
  @override
  final RegExp pattern;
  final RegExp _endPattern;

  LongBlockHtmlSyntax(String pattern, String endPattern)
      : pattern = RegExp(pattern),
        _endPattern = RegExp(endPattern);

  @override
  Node parse(BlockParser parser) {
    final childLines = <String>[];
    // Eat until we hit [endPattern].
    while (!parser.isDone) {
      childLines.add(parser.current);
      if (parser.matches(_endPattern)) break;
      parser.advance();
    }

    parser.advance();
    return Text(childLines.join('\n').trimRight());
  }
}
