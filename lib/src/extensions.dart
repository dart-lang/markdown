// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:source_span/source_span.dart';
import './charcode.dart';

extension MatchExtensions on Match {
  /// Returns the whole match String
  String get match => this[0]!;
}

extension StringExtensions on String {
  /// Calculates the length of indentation a `String` has.
  /// [size] defines how many spaces constitute an indentation.
  ///
  // The behavior of tabs: https://spec.commonmark.org/0.30/#tabs
  int indentation([int size = 4]) {
    var length = 0;
    for (final char in codeUnits) {
      if (char != $space && char != $tab) {
        break;
      }
      length += char == $tab ? size - (length % size) : 1;
    }
    return length;
  }
}

/// Converts [object] to a JSON [String] with a 2 whitespace indent.
String _toPrettyString(Object object) =>
    JsonEncoder.withIndent("  ").convert(object);

extension ListExtensions on List<dynamic> {
  String toPrettyString() => _toPrettyString(toList());
}

extension MapExtensions on Map<dynamic, dynamic> {
  String toPrettyString() => _toPrettyString(this);
}

extension SourceLocationExtensions on SourceLocation {
  bool equals(SourceLocation other) =>
      line == other.line &&
      column == other.column &&
      other.offset == offset &&
      other.sourceUrl == sourceUrl;

  Map<String, int> toMap() => {
        'line': line,
        'column': column,
        'offset': offset,
      };
}

extension SourceSpanExtensions on SourceSpan {
  Map<String, dynamic> toMap() => {
        'start': start.toMap(),
        'end': end.toMap(),
        'text': text,
      };

  /// Removes leading whitespace and trailing whitespace from [text] and returns
  /// a new [SourceSpan].
  SourceSpan trim() {
    final trimmed = text.trim();
    final index = text.indexOf(trimmed);
    return subspan(index, index + trimmed.length);
  }

  /// As [trim], but only removes leading whitespace.
  SourceSpan trimLeft() => subspan(length - text.trimLeft().length, length);

  /// As [trim], but only removes trailing whitespace.
  SourceSpan trimRight() => subspan(0, text.trimRight().length);

  /// Removes leading whitespace by the length of [length].
  // The way of handling tabs: https://spec.commonmark.org/0.30/#tabs
  _IndentedSourceSpan indent([int length = 4]) {
    final whitespaceMatch = RegExp('^[ \t]{0,$length}').firstMatch(text);
    const tabSize = 4;

    int? tabRemaining;
    var start = 0;
    final whitespaces = whitespaceMatch?[0];
    if (whitespaces != null) {
      int indentLength = 0;
      for (start; start < whitespaces.length; start++) {
        final isTab = whitespaces[start] == '\t';
        if (isTab) {
          indentLength += tabSize;
          tabRemaining = 4;
        } else {
          indentLength += 1;
        }
        if (indentLength >= length) {
          if (tabRemaining != null) {
            tabRemaining = indentLength - length;
          }
          if (indentLength == length || isTab) {
            start += 1;
          }
          break;
        }
        if (tabRemaining != null) {
          tabRemaining = 0;
        }
      }
    }
    return _IndentedSourceSpan(subspan(start), tabRemaining);
  }
}

extension SourceFileExtensions on SourceFile {
  /// Returns a list a list of spans.
  List<FileSpan> spans() {
    final spans = <FileSpan>[];

    for (var i = 0; i < lines; i++) {
      spans.add(span(
        getOffset(i),
        i < lines - 1 ? getOffset(i + 1) : null,
      ));
    }

    return spans;
  }
}

extension SourceSpanListExtensions on List<SourceSpan> {
  List<SourceSpan> concatWhilePossible() {
    final List<SourceSpan> spans = [];

    for (var i = 0; i < length; i++) {
      final current = this[i];
      if (spans.isNotEmpty && spans.last.end.offset == current.start.offset) {
        spans.last = spans.last.union(current);
      } else {
        spans.add(current);
      }
    }

    return spans;
  }

  /// Checks if a list of SouceSpan has only spaces, tabs, or line endings.
  bool isEmptyContent() {
    for (final span in this) {
      if (span.text.trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}

class _IndentedSourceSpan {
  final SourceSpan span;

  /// How many spaces of a tab that remains after part of it has been consumed.
  ///
  /// `null` means it did not hit a `tab`.
  final int? tabRemaining;

  _IndentedSourceSpan(this.span, this.tabRemaining);
}
