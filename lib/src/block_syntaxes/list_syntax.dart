// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

class ListItem {
  ListItem(this.lines);

  bool forceBlock = false;
  final List<String> lines;
}

/// Base class for both ordered and unordered lists.
abstract class ListSyntax extends BlockSyntax {
  @override
  bool canEndBlock(BlockParser parser) {
    // An empty list cannot interrupt a paragraph. See
    // https://spec.commonmark.org/0.29/#example-255.
    // Ideally, [BlockSyntax.canEndBlock] should be changed to be a method
    // which accepts a [BlockParser], but this would be a breaking change,
    // so we're going with this temporarily.
    final match = pattern.firstMatch(parser.current)!;
    // The seventh group, in both [olPattern] and [ulPattern] is the text
    // after the delimiter.
    return match[7]?.isNotEmpty ?? false;
  }

  String get listTag;

  const ListSyntax();

  /// A list of patterns that can start a valid block within a list item.
  static final blocksInList = [
    blockquotePattern,
    headerPattern,
    hrPattern,
    indentPattern,
    ulPattern,
    olPattern
  ];

  static final _whitespaceRe = RegExp('[ \t]*');

  @override
  Node parse(BlockParser parser) {
    final items = <ListItem>[];
    var childLines = <String>[];

    void endItem() {
      if (childLines.isNotEmpty) {
        items.add(ListItem(childLines));
        childLines = <String>[];
      }
    }

    late Match? match;
    bool tryMatch(RegExp pattern) {
      match = pattern.firstMatch(parser.current);
      return match != null;
    }

    String? listMarker;
    String? indent;
    // In case the first number in an ordered list is not 1, use it as the
    // "start".
    int? startNumber;

    while (!parser.isDone) {
      final leadingSpace =
          _whitespaceRe.matchAsPrefix(parser.current)!.group(0)!;
      final leadingExpandedTabLength = _expandedTabLength(leadingSpace);
      if (tryMatch(emptyPattern)) {
        if (emptyPattern.hasMatch(parser.next ?? '')) {
          // Two blank lines ends a list.
          break;
        }
        // Add a blank line to the current list item.
        childLines.add('');
      } else if (indent != null && indent.length <= leadingExpandedTabLength) {
        // Strip off indent and add to current item.
        final line = parser.current
            .replaceFirst(leadingSpace, ' ' * leadingExpandedTabLength)
            .replaceFirst(indent, '');
        childLines.add(line);
      } else if (tryMatch(hrPattern)) {
        // Horizontal rule takes precedence to a new list item.
        break;
      } else if (tryMatch(ulPattern) || tryMatch(olPattern)) {
        final precedingWhitespace = match![1]!;
        final digits = match![2] ?? '';
        if (startNumber == null && digits.isNotEmpty) {
          startNumber = int.parse(digits);
        }
        final marker = match![3]!;
        final firstWhitespace = match![5] ?? '';
        final restWhitespace = match![6] ?? '';
        final content = match![7] ?? '';
        final isBlank = content.isEmpty;
        if (listMarker != null && listMarker != marker) {
          // Changing the bullet or ordered list delimiter starts a new list.
          break;
        }
        listMarker = marker;
        final markerAsSpaces = ' ' * (digits.length + marker.length);
        if (isBlank) {
          // See http://spec.commonmark.org/0.28/#list-items under "3. Item
          // starting with a blank line."
          //
          // If the list item starts with a blank line, the final piece of the
          // indentation is just a single space.
          indent = '$precedingWhitespace$markerAsSpaces ';
        } else if (restWhitespace.length >= 4) {
          // See http://spec.commonmark.org/0.28/#list-items under "2. Item
          // starting with indented code."
          //
          // If the list item starts with indented code, we need to _not_ count
          // any indentation past the required whitespace character.
          indent = precedingWhitespace + markerAsSpaces + firstWhitespace;
        } else {
          indent = precedingWhitespace +
              markerAsSpaces +
              firstWhitespace +
              restWhitespace;
        }
        // End the current list item and start a new one.
        endItem();
        childLines.add(restWhitespace + content);
      } else if (BlockSyntax.isAtBlockEnd(parser)) {
        // Done with the list.
        break;
      } else {
        // If the previous item is a blank line, this means we're done with the
        // list and are starting a new top-level paragraph.
        if ((childLines.isNotEmpty) && (childLines.last == '')) {
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
      final children = itemParser.parseLines();
      itemNodes.add(Element('li', children));
      anyEmptyLinesBetweenBlocks =
          anyEmptyLinesBetweenBlocks || itemParser.encounteredBlankLine;
    }

    // Must strip paragraph tags if the list is "tight".
    // http://spec.commonmark.org/0.28/#lists
    final listIsTight = !anyEmptyLines && !anyEmptyLinesBetweenBlocks;

    if (listIsTight) {
      // We must post-process the list items, converting any top-level paragraph
      // elements to just text elements.
      for (final item in itemNodes) {
        final children = item.children;
        if (children != null) {
          for (var i = 0; i < children.length; i++) {
            final child = children[i];
            if (child is Element && child.tag == 'p') {
              children.removeAt(i);
              children.insertAll(i, child.children!);
            }
          }
        }
      }
    }

    if (listTag == 'ol' && startNumber != 1) {
      return Element(listTag, itemNodes)..attributes['start'] = '$startNumber';
    } else {
      return Element(listTag, itemNodes);
    }
  }

  void _removeLeadingEmptyLine(ListItem item) {
    if (item.lines.isNotEmpty && emptyPattern.hasMatch(item.lines.first)) {
      item.lines.removeAt(0);
    }
  }

  /// Removes any trailing empty lines and notes whether any items are separated
  /// by such lines.
  bool _removeTrailingEmptyLines(List<ListItem> items) {
    var anyEmpty = false;
    for (var i = 0; i < items.length; i++) {
      if (items[i].lines.length == 1) continue;
      while (items[i].lines.isNotEmpty &&
          emptyPattern.hasMatch(items[i].lines.last)) {
        if (i < items.length - 1) {
          anyEmpty = true;
        }
        items[i].lines.removeLast();
      }
    }
    return anyEmpty;
  }

  static int _expandedTabLength(String input) {
    var length = 0;
    for (final char in input.codeUnits) {
      length += char == 0x9 ? 4 - (length % 4) : 1;
    }
    return length;
  }
}
