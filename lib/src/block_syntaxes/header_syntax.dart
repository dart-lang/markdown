// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  @override
  RegExp get patternWithHelper => headerPatternWithHelper;

  const HeaderSyntax();

  @override
  Node parse(BlockParser parser) {
    final match = parser.matches(parser.current, this)!;
    parser.advance();

    final marker = match.namedGroup('marker')!;
    final level = marker.length;
    final text = match.namedGroup('text')!;
    final children = <Node>[];

    if (!parser.isHelperPatternActive(this)) {
      children.addAll([
        UnparsedContent(text.trim()),
      ]);
    } else {
      children.addAll([
        if (match[1]!.isNotEmpty) Helper.whitespace(match[1]!),
        Helper.marker(marker),
        if (match[3]!.isNotEmpty) Helper.whitespace(match[3]!),
        UnparsedContent(text),
        if (match[5]!.isNotEmpty) Helper.whitespace(match[5]!),
        if (match[6]!.isNotEmpty) Helper.marker(match[6]!),
        if (!parser.isDone) Helper.newLine(),
      ]);
    }

    return Element('h$level', children);
  }
}
