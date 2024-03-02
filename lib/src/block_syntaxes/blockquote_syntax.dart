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

  /// Whether this blockquote ends with a lazy continuation line.
  // The definition of lazy continuation lines:
  // https://spec.commonmark.org/0.30/#lazy-continuation-line
  static var _lazyContinuation = false;
  @override
  List<Line> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the blockquote, stripping off the ">".
    final childLines = <Line>[];
    _lazyContinuation = false;

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
        _lazyContinuation = false;
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
        _lazyContinuation = true;
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
    final children = BlockParser(childLines, parser.document).parseLines(
      // The setext heading underline cannot be a lazy continuation line in a
      // block quote.
      // https://spec.commonmark.org/0.30/#example-93
      disabledSetextHeading: _lazyContinuation,
      parentSyntax: this,
    );

    return Element('blockquote', children);
  }
}

/// Parses GitHub Alerts blocks.
///
/// See also: https://docs.github.com/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts
class AlertBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => alertPattern;

  const AlertBlockSyntax();

  @override
  List<Line> parseChildLines(BlockParser parser) {
    return const BlockquoteSyntax().parseChildLines(parser);
  }

  @override
  Node parse(BlockParser parser) {
    // Parse the alert type from the first line.
    final type =
        pattern.firstMatch(parser.current.content)!.group(1)!.toLowerCase();

    final childLines = parseChildLines(parser);
    // Until we've parse all the child lines, we can't actually know if this is
    // a blockquote containing `[!note]` or if this is an alert-block.
    //
    // This is because `> [!note]` is not a valid alert-block!
    final isBlockquote = childLines.length <= 1;

    if (!isBlockquote) {
      // Always remove the first line, this is the line that contained the type.
      childLines.removeAt(0);
    }

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(childLines, parser.document).parseLines(
      // The setext heading underline cannot be a lazy continuation line in a
      // block quote.
      // https://spec.commonmark.org/0.30/#example-93
      disabledSetextHeading: BlockquoteSyntax._lazyContinuation,
      parentSyntax: this,
    );

    if (isBlockquote) {
      return Element('blockquote', children);
    }

    // Mapping the alert title text.
    const typeTextMap = {
      'note': 'Note',
      'tip': 'Tip',
      'important': 'Important',
      'caution': 'Caution',
      'warning': 'Warning',
    };
    final titleText = typeTextMap[type]!;
    final titleElement = Element('p', [Text(titleText)])
      ..attributes['class'] = 'markdown-alert-title';
    final elementClass = 'markdown-alert markdown-alert-$type';
    return Element('div', [titleElement, ...children])
      ..attributes['class'] = elementClass;
  }
}
