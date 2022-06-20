// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import '../assets/case_folding.dart';
import '../assets/html_entities.dart';
import 'line.dart';

/// One or more whitespace, for compressing.
final _oneOrMoreWhitespacePattern = RegExp('[ \n\r\t]+');

/// "Normalizes" a link label, according to the [CommonMark spec].
///
/// [CommonMark spec] https://spec.commonmark.org/0.30/#link-label
String normalizeLinkLabel(String label) {
  final text = label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ');
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    buffer.write(caseFoldingMap[text[i]] ?? text[i]);
  }
  return buffer.toString();
}

/// Converts string to `List<Line>` lines.
List<Line> stringToLines(String text) {
  // Replace windows line endings with unix line endings and split.
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final result = <Line>[];

  var offset = 0;
  for (var i = 0; i < lines.length; i++) {
    // Ignore the last blank line. This blank line is produced by the line
    // ending of the previous line, and followd by the end of file.
    if (lines.length == i + 1 && lines[i].isEmpty) {
      break;
    }

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

///  Decodes HTML entity and numeric character references, for example decode
/// `&#35` to `#`.
String decodeHtmlCharacters(String input) {
  final pattern = RegExp(
    '&(?:([a-z0-9]+)|#([0-9]{1,7})|#x([a-f0-9]{1,6}));',
    multiLine: true,
    caseSensitive: false,
  );

  return input.replaceAllMapped(pattern, (match) {
    final text = match[0]!;

    // Entity references, see
    // https://spec.commonmark.org/0.30/#entity-references.
    if (match[1] != null) {
      return htmlEntitiesMap[text] ?? text;
    }

    // Decimal numeric character references, see
    // https://spec.commonmark.org/0.30/#decimal-numeric-character-references.
    if (match[2] != null) {
      final decimalValue = int.parse(match[2]!);
      int hexValue;
      if (decimalValue < 1114112 && decimalValue > 1) {
        hexValue = int.parse(decimalValue.toRadixString(16), radix: 16);
      } else {
        hexValue = 0xFFFd;
      }
      return String.fromCharCode(hexValue);
    }

    // Hexadecimal numeric character references, see
    // https://spec.commonmark.org/0.30/#hexadecimal-numeric-character-references.
    if (match[3] != null) {
      var hexValue = int.parse(match[3]!, radix: 16);
      if (hexValue > 0x10ffff || hexValue == 0) {
        hexValue = 0xFFFd;
      }
      return String.fromCharCode(hexValue);
    }

    return text;
  });
}
