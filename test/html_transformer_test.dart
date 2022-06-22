// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('encodeHtml', () {
    test('encodeHtml prevents less than and ampersand escaping', () {
      final nodes = Document().parseInline('< &');
      final result = HtmlTransformer(encodeHtml: false).transform(nodes);
      expect(result, hasLength(1));
      expect(
        result[0],
        const TypeMatcher<HtmlText>().having(
          (e) => e.text,
          'text',
          equals('< &'),
        ),
      );
    });
  });
  group('with encodeHtml enabled', () {
    final document = Document();

    test('encodes HTML in an inline code snippet', () {
      final nodes = document.parseInline('``<p>Hello <em>Markdown</em></p>``');
      final result = HtmlTransformer(encodeHtml: true).transform(nodes);
      final codeSnippet = result.single as HtmlElement;
      expect(
        codeSnippet.textContent,
        equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;'),
      );
    });

    test('encodes HTML in a fenced code block', () {
      final content = '```\n<p>Hello <em>Markdown</em></p>\n```\n';
      final nodes = document.parseLines(content);
      final result = HtmlTransformer(encodeHtml: true).transform(nodes);
      final codeBlock = result.single as HtmlElement;
      expect(
        codeBlock.textContent,
        equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'),
      );
    });

    test('encodes HTML in an indented code block', () {
      final content = '    <p>Hello <em>Markdown</em></p>\n';
      final nodes = document.parseLines(content);
      final result = HtmlTransformer(encodeHtml: true).transform(nodes);
      final codeBlock = result.single as HtmlElement;
      expect(
        codeBlock.textContent,
        equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'),
      );
    });

    test('encodeHtml spaces are preserved in text', () {
      // Example to get a <p> tag rendered before a text node.
      final content = 'Sample\n\n<pre>\n A\n B\n</pre>';
      final lines = stringToLines(content);
      final nodes = BlockParser(lines, document).parseLines();
      final htmlNodes = HtmlTransformer(encodeHtml: true).transform(nodes);
      final result = HtmlRenderer().render(htmlNodes);
      expect(result, '<p></p>\n<pre>\n A\n B\n</pre>');
    });

    test('encode double quotes, greater than, and less than when escaped', () {
      final contents = r'\>\"\< Hello';
      final nodes = document.parseInline(contents);
      final result = HtmlTransformer(encodeHtml: true).transform(nodes);
      expect(result, hasLength(4));
      expect(
        result.map((e) => (e as HtmlText).text).join(),
        '&gt;&quot;&lt; Hello',
      );
    });
  });

  group('with encodeHtml disabled', () {
    final document = Document();

    test('leaves HTML alone, in a code snippet', () {
      final nodes =
          document.parseInline('```<p>Hello <em>Markdown</em></p>```');
      final result = HtmlTransformer(encodeHtml: false).transform(nodes);

      final codeSnippet = result.single as HtmlElement;
      expect(
        codeSnippet.textContent,
        equals('<p>Hello <em>Markdown</em></p>'),
      );
    });

    test('leaves HTML alone, in a fenced code block', () {
      final content = '```\n<p>Hello <em>Markdown</em></p>\n```\n';
      final nodes = document.parseLines(content);
      final result = HtmlTransformer(encodeHtml: false).transform(nodes);
      final codeBlock = result.single as HtmlElement;
      expect(
        codeBlock.textContent,
        equals('<p>Hello <em>Markdown</em></p>\n'),
      );
    });

    test('leaves HTML alone, in an indented code block', () {
      final content = '    <p>Hello <em>Markdown</em></p>\n';
      final nodes = document.parseLines(content);
      final result = HtmlTransformer(encodeHtml: false).transform(nodes);
      final codeBlock = result.single as HtmlElement;
      expect(
        codeBlock.textContent,
        equals('<p>Hello <em>Markdown</em></p>\n'),
      );
    });

    test('leave double quotes, greater than, and less than when escaped', () {
      final contents = r'\>\"\< Hello';
      final nodes = document.parseInline(contents);
      final result = HtmlTransformer(encodeHtml: false).transform(nodes);
      expect(result, hasLength(4));
      expect(
        result.map((e) => (e as HtmlText).text).join(),
        '>"< Hello',
      );
    });
  });
}
