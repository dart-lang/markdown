// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import '../token.dart';
import 'block_syntax.dart';
import 'code_block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses email-style blockquotes: `> quote`.
class BlockquoteSyntax extends BlockSyntax {
  @override
  RegExp get pattern => blockquotePattern;

  const BlockquoteSyntax();

  BlockSyntaxChildSource parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the blockquote, stripping off the ">".
    final childLines = <SourceSpan>[];
    final markers = <Token>[];

    bool encounteredCodeBlock = false;
    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current.text);
      if (match != null) {
        final tokens = parseTokensFromMatch(
          match,
          offset: parser.current.start.offset,
          line: parser.line,
        );
        markers.add(tokens[0]);

        final line = tokens[1];
        childLines.add(line);
        encounteredCodeBlock = indentPattern.hasMatch(line.text);
        parser.advance();
        continue;
      }

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      // Because indented code blocks cannot interrupt paragraphs, a line
      // matched CodeBlockSyntax is also paragraph continuation text.
      final otherMatched =
          parser.blockSyntaxes.firstWhere((s) => s.canParse(parser));
      if (otherMatched is ParagraphSyntax ||
          (!encounteredCodeBlock && otherMatched is CodeBlockSyntax)) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        break;
      }
    }

    return BlockSyntaxChildSource(markers, childLines);
  }

  @override
  Node parse(BlockParser parser) {
    final start = parser.current.start;
    final end = parser.current.end;
    final childSource = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(
      childSource.lines,
      parser.document,
    ).parseLines();

    return Element(
      'blockquote',
      children: children,
      markers: childSource.markers,
      start: start,
      end: end,
    );
  }
}
