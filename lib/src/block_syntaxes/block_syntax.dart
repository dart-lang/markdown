// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../token.dart';

abstract class BlockSyntax {
  const BlockSyntax();

  /// Gets the regex used to identify the beginning of this block, if any.
  RegExp get pattern;

  List<Token> tokenize(BlockParser parser) {
    final match = pattern.firstMatch(parser.current.text)!;

    return parseTokensFromMatch(
      match,
      text: parser.current.text,
      offset: parser.current.start.offset,
      line: parser.line,
    );
  }

  bool canEndBlock(BlockParser parser) => true;

  bool canParse(BlockParser parser) {
    return pattern.hasMatch(parser.current.text);
  }

  Node? parse(BlockParser parser);

  /// Gets whether or not [parser]'s current line should end the previous block.
  static bool isAtBlockEnd(BlockParser parser) {
    if (parser.isDone) return true;
    return parser.blockSyntaxes
        .any((s) => s.canParse(parser) && s.canEndBlock(parser));
  }

  /// Generates a valid HTML anchor from the inner text of [element].
  static String generateAnchorHash(Element element) =>
      element.children.first.textContent
          .toLowerCase()
          .trim()
          .replaceAll(RegExp('[^a-z0-9 _-]'), '')
          .replaceAll(RegExp(r'\s'), '-');
}

class BlockSyntaxChildSource {
  final List<Token> markers;
  final List<SourceSpan> lines;

  BlockSyntaxChildSource(this.markers, this.lines);
}
