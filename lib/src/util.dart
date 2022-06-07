// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'package:source_span/source_span.dart';
import 'block_parser.dart';
import 'charcode.dart';
import 'extensions.dart';

String escapeHtml(String html) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(html);

String escapeHtmlAttribute(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

/// Escapes the contents of [value], so that it may be used as an HTML
/// attribute.
///
/// Based on http://spec.commonmark.org/0.28/#backslash-escapes.
String escapeAttribute(String value) {
  final result = StringBuffer();
  int ch;
  for (var i = 0; i < value.codeUnits.length; i++) {
    ch = value.codeUnitAt(i);
    if (ch == $backslash) {
      i++;
      if (i == value.codeUnits.length) {
        result.writeCharCode(ch);
        break;
      }
      ch = value.codeUnitAt(i);
      switch (ch) {
        case $quote:
          result.write('&quot;');
          break;
        case $exclamation:
        case $hash:
        case $dollar:
        case $percent:
        case $ampersand:
        case $apostrophe:
        case $lparen:
        case $rparen:
        case $asterisk:
        case $plus:
        case $comma:
        case $dash:
        case $dot:
        case $slash:
        case $colon:
        case $semicolon:
        case $lt:
        case $equal:
        case $gt:
        case $question:
        case $at:
        case $lbracket:
        case $backslash:
        case $rbracket:
        case $caret:
        case $underscore:
        case $backquote:
        case $lbrace:
        case $bar:
        case $rbrace:
        case $tilde:
          result.writeCharCode(ch);
          break;
        default:
          result.write('%5C');
          result.writeCharCode(ch);
      }
    } else if (ch == $quote) {
      result.write('%22');
    } else {
      result.writeCharCode(ch);
    }
  }
  return result.toString();
}

/// One or more whitespace, for compressing.
final _oneOrMoreWhitespacePattern = RegExp('[ \n\r\t]+');

/// "Normalizes" a link label, according to the [CommonMark spec].
///
/// [CommonMark spec] https://spec.commonmark.org/0.29/#link-label
String normalizeLinkLabel(String label) =>
    label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ').toLowerCase();

/// Converts string to `List<Line>` lines.
List<Line> stringToLines(String text) {
  // Replace windows line endings with unix line endings and split.
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final result = <Line>[];

  var offset = 0;
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i];
    final start = SourceLocation(
      offset,
      column: 0,
      line: i,
    );
    offset += text.length;
    final end = SourceLocation(
      offset,
      column: text.length,
      line: i,
    );
    final content = SourceSpan(start, end, text);

    SourceSpan? lineEnding;

    if (i < lines.length - 1) {
      lineEnding = SourceSpan(
        SourceLocation(
          offset,
          column: end.column,
          line: i,
        ),
        SourceLocation(
          ++offset,
          column: 0,
          line: i + 1,
        ),
        '\n',
      );
    }
    result.add(Line(content, lineEnding: lineEnding));
  }

  return result;
}

// TODO(Zhiguang):
// Move it to BlockParser, because of InlineParser will not need it
List<SourceSpan> createSourceSpansFromMatch(
  Match match, {
  required int offset,
  required int line,
  String? text,
}) {
  final groupCount = match.groupCount;
  final List<String> keys = [];
  text ??= match.match;

  if (groupCount == 1) {
    keys.add(text);
  } else {
    for (var i = 0; i < groupCount; i++) {
      keys.add(match[i + 1]!);
    }
  }

  final List<SourceSpan> spans = [];
  for (final key in keys) {
    var indexStart = 0;
    final lastSpan = spans.isEmpty ? null : spans.last;
    if (lastSpan != null) {
      indexStart = lastSpan.end.offset - offset;
    }

    spans.add(createSourceSpanFromText(
      key,
      line: line,
      offset: offset,
      context: text,
      indexStart: indexStart,
    ));
  }

  return spans;
}

/// Creates a new [SourceSpan] from [text] and [context]
///
/// [line] is the the line where [context] start in the Markdown string.
///
/// [offset] is the offset where the [context] start in the Markdown string
SourceSpan createSourceSpanFromText(
  String text, {
  required int line,
  required int offset,
  required String context,
  required int indexStart,
}) {
  final length = text.length;
  final contentOffset = context.indexOf(text, indexStart);
  final sourceFile = SourceFile.fromString(context);
  final fileSpan = sourceFile.span(contentOffset, contentOffset + length);

  final start = SourceLocation(
    offset + contentOffset,
    column: fileSpan.start.column,
    line: line + fileSpan.start.line,
  );

  final end = SourceLocation(
    start.offset + length,
    column: fileSpan.end.column,
    line: line + fileSpan.end.line,
  );

  return SourceSpan(start, end, text);
}

// TODO(Zhiguang): Find out a better solution.
// The solution might be:
// Only use RegExp to check if the parser could hit a syntax, and use something
// like `SourceSpanParser` to tokenize.

// NOTICE:
// This function does not always return the right result:
// In this example the final index is not the index of the captured character.
// But we normally capture the markers and the rest of the text, this
// issue may not happen.
// ``` dart
// const text = '11111111';
// const pattern = r'\d\d(\d)\d';
// final match = RegExp(pattern).matchAsPrefix(text);
// final index = text.indexOf(match[1]!);
// ```

/// Adds index information [start] and [end] to each captured group.
///
/// Returns the entire match if there is no capturing, otherwise returns the
/// captured groups.
List<_GroupWithIndex?> toGroupsWithIndex(Match match) {
  final groups = <_GroupWithIndex?>[];
  final groupCount = match.groupCount;
  final context = match[0]!;

  if (groupCount == 0) {
    groups.add(_GroupWithIndex(context, match.start, match.end));
  } else {
    var startFrom = 0;

    for (var i = 0; i < groupCount; i++) {
      final text = match[i + 1];
      if (text != null) {
        final index = context.indexOf(text, startFrom);
        startFrom += index;
        groups.add(_GroupWithIndex(
          text,
          index + match.start,
          index + match.start + text.length,
        ));
      } else {
        groups.add(null);
      }
    }
  }

  return groups;
}

class _GroupWithIndex {
  final String text;
  final int start;

  /// The index in the string after the last character of the captured
  /// characters.
  final int end;

  int get length => text.length;

  const _GroupWithIndex(this.text, this.start, this.end);

  Map<String, dynamic> toMap() => {'text': text, 'start': start, 'end': end};

  @override
  String toString() => toMap().toPrettyString();
}
