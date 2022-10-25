// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'assets/case_folding.dart';
import 'assets/html_entities.dart';
import 'charcode.dart';
import 'patterns.dart';

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
/// [CommonMark spec] https://spec.commonmark.org/0.30/#link-label
String normalizeLinkLabel(String label) {
  var text = label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ');
  for (var i = 0; i < text.length; i++) {
    final mapped = caseFoldingMap[text[i]];
    if (mapped != null) {
      text = text.replaceRange(i, i + 1, mapped);
    }
  }
  return text;
}

///  Decodes HTML entity and numeric character references, for example decode
/// `&#35` to `#`.
String decodeHtmlCharacters(String input) =>
    input.replaceAllMapped(htmlCharactersPattern, decodeHtmlCharacterFromMatch);

/// Decodes HTML entity and numeric character references from the given [match].
String decodeHtmlCharacterFromMatch(Match match) {
  final text = match.match;
  final entity = match[1];
  final decimalNumber = match[2];
  final hexadecimalNumber = match[3];

  // Entity references, see
  // https://spec.commonmark.org/0.30/#entity-references.
  if (entity != null) {
    return htmlEntitiesMap[text] ?? text;
  }

  // Decimal numeric character references, see
  // https://spec.commonmark.org/0.30/#decimal-numeric-character-references.
  else if (decimalNumber != null) {
    final decimalValue = int.parse(decimalNumber);
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
  else if (hexadecimalNumber != null) {
    var hexValue = int.parse(hexadecimalNumber, radix: 16);
    if (hexValue > 0x10ffff || hexValue == 0) {
      hexValue = 0xFFFd;
    }
    return String.fromCharCode(hexValue);
  }

  return text;
}

extension MatchExtensions on Match {
  /// Returns the whole match String
  String get match => this[0]!;
}
