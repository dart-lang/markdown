// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  group('test InlineSyntax caseSensitive parameter', () {
    const text = 'one BREAK two';

    test('with caseSensitive enabled', () {
      final result = markdownToHtml(
        text,
        inlineOnly: true,
        inlineSyntaxes: [BreakSyntax(true)],
      );

      expect(result, equals('one BREAK two'));
    });

    test('with caseSensitive disabled', () {
      final result = markdownToHtml(
        text,
        inlineOnly: true,
        inlineSyntaxes: [BreakSyntax(false)],
      );

      expect(result, equals('one <break /> two'));
    });
  });
}

class BreakSyntax extends InlineSyntax {
  BreakSyntax(bool caseSensitive)
      : super('break', caseSensitive: caseSensitive);

  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(Element.empty('break'));
    return true;
  }
}
