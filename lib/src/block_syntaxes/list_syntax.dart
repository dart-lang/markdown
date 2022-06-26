// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../charcode.dart';
import '../extensions.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../parsers/source_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

@Deprecated('Use ListSyntax instead')
class OrderedListSyntax extends ListSyntax {}

@Deprecated('Use ListSyntax instead')
class UnorderedListSyntax extends ListSyntax {}

/// Base class for both ordered and unordered lists.
class ListSyntax extends BlockSyntax {
  @override
  RegExp get pattern => listPattern;

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
        match[1] != null &&
        match[1] != '1') {
      return false;
    }

    // An empty list item cannot interrupt a paragraph. See
    // https://spec.commonmark.org/0.30/#example-285
    // The seventh group, in both [olPattern] and [ulPattern] is the text
    // after the delimiter.
    return match[2]?.isNotEmpty ?? false;
  }

  const ListSyntax();

  @override
  Node parse(BlockParser parser) {
    var match = parser.current.firstMatch(listPattern);
    final ordered = match![1] != null;

    SourceSpan? listMarker;
    final listItems = <BlockSyntaxChildSource>[];

    // The child lines of each list item.
    var childLines = <Line>[];

    void endItem() {
      if (childLines.isNotEmpty) {
        listItems.add(BlockSyntaxChildSource(
          lines: childLines,
          markers: [listMarker!],
        ));
        childLines = <Line>[];
      }
    }

    bool tryMatch(RegExp pattern) {
      match = parser.current.firstMatch(pattern);
      return match != null;
    }

    // In case the first number in an ordered list is not 1, use it as the
    // "start".
    int? startNumber;

    int? indent;
    int? blankLines;

    while (!parser.isDone) {
      final currentIndent = parser.current.content.text.indentation() +
          (parser.current.tabRemaining ?? 0);

      // If meet a blank line.
      if (tryMatch(emptyPattern)) {
        childLines.add(parser.current);

        if (blankLines != null) {
          blankLines++;
        }
      } else if (indent != null && indent <= currentIndent) {
        // A list item can begin with at most one blank line. See:
        // https://spec.commonmark.org/0.30/#example-280
        if (blankLines != null && blankLines > 1) {
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
      } else if (tryMatch(listPattern)) {
        blankLines = null;

        final spanParser = SourceParser([parser.current.content]);
        var precedingWhitespaces = spanParser.moveThroughWhitespace();
        final markerStart = spanParser.position;
        final digits = match![1] ?? '';
        if (digits.isNotEmpty) {
          startNumber ??= int.parse(digits);
          spanParser.advanceBy(digits.length);
        }
        spanParser.advance();

        // See https://spec.commonmark.org/0.30/#ordered-list-marker
        final marker =
            spanParser.subspan(markerStart, spanParser.position).first;

        var isBlank = true;
        var contentWhitespances = 0;
        var hitTab = false;
        int? contentBlockStart;

        if (!spanParser.isDone) {
          hitTab = spanParser.charAt() == $tab;
          // Skip the first whitespace.
          spanParser.advance();
          contentBlockStart = spanParser.position;
          if (!spanParser.isDone) {
            contentWhitespances = spanParser.moveThroughWhitespace();

            if (!spanParser.isDone) {
              isBlank = false;
            }
          }
        }

        // Changing the bullet or ordered list delimiter starts a new list.
        if (listMarker != null &&
            listMarker.text.last() != marker.text.last()) {
          break;
        }

        // End the current list item.
        endItem();

        // Start a new list item, the last item will be ended up outside of the
        // `while` loop.
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

        final content = contentBlockStart != null && !isBlank
            ? spanParser.subspan(contentBlockStart).first
            : spanParser.emptySpan();

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

    // End the last list item.
    endItem();

    final itemNodes = <Element>[];

    _removeLeadingBlankLines(listItems);
    final anyBlankLines = _removeTrailingBlankLines(listItems);
    var anyBlankLinesBetweenBlocks = false;

    for (final item in listItems) {
      final itemParser = BlockParser(item.lines, parser.document);

      final children = itemParser.parseLines(fromSyntax: this);
      itemNodes.add(Element(
        'listItem',
        children: children,
        markers: item.markers,
      ));
      anyBlankLinesBetweenBlocks =
          anyBlankLinesBetweenBlocks || itemParser.encounteredBlankLine;
    }

    // Must strip paragraph tags if the list is "tight".
    // http://spec.commonmark.org/0.30/#lists
    final listIsTight = !anyBlankLines && !anyBlankLinesBetweenBlocks;

    if (listIsTight) {
      // We must post-process the list items, converting any top-level paragraph
      // elements to just text elements.
      for (final item in itemNodes) {
        final children = item.children;
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          if (child is Element && child.type == 'paragraph') {
            children
              ..removeAt(i)
              ..insertAll(i, child.children);
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

  void _removeLeadingBlankLines(List<BlockSyntaxChildSource> listItems) {
    for (final item in listItems) {
      if (item.lines.isNotEmpty && item.lines.first.isBlankLine) {
        item.lines.removeAt(0);
      }
    }
  }

  /// Removes any trailing blank lines and notes whether any items are separated
  /// by such lines.
  bool _removeTrailingBlankLines(List<BlockSyntaxChildSource> listItems) {
    var anyEmpty = false;
    for (var i = 0; i < listItems.length; i++) {
      final lines = listItems[i].lines;
      if (lines.length == 1) continue;
      while (lines.isNotEmpty && lines.last.isBlankLine) {
        if (i < listItems.length - 1) {
          anyEmpty = true;
        }
        lines.removeLast();
      }
    }
    return anyEmpty;
  }
}
