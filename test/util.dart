// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library markdown.test.utils;

import 'package:unittest/unittest.dart';

import 'package:markdown/markdown.dart';

/// Removes eight spaces of leading indentation from a multiline string.
///
/// Note that this is very sensitive to how the literals are styled. They should
/// be:
///     '''
///     Text starts on own line. Lines up with subsequent lines.
///     Lines are indented exactly 8 characters from the left margin.'''
///
/// This does nothing if text is only a single line.
// TODO(nweiz): Make this auto-detect the indentation level from the first
// non-whitespace line.
String cleanUpLiteral(String text) {
  var lines = text.split('\n');
  if (lines.length <= 1) return text;

  for (var j = 0; j < lines.length; j++) {
    if (lines[j].length > 8) {
      lines[j] = lines[j].substring(8, lines[j].length);
    } else {
      lines[j] = '';
    }
  }

  return lines.join('\n');
}

void validate(String description, String markdown, String html,
    {List<InlineSyntax> inlineSyntaxes,
    Resolver linkResolver,
    Resolver imageLinkResolver,
    bool inlineOnly: false}) {
  test(description, () {
    markdown = cleanUpLiteral(markdown);
    html = cleanUpLiteral(html);

    var result = markdownToHtml(markdown,
        inlineSyntaxes: inlineSyntaxes,
        linkResolver: linkResolver,
        imageLinkResolver: imageLinkResolver,
        inlineOnly: inlineOnly);
    var passed = compareOutput(html, result);

    if (!passed) {
      // Remove trailing newline.
      html = html.substring(0, html.length - 1);

      var sb = new StringBuffer();
      sb.writeln('Expected: ${html.replaceAll("\n", "\n          ")}');
      sb.writeln('  Actual: ${result.replaceAll("\n", "\n          ")}');

      fail(sb.toString());
    }
  });
}

/// Does a loose comparison of the two strings of HTML. Ignores differences in
/// newlines and indentation.
bool compareOutput(String a, String b) {
  int i = 0;
  int j = 0;

  skipIgnored(String s, int i) {
    // Ignore newlines.
    while ((i < s.length) && (s[i] == '\n')) {
      i++;
      // Ignore indentation.
      while ((i < s.length) && (s[i] == ' ')) i++;
    }

    return i;
  }

  while (true) {
    i = skipIgnored(a, i);
    j = skipIgnored(b, j);

    // If one string runs out of non-ignored strings, the other must too.
    if (i == a.length) return j == b.length;
    if (j == b.length) return i == a.length;

    if (a[i] != b[j]) return false;
    i++;
    j++;
  }
}
