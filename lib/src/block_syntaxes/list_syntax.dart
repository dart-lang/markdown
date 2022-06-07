// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../extensions.dart';
import '../patterns.dart';
import '../source_span_parser.dart';
import 'block_syntax.dart';

/// Base class for both ordered and unordered lists.
abstract class ListSyntax extends BlockSyntax {
  @override
  bool canInterrupt(BlockParser parser) {
    final match = parser.current.firstMatch(pattern)!;

    // Allow only lists starting with 1 to interrupt paragraphs, if it is an
    // ordered list. See https://spec.commonmark.org/0.30/#example-304.
    // But there shuold be an exception for nested ordered lists, for example:
    // ```
    // 1. one
    // 2. two
    //   3. three
    //   4. four
    // 5. five
    // ```
    if (parser.parentSyntax is! ListSyntax &&
        match[1]!.isNotEmpty &&
        match[1] != '1') {
      return false;
    }

    // An empty list item cannot interrupt a paragraph. See
    // https://spec.commonmark.org/0.30/#example-285
    // The seventh group, in both [olPattern] and [ulPattern] is the text
    // after the delimiter.
    return match[2]?.isNotEmpty ?? false;
  }

  bool get ordered;

  const ListSyntax();

  @override
  Node parse(BlockParser parser) {
    SourceSpan? listMarker;
    final items = <BlockSyntaxChildSource>[];
    var childLines = <Line>[];

    void endItem() {
      if (childLines.isNotEmpty) {
        items.add(BlockSyntaxChildSource(
          lines: childLines,
          markers: [listMarker!],
        ));
        childLines = <Line>[];
      }
    }

    late Match? match;
    bool tryMatch(RegExp pattern) {
      match = parser.current.firstMatch(pattern);
      return match != null;
    }

    int indent = 0;
    // In case the first number in an ordered list is not 1, use it as the
    // "start".
    int? startNumber;
    int blankLines = 0;

    while (!parser.isDone) {
      final currentIndent = parser.current.content.text.indentation() +
          (parser.current.tabRemaining ?? 0);

      if (tryMatch(emptyPattern)) {
        childLines.add(parser.current);
        if (blankLines != 0) {
          blankLines++;
        }
      } else if (indent != 0 && indent <= currentIndent) {
        // A list item can begin with at most one blank line. See:
        // https://spec.commonmark.org/0.30/#example-280
        if (blankLines > 1) {
          break;
        }

        final indentedLine = parser.current.content.indent(indent);

        childLines.add(Line(
          indentedLine.span,
          lineEnding: parser.current.lineEnding,
          tabRemaining: indentedLine.tabRemaining,
        ));
      } else if (tryMatch(hrPattern)) {
        // Horizontal rule takes precedence to a new list item.
        break;
      } else if (tryMatch(ulPattern) || tryMatch(olPattern)) {
        blankLines = 0;

        final sourceSpanParser = SourceSpanParser([parser.current.content]);
        var precedingWhitespaces = sourceSpanParser.moveThroughWhitespace();
        final markerStart = sourceSpanParser.position;
        final digits = match![1] ?? '';
        if (digits.isNotEmpty) {
          if (startNumber == null && digits.isNotEmpty) {
            startNumber = int.parse(digits);
          }
          sourceSpanParser.advanceBy(digits.length);
        }
        sourceSpanParser.advance();

        // See https://spec.commonmark.org/0.30/#ordered-list-marker
        final marker = sourceSpanParser
            .subText(markerStart, sourceSpanParser.position)
            .first;

        var isBlank = true;
        var contentWhitespances = 0;
        var hitTab = false;
        SourcePosition? contentBlockStart;

        if (!sourceSpanParser.isDone) {
          hitTab = sourceSpanParser.charAt() == $tab;
          // Skip the first whitespace.
          sourceSpanParser.advance();
          contentBlockStart = sourceSpanParser.position;
          if (!sourceSpanParser.isDone) {
            contentWhitespances = sourceSpanParser.moveThroughWhitespace();

            if (!sourceSpanParser.isDone) {
              isBlank = false;
            }
          }
        }

        // Changing the bullet or ordered list delimiter starts a new list.
        if (listMarker != null &&
            listMarker.text.last() != marker.text.last()) {
          break;
        }
        listMarker = marker;
        precedingWhitespaces += digits.length + 2;
        if (isBlank) {
          // See https://spec.commonmark.org/0.30/#example-278.
          blankLines = 1;
          indent = precedingWhitespaces;
        } else if (contentWhitespances >= 4) {
          // See https://spec.commonmark.org/0.30/#example-270.
          //
          // If the list item starts with indented code, we need to _not_ count
          // any indentation past the required whitespace character.
          indent = precedingWhitespaces;
        } else {
          indent = precedingWhitespaces + contentWhitespances;
        }

        // End the current list item and start a new one.
        endItem();

        SourceSpan content;
        if (contentBlockStart != null && !isBlank) {
          content = sourceSpanParser.subText(contentBlockStart).first;
        } else {
          final location = sourceSpanParser.positionToLocation(
            sourceSpanParser.position,
          );

          content = SourceSpan(location, location, '');
        }

        childLines.add(Line(
          content,
          lineEnding: parser.current.lineEnding,
          tabRemaining: hitTab ? 2 : null,
        ));
      } else if (shouldEnd(parser)) {
        // Done with the list.
        break;
      } else {
        // If the previous item is a blank line, this means we're done with the
        // list and are starting a new top-level paragraph.
        if ((childLines.isNotEmpty) && (childLines.last.isBlankLine)) {
          parser.encounteredBlankLine = true;
          break;
        }

        // Anything else is paragraph continuation text.
        childLines.add(parser.current);
      }
      parser.advance();
    }

    endItem();
    final itemNodes = <Element>[];

    items.forEach(_removeLeadingEmptyLine);
    final anyEmptyLines = _removeTrailingEmptyLines(items);
    var anyEmptyLinesBetweenBlocks = false;

    for (final item in items) {
      final itemParser = BlockParser(item.lines, parser.document);

      final children = itemParser.parseLines(fromSyntax: this);
      itemNodes.add(Element(
        'listItem',
        children: children,
        markers: item.markers,
      ));
      anyEmptyLinesBetweenBlocks =
          anyEmptyLinesBetweenBlocks || itemParser.encounteredBlankLine;
    }

    // Must strip paragraph tags if the list is "tight".
    // http://spec.commonmark.org/0.30/#lists
    final listIsTight = !anyEmptyLines && !anyEmptyLinesBetweenBlocks;

    if (listIsTight) {
      // We must post-process the list items, converting any top-level paragraph
      // elements to just text elements.
      for (final item in itemNodes) {
        final children = item.children;
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          if (child is Element && child.type == 'paragraph') {
            children.removeAt(i);
            children.insertAll(i, child.children);
          }
        }
      }
    }

    return Element(
      ordered ? 'orderedList' : 'bulletList',
      children: itemNodes,
      attributes: {
        if (ordered && startNumber != 1) 'start': '$startNumber',
      },
    );
  }

  // TODO(Zhiguang): Save the lineEnding of the removed line.
  void _removeLeadingEmptyLine(BlockSyntaxChildSource item) {
    if (item.lines.isNotEmpty && item.lines.first.hasMatch(emptyPattern)) {
      item.lines.removeAt(0);
    }
  }

  /// Removes any trailing empty lines and notes whether any items are separated
  /// by such lines.
  // TODO(Zhiguang): Save the lineEnding of the removed line.
  bool _removeTrailingEmptyLines(List<BlockSyntaxChildSource> items) {
    var anyEmpty = false;
    for (var i = 0; i < items.length; i++) {
      if (items[i].lines.length == 1) continue;
      while (items[i].lines.isNotEmpty &&
          items[i].lines.last.hasMatch(emptyPattern)) {
        if (i < items.length - 1) {
          anyEmpty = true;
        }
        items[i].lines.removeLast();
      }
    }
    return anyEmpty;
  }
}
