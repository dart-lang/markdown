// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `http://foo.com`.
class AutolinkExtensionSyntax extends InlineSyntax {
  /// Broken up parts of the autolink regex for reusability and readability

  // Autolinks can only come at the beginning of a line, after whitespace, or
  // any of the delimiting characters *, _, ~, and (.
  static const start = r'(?:^|[\s*_~(>])';

  // An extended url autolink will be recognized when one of the schemes
  // http://, https://, or ftp://, followed by a valid domain
  static const scheme = r'(?:(?:https?|ftp):\/\/|www\.)';

  // A valid domain consists of alphanumeric characters, underscores (_),
  // hyphens (-) and periods (.). There must be at least one period, and no
  // underscores may be present in the last two segments of the domain.
  static const domainPart = r'\w\-';
  static const domain = '[$domainPart][$domainPart.]+';

  // A valid domain consists of alphanumeric characters, underscores (_),
  // hyphens (-) and periods (.).
  static const path = r'[^\s<]*';

  // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will not
  // be considered part of the autolink
  static const truncatingPunctuationPositive = '[?!.,:*_~]';

  static final regExpTrailingPunc = RegExp('$truncatingPunctuationPositive*\$');
  static final regExpEndsWithColon = RegExp(r'\&[a-zA-Z0-9]+;$');
  static final regExpWhiteSpace = RegExp(r'\s');

  AutolinkExtensionSyntax() : super('$start(($scheme)($domain)($path))');

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    return super.tryMatch(parser, parser.pos > 0 ? parser.pos - 1 : 0);
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    var url = match[1]!;
    var href = url;
    var matchLength = url.length;

    if (url[0] == '>' || url.startsWith(regExpWhiteSpace)) {
      url = url.substring(1, url.length - 1);
      href = href.substring(1, href.length - 1);
      parser.pos++;
      matchLength--;
    }

    // Prevent accidental standard autolink matches
    if (url.endsWith('>') && parser.source[parser.pos - 1] == '<') {
      return false;
    }

    // When an autolink ends in ), we scan the entire autolink for the total
    // number of parentheses. If there is a greater number of closing
    // parentheses than opening ones, we don’t consider the last character
    // part of the autolink, in order to facilitate including an autolink
    // inside a parenthesis:
    // https://github.github.com/gfm/#example-600
    if (url.endsWith(')')) {
      final opening = _countChars(url, '(');
      final closing = _countChars(url, ')');

      if (closing > opening) {
        url = url.substring(0, url.length - 1);
        href = href.substring(0, href.length - 1);
        matchLength--;
      }
    }

    // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will
    // not be considered part of the autolink, though they may be included
    // in the interior of the link:
    // https://github.github.com/gfm/#example-599
    final trailingPunc = regExpTrailingPunc.firstMatch(url);
    if (trailingPunc != null) {
      final trailingLength = trailingPunc.match.length;
      url = url.substring(0, url.length - trailingLength);
      href = href.substring(0, href.length - trailingLength);
      matchLength -= trailingLength;
    }

    // If an autolink ends in a semicolon (;), we check to see if it appears
    // to resemble an
    // [entity reference](https://github.github.com/gfm/#entity-references);
    // if the preceding text is & followed by one or more alphanumeric
    // characters. If so, it is excluded from the autolink:
    // https://github.github.com/gfm/#example-602
    if (url.endsWith(';')) {
      final entityRef = regExpEndsWithColon.firstMatch(url);
      if (entityRef != null) {
        // Strip out HTML entity reference
        final entityRefLength = entityRef.match.length;
        url = url.substring(0, url.length - entityRefLength);
        href = href.substring(0, href.length - entityRefLength);
        matchLength -= entityRefLength;
      }
    }

    // The scheme http will be inserted automatically
    if (!href.startsWith('http://') &&
        !href.startsWith('https://') &&
        !href.startsWith('ftp://')) {
      href = 'http://$href';
    }

    final text = parser.encodeHtml ? escapeHtml(url) : url;
    final anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull(href);
    parser.addNode(anchor);

    parser.consume(matchLength);
    return false;
  }

  int _countChars(String input, String char) {
    var count = 0;

    for (var i = 0; i < input.length; i++) {
      if (input[i] == char) count++;
    }

    return count;
  }
}
