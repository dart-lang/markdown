import 'dart:convert';

String escapeHtml(String html) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(html);

String escapeHtmlAttribute(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

// Escape the contents of [value], so that it may be used as an HTML attribute.

// Based on http://spec.commonmark.org/0.28/#backslash-escapes.
String escapeAttribute(String value) {
  var result = StringBuffer();
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

/// Character '\'.
const int $backslash = 0x5C;

/// Character '"'.
const int $quote = 0x22;

/// Character '!'.
const int $exclamation = 0x21;

/// Character '#'.
const int $hash = 0x23;

/// Character '$'.
const int $dollar = 0x24;

/// Character '%'.
const int $percent = 0x25;

/// Character '&'.
const int $ampersand = 0x26;

/// Character '''.
const int $apostrophe = 0x27;

/// Character '('.
const int $lparen = 0x28;

/// Character ')'.
const int $rparen = 0x29;

/// Character '*'.
const int $asterisk = 0x2A;

/// Character '+'.
const int $plus = 0x2B;

/// Character ','.
const int $comma = 0x2C;

/// Character '-'.
const int $dash = 0x2D;

/// Character '.'.
const int $dot = 0x2E;

/// Character '/'.
const int $slash = 0x2F;

/// Character ':'.
const int $colon = 0x3A;

/// Character ';'.
const int $semicolon = 0x3B;

/// Character '<'.
const int $lt = 0x3C;

/// Character '='.
const int $equal = 0x3D;

/// Character '>'.
const int $gt = 0x3E;

/// Character '?'.
const int $question = 0x3F;

/// Character '@'.
const int $at = 0x40;

/// Character '['.
const int $lbracket = 0x5B;

/// Character ']'.
const int $rbracket = 0x5D;

/// Character '^'.
const int $caret = 0x5E;

/// Character '_'.
const int $underscore = 0x5F;

/// Character '`'.
const int $backquote = 0x60;

/// Character '{'.
const int $lbrace = 0x7B;

/// Character '|'.
const int $bar = 0x7C;

/// Character '}'.
const int $rbrace = 0x7D;

/// Character '~'.
const int $tilde = 0x7E;

/// Space character.
const int $space = 0x20;

/// Character '"'.
const int $double_quote = 0x22;

/// "Line feed" control character.
const int $lf = 0x0A;

/// "Carriage return" control character.
const int $cr = 0x0D;

/// "Form feed" control character.
const int $ff = 0x0C;

/// "Horizontal Tab" control character, common name.
const int $tab = 0x09;

/// "Vertical Tab" control character.
const int $vt = 0x0B;
