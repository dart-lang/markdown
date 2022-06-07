// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/src/extensions.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  group('for String', () {
    test('indentation()', () {
      expect("\tFoo".indentation(), 4);
      expect("\tFoo".indentation(2), 2);
      expect("\tFoo".indentation(8), 8);
      expect(" \tFoo".indentation(), 4);
      expect("  \tFoo".indentation(), 4);
      expect("   \tFoo".indentation(), 4);
      expect("    \tFoo".indentation(), 8);
      expect("\t Foo".indentation(), 5);
      expect(" \t Foo".indentation(), 5);
      expect("  \t Foo".indentation(), 5);
      expect("   \t Foo".indentation(), 5);
      expect("    \t Foo".indentation(), 9);
    });
  });
  group('for SourceSpan', () {
    group('trim functions', () {
      final span = _createSpan('hey \n foo\n bar').subspan(3, 11);

      test('trim()', () {
        final result = span.trim();
        expect(result.start, equals(SourceLocation(6, line: 1, column: 1)));
        expect(result.end, equals(SourceLocation(9, line: 1, column: 4)));
        expect(result.text, equals('foo'));
      });

      test('trimLeft()', () {
        final result = span.trimLeft();
        expect(result.start, equals(SourceLocation(6, line: 1, column: 1)));
        expect(result.end, equals(SourceLocation(11, line: 2, column: 1)));
        expect(result.text, equals('foo\n '));
      });

      test('trimRight()', () {
        final result = span.trimRight();
        expect(result.start, equals(SourceLocation(3, line: 0, column: 3)));
        expect(result.end, equals(SourceLocation(9, line: 1, column: 4)));
        expect(result.text, equals(' \n foo'));
      });
    });
    group('for indent()', () {
      test(r'contains no tab(\t)', () {
        final span = _createSpan('   foo');

        expect(span.indent().span.text, 'foo');
        expect(span.indent(5).span.text, 'foo');
        expect(span.indent(2).span.text, ' foo');
      });

      test(r'contains tab(\t)', () {
        expect(_indent(_createSpan('\tfoo')), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan(' \tfoo')), {
          'text': 'foo',
          'tabRemaining': 1,
        });
        expect(_indent(_createSpan('  \tfoo')), {
          'text': 'foo',
          'tabRemaining': 2,
        });
        expect(_indent(_createSpan('   \tfoo')), {
          'text': 'foo',
          'tabRemaining': 3,
        });
        expect(_indent(_createSpan('    \tfoo')), {
          'text': '\tfoo',
          'tabRemaining': null,
        });
        expect(_indent(_createSpan(' \tfoo')), {
          'text': 'foo',
          'tabRemaining': 1,
        });
        expect(_indent(_createSpan('\t foo')), {
          'text': ' foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t\tfoo')), {
          'text': '\tfoo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t\tfoo'), 7), {
          'text': 'foo',
          'tabRemaining': 1,
        });
        expect(_indent(_createSpan('\t\tfoo'), 8), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t\tfoo'), 9), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t\t foo'), 9), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t \t foo'), 9), {
          'text': ' foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t \t foo'), 10), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('    \tfoo'), 8), {
          'text': 'foo',
          'tabRemaining': 0,
        });
        expect(_indent(_createSpan('\t    foo'), 8), {
          'text': 'foo',
          'tabRemaining': 0,
        });
      });
    });
  });
}

SourceSpan _createSpan(String text) => SourceFile.fromString(text).span(0);
Map<String, dynamic> _indent(SourceSpan span, [int size = 4]) {
  final indented = span.indent(size);
  return {
    'text': indented.span.text,
    'tabRemaining': indented.tabRemaining,
  };
}
