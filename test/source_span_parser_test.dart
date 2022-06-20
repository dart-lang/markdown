// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/src/extensions.dart';
import 'package:markdown/src/parsers/source_parser.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  test('allows to initinize with empty source', () {
    final parser = SourceParser([]);
    expect(parser.isDone, true);
  });

  group('for isDone()', () {
    final source = SourceFile.fromString('12\n345\n').spans();

    test('with an ending empty line', () {
      final parser = SourceParser(source);

      expect(parser.source.last.text, '');
      expect(parser.position, 0);

      parser.advanceBy(6);
      expect(parser.stringAt(), '\n');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });

    test('without an ending empty line', () {
      final parser = SourceParser(source.sublist(0, source.length - 1));

      expect(parser.source.last.text, '345\n');
      expect(parser.position, 0);

      parser.advanceBy(6);
      expect(parser.stringAt(), '\n');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });

    test('without a trailing newline', () {
      final parser = SourceParser([
        source[0],
        source[1].trim(),
      ]);

      expect(parser.source.last.text, '345');
      expect(parser.position, 0);

      parser.advanceBy(5);
      expect(parser.stringAt(), '5');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });
  });

  group('for moveThroughWhitespace()', () {
    final source = SourceFile.fromString(' \t\n bar').spans();
    test('with `multiLine` enabled', () {
      final parser = SourceParser(source);
      final steps = parser.moveThroughWhitespace(multiLine: true);
      expect(steps, 4);
      expect(parser.stringAt(), 'b');
    });

    test('with `multiLine` disabled', () {
      final parser = SourceParser(source);
      final steps = parser.moveThroughWhitespace();
      expect(steps, 2);
      expect(parser.stringAt(), '\n');
    });
  });

  group('for subspan()', () {
    test('with line feed ending', () {
      final source = SourceFile.fromString('1234\n').span(0);
      final parser = SourceParser([
        source.subspan(0, 1),
        source.subspan(2),
      ]);
      final result = parser.subspan(0, 4);
      expect(result.map((e) => e.text).join(), '134\n');
    });

    test('without line feed ending', () {
      final source = SourceFile.fromString('12345').span(0);
      final parser = SourceParser([
        source.subspan(0, 1),
        source.subspan(2),
      ]);
      final result = parser.subspan(0, 4);
      expect(result.map((e) => e.text).join(), '1345');
    });
  });

  group('test with complex segments', () {
    final spans = SourceFile.fromString('''
12
    
   3456  
 789  

  abc de 
fg   

''').spans();

    final source = [
      spans[1],
      spans[3].trim(),
      spans[5].subspan(0, 4),
      spans[5].subspan(4).union(spans[6]),
      spans[7],
    ];

    late SourceParser parser;

    setUp(() {
      parser = SourceParser(source);
    });

    test('validate source data', () {
      expect(source.length, 5);
      expect(source[0].text, '    \n');
      expect(source[1].text, '789');
      expect(source[2].text, '  ab');
      expect(source[3].text, 'c de \nfg   \n');
      expect(source[4].text, '\n');
    });

    group('stringAt()', () {
      test('get a char from a position', (() {
        expect(parser.stringAt(0), ' ');
        expect(parser.stringAt(3), ' ');
        expect(parser.stringAt(17), '\n');
        expect(parser.stringAt(18), 'f');
        expect(parser.stringAt(24), '\n');
      }));

      test('throws an error when stringAt the ending position', () {
        expect(() => parser.stringAt(25), throwsArgumentError);
      });
    });

    group('toSourceLocation()', () {
      test('works with valid positions', () {
        expect(
          parser
              .toSourceLocation(0)
              .equals(SourceLocation(3, line: 1, column: 0)),
          true,
        );
        expect(
          parser
              .toSourceLocation(17)
              .equals(SourceLocation(35, line: 5, column: 9)),
          true,
        );
        expect(
          parser
              .toSourceLocation(18)
              .equals(SourceLocation(36, line: 6, column: 0)),
          true,
        );
      });

      test('works for the ending position', () {
        final position = 25;

        expect(
          parser
              .toSourceLocation(position)
              .equals(SourceLocation(43, line: 8, column: 0)),
          true,
        );
      });
    });

    group('advanceBy()', () {
      test('moves the position forward and backward', () {
        expect(parser.position, 0);

        parser.advanceBy(7);
        expect(parser.stringAt(), '9');

        parser.advance();
        expect(parser.stringAt(), ' ');

        parser.advanceBy(3);
        expect(parser.stringAt(), 'b');

        parser.advanceBy(-4);
        expect(parser.stringAt(), '9');

        parser.advanceBy(-7);
        expect(parser.position, 0);
      });
    });

    group('getText()', () {
      test('same index for start and end', (() {
        final segments = parser.subspan(6, 7);

        expect(segments.length, 1);
        expect(segments.first.text, '8');
      }));

      test('end is at the beginning', (() {
        final segments = parser.subspan(6, 8);

        expect(segments.length, 1);
        expect(segments[0].toMap(), {
          "start": {"line": 3, "column": 2, "offset": 20},
          "end": {"line": 3, "column": 4, "offset": 22},
          "text": "89"
        });
      }));

      test('no end position specified', (() {
        final segments = parser.subspan(6);

        expect(segments.length, 4);
        expect(segments.map((e) => e.text).join(), '89  abc de \nfg   \n\n');
      }));

      test('across several segments but actually are in the same line', (() {
        final segments = parser.subspan(6, 15);

        expect(segments[0].toMap(), {
          "start": {"line": 3, "column": 2, "offset": 20},
          "end": {"line": 3, "column": 4, "offset": 22},
          "text": "89"
        });

        expect(segments[1].toMap(), {
          "start": {"line": 5, "column": 0, "offset": 26},
          "end": {"line": 5, "column": 4, "offset": 30},
          "text": "  ab"
        });

        expect(segments[2].toMap(), {
          "start": {"line": 5, "column": 4, "offset": 30},
          "end": {"line": 5, "column": 7, "offset": 33},
          "text": "c d",
        });

        expect(segments.map((e) => e.text).join(), '89  abc d');
      }));

      test('from a segment which has a multiple line text', (() {
        final segments = parser.subspan(14, 21);

        expect(segments[0].toMap(), {
          "start": {"line": 5, "column": 6, "offset": 32},
          "end": {"line": 6, "column": 3, "offset": 39},
          "text": "de \nfg "
        });
      }));
    });
  });
}
