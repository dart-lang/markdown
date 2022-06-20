// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../charcode.dart';
import '../extensions.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
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
    final childLines = <Line>[];
    final markers = <SourceSpan>[];

    bool lazyEnding = false;
    while (!parser.isDone) {
      final currentLine = parser.current;
      final match = currentLine.firstMatch(pattern);
      if (match != null) {
        final markerString = match[1]!;
        final markerLength = markerString.length;
        final markerStart = match.match.indexOf(markerString);
        final markerEnd = markerStart + markerLength;

        // TODO(Zhiguang) Fix marker.
        // final marker = currentLine.content.subspan(markerStart, markerEnd);

        int? tabRemaining;
        if (currentLine.text.codeUnitAt(markerEnd - 1) == $tab) {
          tabRemaining = 2;
        }

        childLines.add(Line(
          currentLine.content.subspan(markerEnd),
          lineEnding: parser.current.lineEnding,
          tabRemaining: tabRemaining,
        ));

        parser.advance();
        lazyEnding = false;
        continue;
      }

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      // Because indented code blocks cannot interrupt paragraphs, a line
      // matched CodeBlockSyntax is also paragraph continuation text.
      final otherMatched =
          parser.blockSyntaxes.firstWhere((s) => s.canParse(parser));
      if ((otherMatched is ParagraphSyntax &&
              childLines.last.content.length > 0 &&
              !childLines.last.hasMatch(codeFencePattern)) ||
          (!childLines.last.hasMatch(indentPattern) &&
              otherMatched is CodeBlockSyntax)) {
        childLines.add(parser.current);
        lazyEnding = true;
        parser.advance();
      } else {
        break;
      }
    }

    return BlockSyntaxChildSource(
      markers: markers,
      lines: childLines,
      lazyEnding: lazyEnding,
    );
  }

  @override
  Node parse(BlockParser parser) {
    final childSource = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(
      childSource.lines,
      parser.document,
    ).parseLines(disabledSetextHeading: childSource.lazyEnding);

    return Element(
      'blockquote',
      children: children,
      markers: childSource.markers,
    );
  }
}
