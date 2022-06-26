// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../line.dart';
import '../parsers/block_parser.dart';

abstract class BlockSyntax {
  const BlockSyntax();

  /// Gets the regex used to identify the beginning of this block, if any.
  RegExp get pattern;

  /// If can interrupt a block.
  bool canInterrupt(BlockParser parser) => true;

  bool canParse(BlockParser parser) => parser.current.hasMatch(pattern);

  Node? parse(BlockParser parser);

  /// Returns the block which interrupts current syntax parsing if there is one,
  /// otherwise returns `null`.
  ///
  /// Make sure to check if [parser] `isDone` is `false` first.
  BlockSyntax? interruptedBy(BlockParser parser) {
    for (final syntax in parser.blockSyntaxes) {
      if (syntax.canParse(parser) && syntax.canInterrupt(parser)) {
        return syntax;
      }
    }

    return null;
  }

  /// If should end the current syntax parseing.
  bool shouldEnd(BlockParser parser) =>
      parser.isDone || interruptedBy(parser) != null;

  /// Generates a valid HTML anchor from the inner text of [element].
  static String generateAnchorHash(Element element) =>
      element.children.first.textContent
          .toLowerCase()
          .trim()
          .replaceAll(RegExp('[^a-z0-9 _-]'), '')
          .replaceAll(RegExp(r'\s'), '-');
}

class BlockSyntaxChildSource {
  final List<SourceSpan> markers;
  final List<Line> lines;

  /// If the lines is ending up with a lazy continuation line.
  final bool lazyEnding;

  BlockSyntaxChildSource({
    this.markers = const [],
    this.lines = const [],
    this.lazyEnding = false,
  });
}
