// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'code_block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses GitHub callout blocks.
/// https://github.com/orgs/community/discussions/16925
class CalloutBlockSyntax extends BlockSyntax {
  const CalloutBlockSyntax();

  @override
  RegExp get pattern => calloutPattern;

  @override
  bool canParse(BlockParser parser) {
    return pattern.hasMatch(parser.current.content) &&
        parser.lines.any((line) => _contentLineRegExp.hasMatch(line.content));
  }

  /// Whether this callout ends with a lazy continuation line.
  // The definition of lazy continuation lines:
  // https://spec.commonmark.org/0.30/#lazy-continuation-line
  static bool _lazyContinuation = false;
  static final _contentLineRegExp = RegExp(r'>?\s?(.*)*');

  @override
  List<Line> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the callout, stripping off the ">".
    final childLines = <Line>[];
    _lazyContinuation = false;

    while (!parser.isDone) {
      final strippedContent =
          parser.current.content.replaceFirst(RegExp(r'^\s*>?\s*'), '');
      final match = _contentLineRegExp.firstMatch(strippedContent);
      if (match != null) {
        childLines.add(Line(strippedContent));
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
    // Parse the callout type from the first line.
    final type =
        pattern.firstMatch(parser.current.content)!.group(1)!.toLowerCase();
    parser.advance();
    final childLines = parseChildLines(parser);
    // Recursively parse the contents of the callout.
    final children = BlockParser(childLines, parser.document).parseLines(
      // The setext heading underline cannot be a lazy continuation line in a
      // block quote.
      // https://spec.commonmark.org/0.30/#example-93
      disabledSetextHeading: _lazyContinuation,
      parentSyntax: this,
    );

    // Mapping the callout title text.
    final titleText = {
      'note': 'Note',
      'tip': 'Tip',
      'important': 'Important',
      'caution': 'Caution',
      'warning': 'Warning',
    }[type]!;
    final titleElement = Element('p', [Text(titleText)])
      ..attributes['class'] = 'markdown-alert-title';
    final elementClass = 'markdown-alert markdown-alert-${type.toLowerCase()}';
    return Element('div', [titleElement, ...children])
      ..attributes['class'] = elementClass;
  }
}
