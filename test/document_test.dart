// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  group('Document', () {
    test('encodeHtml prevents less than and ampersand escaping', () {
      var document = Document(encodeHtml: false);
      var result = document.parseInline('< &');
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Text>()
              .having((e) => e.text, 'text', equals('< &')));
    });

    test('encodeHtml true allow code block escaping', () {
      var document = Document(encodeHtml: true);
      var result = document.parseInline("```<p>Hello <em>Markdown</em></p>```");
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Element>().having(
              (e) => e.textContent,
              'text',
              equals(
                  "&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;")));
    });

    test('encodeHtml false prevents code block escaping', () {
      var document = Document(encodeHtml: false);
      var result = document.parseInline("```<p>Hello <em>Markdown</em></p>```");
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Element>().having((e) => e.textContent, 'text',
              equals("<p>Hello <em>Markdown</em></p>")));
    });

    test('encodeHtml true allow code block escaping (BlockParser)', () {
      var document = Document(encodeHtml: true);
      var lines = "```\n<p>Hello <em>Markdown</em></p>\n```\n".split('\n');
      var result = document.parseLines(lines);
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Element>().having(
              (e) => e.textContent,
              'text',
              equals(
                  "&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n")));
    });

    test('encodeHtml false prevents code block escaping (BlockParser)', () {
      var document = Document(encodeHtml: false);
      var lines = "```\n<p>Hello <em>Markdown</em></p>\n```\n".split('\n');
      var result = document.parseLines(lines);
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Element>().having((e) => e.textContent, 'text',
              equals("<p>Hello <em>Markdown</em></p>\n")));
    });
  });
}
