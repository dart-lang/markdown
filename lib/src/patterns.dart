// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The line contains only whitespace or is empty.
final emptyPattern = RegExp(r'^(?:[ \t]*)$');

/// A series of `=` or `-` (on the next line) define setext-style headers.
final setextPattern = RegExp(r'^[ ]{0,3}(=+|-+)\s*$');

/// Leading (and trailing) `#` define atx-style headers.
///
/// Starts with 1-6 unescaped `#` characters which must not be followed by a
/// non-space character. Line may end with any number of `#` characters,.
final headerPattern =
    RegExp(r'^ {0,3}(#{1,6})(?:[ \x09\x0b\x0c].*?)?(?:\s(#*)\s*)?$');

/// The line starts with `>` with one optional space after.
final blockquotePattern = RegExp(r'^[ ]{0,3}>[ \t]?.*$');

/// A line indented four spaces. Used for code blocks and lists.
final indentPattern = RegExp(r'^(?:    | {0,3}\t).*$');

/// Fenced code block.
final codeFencePattern = RegExp(r'^([ ]{0,3})(?:(`{3,})([^`]*)|(~{3,})(.*))$');

/// Fenced blockquotes.
final blockquoteFencePattern = RegExp(r'^>{3}\s*$');

/// Three or more hyphens, asterisks or underscores by themselves. Note that
/// a line like `----` is valid as both HR and SETEXT. In case of a tie,
/// SETEXT should win.
final hrPattern = RegExp(r'^ {0,3}([-*_])[ \t]*\1[ \t]*\1(?:\1|[ \t])*$');

/// A line starting with one of these markers: `-`, `*`, `+`. May have up to
/// three leading spaces before the marker and any number of spaces or tabs
/// after.
///
/// Contains a dummy group at [2], so that the groups in [ulPattern] and
/// [olPattern] match up; in both, [2] is the length of the number that begins
/// the list marker.
final ulPattern = RegExp(r'^[ ]{0,3}()[*+-](?:[ \t]+(.*))?$');

/// A line starting with a number like `123.`. May have up to three leading
/// spaces before the marker and any number of spaces or tabs after.
final olPattern = RegExp(r'^[ ]{0,3}(\d{1,9})[\.)](?:[ \t]+(.*))?$');

/// A line of hyphens separated by at least one pipe.
final tablePattern = RegExp(
    r'^[ ]{0,3}\|?([ \t]*:?\-+:?[ \t]*\|)+([ \t]|[ \t]*:?\-+:?[ \t]*)?$');

/// A pattern which should never be used. It just satisfies non-nullability of
/// pattern fields.
final dummyPattern = RegExp('');

/// A line starts with `[`.
final linkReferenceDefinitionPattern = RegExp(r'[ ]{0,3}\[');

final htmlBlockPattern = RegExp(
    '^ {0,3}(?:'
    '<(pre|script|style|textarea)'
    r'(?:\s|>|$)'
    '|'
    '(<!--)'
    '|'
    r'(<\?)'
    '|'
    '(<![a-z])'
    '|'
    r'(<!\[CDATA\[)'
    '|'
    '</?(address|article|aside|base|basefont|blockquote|body|'
    'caption|center|col|colgroup|dd|details|dialog|dir|DIV|dl|dt|fieldset|'
    'figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|'
    'header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|'
    'optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|'
    'thead|title|tr|track|ul)'
    r'(?:\s|>|/>|$)'
    '|'

    // Here is more restricted than the commonmark definition(Rule #7).
    // Otherwise some raw HTML test cases will fail, for example:
    // https://spec.commonmark.org/0.30/#example-618.
    // Because if a line is treated as a HTML block, it will output as Text node
    // directly, the RawHtmlSyntax does not have a chance to validate if this
    // HTML tag is legal or not.
    '((?:$_namedTagDefinition)\\s*\$))',
    caseSensitive: false);

/// A pattern matches raw HTML.
// See https://spec.commonmark.org/0.30/#raw-html.
final rawHtmlPattern = RegExp(
  '(?:$_namedTagDefinition)'
  '|'

  // HTML comment, see
  // https://spec.commonmark.org/0.30/#html-comment.
  '<!--(?:(?:[^-<>]+-[^-<>]+)+|[^-<>]+)-->'
  '|'

  // Processing-instruction, see
  // https://spec.commonmark.org/0.30/#processing-instruction
  r'<\?.*?\?>'
  '|'

  // Peclaration, see
  // https://spec.commonmark.org/0.30/#declaration.
  '(<![a-z]+.*?>)'
  '|'

  // CDATA section, see
  // https://spec.commonmark.org/0.30/#cdata-section.
  r'(<!\[CDATA\[.*?]]>)',
  caseSensitive: false,
  multiLine: true,
);

/// A [String] pattern to match a named tag like `<table>` or `</table>`.
final _namedTagDefinition =
    // Open tag begins.
    '<'

    // Tag name.
    '[a-z][a-z0-9-]*'

    // Attribute begin, see
    // https://spec.commonmark.org/0.30/#attribute.
    r'(?:\s+'

    // Attribute name, see
    // https://spec.commonmark.org/0.30/#attribute-name.
    '[a-z_:][a-z0-9._:-]*'
    //
    '(?:'
    // Attribute value specification, see
    // https://spec.commonmark.org/0.30/#attribute-value-specification.
    r'\s*=\s*'

    // Attribute value, see
    // https://spec.commonmark.org/0.30/#unquoted-attribute-value.
    r'''(?:[^\s"'=<>`]+?|'[^']*?'|"[^"]*?")'''

    //  Attribute end.
    ')?)*'

    // Tag end
    r'\s*/?>'

    // or
    '|'

    // Closing tag, see
    // https://spec.commonmark.org/0.30/#closing-tag.
    r'</[a-z][a-z0-9-]*\s*>';

/// According to
/// [CommonMark](https://spec.commonmark.org/0.30/#unicode-punctuation-character):
///
/// > A punctuation character is an ASCII punctuation character or anything in
/// > the general Unicode categories `Pc`, `Pd`, `Pe`, `Pf`, `Pi`, `Po`, or
/// > `Ps`.
// This RegExp is inspired by
// https://github.com/commonmark/commonmark.js/blob/1f7d09099c20d7861a674674a5a88733f55ff729/lib/inlines.js#L39.
// I don't know if there is any way to simplify it or maintain it.
final RegExp unicodePunctuationPattern = RegExp('['
    '$asciiPunctuationEscaped'
    r'\xA1\xA7\xAB\xB6\xB7\xBB\xBF\u037E\u0387\u055A-\u055F\u0589\u058A\u05BE'
    r'\u05C0\u05C3\u05C6\u05F3\u05F4\u0609\u060A\u060C\u060D\u061B\u061E'
    r'\u061F\u066A-\u066D\u06D4\u0700-\u070D\u07F7-\u07F9\u0830-\u083E\u085E'
    r'\u0964\u0965\u0970\u0AF0\u0DF4\u0E4F\u0E5A\u0E5B\u0F04-\u0F12\u0F14'
    r'\u0F3A-\u0F3D\u0F85\u0FD0-\u0FD4\u0FD9\u0FDA\u104A-\u104F\u10FB'
    r'\u1360-\u1368\u1400\u166D\u166E\u169B\u169C\u16EB-\u16ED\u1735\u1736'
    r'\u17D4-\u17D6\u17D8-\u17DA\u1800-\u180A\u1944\u1945\u1A1E\u1A1F'
    r'\u1AA0-\u1AA6\u1AA8-\u1AAD\u1B5A-\u1B60\u1BFC-\u1BFF\u1C3B-\u1C3F\u1C7E'
    r'\u1C7F\u1CC0-\u1CC7\u1CD3\u2010-\u2027\u2030-\u2043\u2045-\u2051'
    r'\u2053-\u205E\u207D\u207E\u208D\u208E\u2308-\u230B\u2329\u232A'
    r'\u2768-\u2775\u27C5\u27C6\u27E6-\u27EF\u2983-\u2998\u29D8-\u29DB\u29FC'
    r'\u29FD\u2CF9-\u2CFC\u2CFE\u2CFF\u2D70\u2E00-\u2E2E\u2E30-\u2E42'
    r'\u3001-\u3003\u3008-\u3011\u3014-\u301F\u3030\u303D\u30A0\u30FB\uA4FE'
    r'\uA4FF\uA60D-\uA60F\uA673\uA67E\uA6F2-\uA6F7\uA874-\uA877\uA8CE\uA8CF'
    r'\uA8F8-\uA8FA\uA8FC\uA92E\uA92F\uA95F\uA9C1-\uA9CD\uA9DE\uA9DF'
    r'\uAA5C-\uAA5F\uAADE\uAADF\uAAF0\uAAF1\uABEB\uFD3E\uFD3F\uFE10-\uFE19'
    r'\uFE30-\uFE52\uFE54-\uFE61\uFE63\uFE68\uFE6A\uFE6B\uFF01-\uFF03'
    r'\uFF05-\uFF0A\uFF0C-\uFF0F\uFF1A\uFF1B\uFF1F\uFF20\uFF3B-\uFF3D\uFF3F'
    r'\uFF5B\uFF5D\uFF5F-\uFF65'
    ']');

// ASCII punctuation characters, see
// https://spec.commonmark.org/0.30/#unicode-whitespace-character.
const asciiPunctuationCharacters = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

const asciiPunctuationEscaped = r'''!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~''';

/// Whitespace character.
// See https://github.github.com/gfm/#whitespace-character.
final String whitespaceCharacters = '\u0020\u0009\u000A\u000C\u000D\u000B';

// final String asciiPunctuationCharacters = '!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~';

/// Unicode whitespace.
// See https://spec.commonmark.org/0.30/#unicode-whitespace-character.
// Unicode Zs: https://www.compart.com/en/unicode/category.
final String unicodeWhitespaceCharacters = '\u0020\u0009\u000A\u000C\u000D'
    '\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008'
    '\u2009\u200A\u202F\u205F\u3000';
