// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../extensions.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

@Deprecated('Use BlankLineSyntax instead')
class EmptyBlockSyntax extends BlankLineSyntax {}

// A line containing no characters, or a line containing only spaces (`U+0020`)
// or tabs (`U+0009`), is called a blank line.
// See https://spec.commonmark.org/0.30/#blank-line.
class BlankLineSyntax extends BlockSyntax {
  @override
  RegExp get pattern => emptyPattern;

  const BlankLineSyntax();

  @override
  Node? parse(BlockParser parser) {
    parser.encounteredBlankLine = true;
    final lineEndings = <SourceSpan>[];

    lineEndings.addIfNotNull(parser.current.lineEnding);
    parser.advance();

    while (!parser.isDone && parser.current.hasMatch(pattern)) {
      lineEndings.addIfNotNull(parser.current.lineEnding);
      parser.advance();
    }

    return Element(
      'blankLine',
      lineEndings: lineEndings,
    );
  }
}
