// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../line.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';
import 'code_block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses email-style blockquotes: `> quote`.
class BlockquoteSyntax extends BlockSyntax {
  @override
  RegExp get pattern => blockquotePattern;

  const BlockquoteSyntax();

  @override
  List<Line> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the blockquote, stripping off the ">".
    final childLines = <Line>[];

    while (!parser.isDone) {
      final currentLine = parser.current;
      final match = pattern.firstMatch(parser.current.content);
      if (match != null) {
        // A block quote marker consists of a `>` together with an optional
        // following space of indentation, see
        // https://spec.commonmark.org/0.30/#block-quote-marker.
        final markerStart = match.match.indexOf('>');
        int markerEnd;
        if (currentLine.content.length > 1) {
          var hasSpace = false;
          // Check if there is a following space if the marker is not at the end
          // of this line.
          if (markerStart < currentLine.content.length - 1) {
            final nextChar = currentLine.content.codeUnitAt(markerStart + 1);
            hasSpace = nextChar == $tab || nextChar == $space;
          }
          markerEnd = markerStart + (hasSpace ? 2 : 1);
        } else {
          markerEnd = markerStart + 1;
        }
        childLines.add(Line(currentLine.content.substring(markerEnd)));
        parser.advance();
        continue;
      }

      final lastLine = childLines.last;

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      // Because indented code blocks cannot interrupt paragraphs, a line
      // matched CodeBlockSyntax is also paragraph continuation text.
      final otherMatched =
          parser.blockSyntaxes.firstWhere((s) => s.canParse(parser));
      if ((otherMatched is ParagraphSyntax &&
              !lastLine.isBlankLine &&
              !codeFencePattern.hasMatch(lastLine.content)) ||
          (otherMatched is CodeBlockSyntax &&
              !indentPattern.hasMatch(lastLine.content))) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        break;
      }
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(childLines, parser.document).parseLines();

    return Element('blockquote', children);
  }
}
