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

/// Parses tables.
class TableSyntax extends BlockSyntax {
  @override
  bool canInterrupt(BlockParser parser) => false;

  @override
  RegExp get pattern => dummyPattern;

  const TableSyntax();

  @override
  bool canParse(BlockParser parser) {
    // Note: matches *next* line, not the current one. We're looking for the
    // bar separating the head row from the body rows.
    return parser.next?.hasMatch(tablePattern, syntax: this) ?? false;
  }

  /// Parses a table into its three parts:
  ///
  /// * a head row of head cells
  /// * a divider of hyphens and pipes (not rendered)
  /// * many body rows of body cells
  @override
  Node? parse(BlockParser parser) {
    final markers = [parser.next!.content.trim()];
    final lineEndings = [
      parser.current.lineEnding!,
      if (parser.next?.lineEnding != null) parser.next!.lineEnding!,
    ];

    final alignments = _parseDelimiterRow(parser.next!.content.text);
    final columnCount = alignments.length;
    final parsedRow = _parseRow(
      parser.current.content,
      alignments,
      'tableHeadCell',
    );
    if (parsedRow.row.children.length != columnCount) {
      parser.next!.neverMatch(this);
      return null;
    }

    markers.insertAll(0, parsedRow.markers);
    final head = Element('tableHead', children: [parsedRow.row]);
    parser.advance();

    // Advance past the divider of hyphens.
    parser.advance();

    final rows = <Element>[];
    while (!shouldEnd(parser)) {
      final parsedRow = _parseRow(
        parser.current.content,
        alignments,
        'tableBodyCell',
      );
      final children = parsedRow.row.children;
      markers.addAll(parsedRow.markers);
      if (parser.current.lineEnding != null) {
        lineEndings.add(parser.current.lineEnding!);
      }

      while (children.length < columnCount) {
        // Insert synthetic empty cells.
        children.add(Element('tableBodyCell'));
      }

      // https://github.github.com/gfm/#example-204
      // But we do not ignore the excess in Markdown AST, mark them instead.
      if (children.length > columnCount) {
        children.getRange(columnCount, children.length).forEach((element) {
          (element as Element).attributes['exception'] = "exceeded";
        });
      }
      rows.add(parsedRow.row);
      parser.advance();
    }

    Element? body;
    if (rows.isNotEmpty) {
      body = Element('tableBody', children: rows);
    }
    return Element(
      'table',
      children: [head, if (body != null) body],
      lineEndings: lineEndings,
      markers: markers,
    );
  }

  List<String?> _parseDelimiterRow(String text) {
    final columns = text.replaceAll(RegExp(r'^\s*\||\|\s*$'), '').split('|');

    return columns.map((column) {
      column = column.trim();
      final matchLeft = column.startsWith(':');
      final matchRight = column.endsWith(':');

      if (matchLeft && matchRight) return 'center';
      if (matchLeft) return 'left';
      if (matchRight) return 'right';
      return null;
    }).toList();
  }

  /// Parses a table row at the current line into a table row element, with
  /// parsed table cells.
  ///
  /// [alignments] is used to annotate an alignment on each cell, and
  /// [cellType] is used to declare either "tableBodyCell" or "tableHeadCell"
  /// cells.
  _RowElements _parseRow(
    SourceSpan content,
    List<String?> alignments,
    String cellType,
  ) {
    final markers = <SourceSpan>[];
    final row = <Element>[];
    final cells = <List<Node>>[];
    final spanParser = SourceSpanParser([content.trimRight()]);

    /// Walks through the opening pipe and any whitespace that surrounds it.
    spanParser.moveThroughWhitespace();
    if (spanParser.charAt() == $pipe) {
      spanParser.advance();
    }

    var cellStart = spanParser.position;
    final segments = <SourceSpan>[];
    while (!spanParser.isDone) {
      final char = spanParser.charAt();
      final atEnd = spanParser.isEndingPosition(
        spanParser.offsetPosition(spanParser.position, 1),
      );

      // GitHub Flavored Markdown has a strange bit here; the pipe is to be
      // escaped before any other inline processing. One consequence, for
      // example, is that "| `\|` |" should be parsed as a cell with a code
      // element with text "|", rather than "\|". Most parsers are not
      // compliant with this corner, but this is what is specified, and what
      // GitHub does in practice.
      // See https://github.github.com/gfm/#example-200.
      if (char == $backslash && !atEnd) {
        segments.addAll(spanParser.subText(cellStart, spanParser.position));

        // Save "\" as a marker.
        markers.add(spanParser.spanAt());
        spanParser.advance();

        cellStart = spanParser.position;
        spanParser.advance();
        continue;
      }

      if (char == $pipe || atEnd) {
        segments.addAll(spanParser.subText(
          cellStart,
          (atEnd && char != $pipe) ? null : spanParser.position,
        ));

        if (segments.isNotEmpty) {
          segments.first = segments.first.trimLeft();
          segments.last = segments.last.trimRight();
        }
        cells.add(
          segments.map<Node>((span) => UnparsedContent.fromSpan(span)).toList(),
        );
        segments.clear();
        if (!atEnd) {
          spanParser.advance();
          cellStart = spanParser.position;
          continue;
        }
      }
      spanParser.advance();
    }

    for (var i = 0; i < cells.length; i++) {
      String? textAlign;
      if (i < alignments.length && alignments[i] != null) {
        textAlign = '${alignments[i]}';
      }

      row.add(Element(
        cellType,
        children: cells[i],
        attributes: textAlign == null ? {} : {'textAlign': textAlign},
      ));
    }

    return _RowElements(Element('tableRow', children: row), markers);
  }
}

class _RowElements {
  final Element row;
  final List<SourceSpan> markers;
  _RowElements(this.row, this.markers);
}
