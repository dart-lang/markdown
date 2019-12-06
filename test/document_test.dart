// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

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

    group('with encodeHtml enabled', () {
      var document = Document(encodeHtml: true);

      test('encodes HTML in an inline code snippet', () {
        var result = document.parseInline('``<p>Hello <em>Markdown</em></p>``');
        var codeSnippet = result.single as Element;
        expect(codeSnippet.textContent,
            equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;'));
      });

      test('encodes HTML in a fenced code block', () {
        var lines = '```\n<p>Hello <em>Markdown</em></p>\n```\n'.split('\n');
        var result = document.parseLines(lines);
        var codeBlock = result.single as Element;
        expect(codeBlock.textContent,
            equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'));
      });

      test('encodes HTML in an indented code block', () {
        var lines = '    <p>Hello <em>Markdown</em></p>\n'.split('\n');
        var result = document.parseLines(lines);
        var codeBlock = result.single as Element;
        expect(codeBlock.textContent,
            equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'));
      });

      test('encodeHtml spaces are preserved in text', () {
        // Example to get a <p> tag rendered before a text node.
        var contents = 'Sample\n\n<pre>\n A\n B\n</pre>';
        var document = Document(encodeHtml: true);
        var lines = LineSplitter.split(contents).toList();
        var nodes = BlockParser(lines, document).parseLines();
        var result = HtmlRenderer().render(nodes);
        expect(result, '<p>\n</p><pre>\n A\n B\n</pre>');
      });
    });

    group('with encodeHtml disabled', () {
      var document = Document(encodeHtml: false);

      test('leaves HTML alone, in a code snippet', () {
        var result =
            document.parseInline('```<p>Hello <em>Markdown</em></p>```');
        var codeSnippet = result.single as Element;
        expect(
            codeSnippet.textContent, equals('<p>Hello <em>Markdown</em></p>'));
      });

      test('leaves HTML alone, in a fenced code block', () {
        var lines = '```\n<p>Hello <em>Markdown</em></p>\n```\n'.split('\n');
        var result = document.parseLines(lines);
        var codeBlock = result.single as Element;
        expect(
            codeBlock.textContent, equals('<p>Hello <em>Markdown</em></p>\n'));
      });

      test('leaves HTML alone, in an indented code block', () {
        var lines = '    <p>Hello <em>Markdown</em></p>\n'.split('\n');
        var result = document.parseLines(lines);
        var codeBlock = result.single as Element;
        expect(
            codeBlock.textContent, equals('<p>Hello <em>Markdown</em></p>\n'));
      });
    });
  });
}
