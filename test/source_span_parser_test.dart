import 'package:markdown/src/extensions.dart';
import 'package:markdown/src/source_span_parser.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  test('allows to initinize with empty source', () {
    final parser = SourceSpanParser([]);
    expect(parser.isDone, true);
  });

  group('for isEndingPosition()', () {
    final source = SourceFile.fromString('12\n').spans();

    test('with an ending empty line', () {
      final parser = SourceSpanParser(source);

      expect(parser.source.last.text, '');
      expect(parser.isEndingPosition(SourcePosition(1, 0)), true);
      expect(parser.isEndingPosition(SourcePosition(0, 2)), false);
      expect(
        () => parser.isEndingPosition(SourcePosition(1, 1)),
        throwsArgumentError,
      );
      expect(
        () => parser.isEndingPosition(SourcePosition(0, 3)),
        throwsArgumentError,
      );
    });

    test('without an ending empty line', () {
      final parser = SourceSpanParser([source.first]);

      expect(parser.source.last.text, '12\n');

      expect(parser.isEndingPosition(SourcePosition(1, 0)), true);
      expect(parser.isEndingPosition(SourcePosition(0, 2)), false);
      expect(
        () => parser.isEndingPosition(SourcePosition(1, 1)),
        throwsArgumentError,
      );
      expect(
        () => parser.isEndingPosition(SourcePosition(0, 3)),
        throwsArgumentError,
      );
    });

    test('without a trailing newline', () {
      final parser = SourceSpanParser([source.first.trim()]);

      expect(parser.source.last.text, '12');

      expect(parser.isEndingPosition(SourcePosition(0, 2)), true);
      expect(parser.isEndingPosition(SourcePosition(0, 1)), false);
      expect(
        () => parser.isEndingPosition(SourcePosition(0, 3)),
        throwsArgumentError,
      );
      expect(
        () => parser.isEndingPosition(SourcePosition(1, 0)),
        throwsArgumentError,
      );
    });
  });

  group('for isDone()', () {
    final source = SourceFile.fromString('12\n345\n').spans();

    test('with an ending empty line', () {
      final parser = SourceSpanParser(source);

      expect(parser.source.last.text, '');
      expect(parser.position, SourcePosition(0, 0));

      parser.advanceBy(6);
      expect(parser.stringAt(parser.position), '\n');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });

    test('without an ending empty line', () {
      final parser = SourceSpanParser(source.sublist(0, source.length - 1));

      expect(parser.source.last.text, '345\n');
      expect(parser.position, SourcePosition(0, 0));

      parser.advanceBy(6);
      expect(parser.stringAt(parser.position), '\n');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });

    test('without a trailing newline', () {
      final parser = SourceSpanParser([
        source[0],
        source[1].trim(),
      ]);

      expect(parser.source.last.text, '345');
      expect(parser.position, SourcePosition(0, 0));

      parser.advanceBy(5);
      expect(parser.stringAt(parser.position), '5');
      expect(parser.isDone, false);

      parser.advance();
      expect(parser.isDone, true);
    });
  });

  group('for moveThroughWhitespace()', () {
    final source = SourceFile.fromString(' \t\n bar').spans();
    test('with `multiLine` enabled', () {
      final parser = SourceSpanParser(source);
      final steps = parser.moveThroughWhitespace(multiLine: true);
      expect(steps, 4);
      expect(parser.stringAt(), 'b');
    });

    test('with `multiLine` disabled', () {
      final parser = SourceSpanParser(source);
      final steps = parser.moveThroughWhitespace();
      expect(steps, 2);
      expect(parser.stringAt(), '\n');
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

    late SourceSpanParser parser;

    setUp(() {
      parser = SourceSpanParser(source);
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
        expect(parser.stringAt(SourcePosition(0, 0)), ' ');
        expect(parser.stringAt(SourcePosition(0, 3)), ' ');
        expect(parser.stringAt(SourcePosition(3, 5)), '\n');
        expect(parser.stringAt(SourcePosition(3, 6)), 'f');
        expect(parser.stringAt(SourcePosition(4, 0)), '\n');
      }));

      test('throws an error when stringAt the ending position', () {
        final position = SourcePosition(5, 0);

        expect(parser.isEndingPosition(position), true);
        expect(() => parser.stringAt(position), throwsArgumentError);
      });
    });

    group('positionToLocation()', () {
      test('works with valid positions', () {
        expect(
          parser
              .positionToLocation(SourcePosition(0, 0))
              .equals(SourceLocation(3, line: 1, column: 0)),
          true,
        );
        expect(
          parser
              .positionToLocation(SourcePosition(3, 5))
              .equals(SourceLocation(35, line: 5, column: 9)),
          true,
        );
        expect(
          parser
              .positionToLocation(SourcePosition(3, 6))
              .equals(SourceLocation(36, line: 6, column: 0)),
          true,
        );
      });

      test('works for the ending position', () {
        final position = SourcePosition(5, 0);

        expect(parser.isEndingPosition(position), true);
        expect(
          parser
              .positionToLocation(position)
              .equals(SourceLocation(43, line: 8, column: 0)),
          true,
        );
      });
    });

    group('advanceBy()', () {
      test('moves the position forward and backward', () {
        expect(parser.position, SourcePosition(0, 0));

        parser.advanceBy(7);
        expect(parser.stringAt(parser.position), '9');

        parser.advance();
        expect(parser.stringAt(parser.position), ' ');

        parser.advanceBy(3);
        expect(parser.stringAt(parser.position), 'b');

        parser.advanceBy(-4);
        expect(parser.stringAt(parser.position), '9');

        parser.advanceBy(-7);
        expect(parser.position, SourcePosition(0, 0));
      });
    });

    group('getText()', () {
      test('same index for start and end', (() {
        final segments = parser.subText(
          SourcePosition(1, 1),
          SourcePosition(1, 3),
        );

        expect(segments.length, 1);
        expect(segments.first.text, '89');
      }));

      test('end is at the beginning', (() {
        final segments = parser.subText(
          SourcePosition(1, 1),
          SourcePosition(2, 0),
        );

        expect(segments.length, 1);
        expect(segments[0].toMap(), {
          "start": {"line": 3, "column": 2, "offset": 20},
          "end": {"line": 3, "column": 4, "offset": 22},
          "text": "89"
        });
      }));

      test('no end position specified', (() {
        final segments = parser.subText(
          SourcePosition(1, 1),
        );

        expect(segments.length, 4);
        expect(segments.map((e) => e.text).join(), '89  abc de \nfg   \n\n');
      }));

      test('across several segments which are in the same line', (() {
        final segments = parser.subText(
          SourcePosition(1, 1),
          SourcePosition(3, 3),
        );

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
        final segments = parser.subText(
          SourcePosition(3, 2),
          SourcePosition(3, 9),
        );

        expect(segments[0].toMap(), {
          "start": {"line": 5, "column": 6, "offset": 32},
          "end": {"line": 6, "column": 3, "offset": 39},
          "text": "de \nfg "
        });
      }));
    });

    group('positionToOffset()', () {
      test('get a global offset', () {
        expect(parser.positionToOffset(SourcePosition(0, 0)), 0);
        expect(parser.positionToOffset(SourcePosition(3, 5)), 17);
        expect(parser.positionToOffset(SourcePosition(4, 0)), 24);
      });
    });
    group('matchFromStart()', () {
      final position = SourcePosition(1, 0);
      test('without capturing', () {
        const pattern = r'\d+\d\s+\w+\s+\w+\s+\w\w+';
        final text = parser.matchFromStart(
          RegExp(pattern, multiLine: true),
          position,
        );
        expect(
          text.map((e) => e.map((e) => e.toMap()).toList()).toList(),
          [
            [
              {
                "start": {"line": 3, "column": 1, "offset": 19},
                "end": {"line": 3, "column": 4, "offset": 22},
                "text": "789"
              },
              {
                "start": {"line": 5, "column": 0, "offset": 26},
                "end": {"line": 5, "column": 4, "offset": 30},
                "text": "  ab"
              },
              {
                "start": {"line": 5, "column": 4, "offset": 30},
                "end": {"line": 6, "column": 2, "offset": 38},
                "text": "c de \nfg"
              },
            ],
          ],
        );
      });
      test('with capturing', () {
        const pattern = r'\d+(\d\s+\w+)\s+(\w+\s+\w)\w+';
        final text = parser.matchFromStart(
          RegExp(pattern, multiLine: true),
          position,
        );
        expect(text.map((e) => e.map((e) => e.toMap()).toList()).toList(), [
          [
            {
              "start": {"line": 3, "column": 3, "offset": 21},
              "end": {"line": 3, "column": 4, "offset": 22},
              "text": "9"
            },
            {
              "start": {"line": 5, "column": 0, "offset": 26},
              "end": {"line": 5, "column": 4, "offset": 30},
              "text": "  ab"
            },
            {
              "start": {"line": 5, "column": 4, "offset": 30},
              "end": {"line": 5, "column": 5, "offset": 31},
              "text": "c"
            },
          ],
          [
            {
              "start": {"line": 5, "column": 6, "offset": 32},
              "end": {"line": 6, "column": 1, "offset": 37},
              "text": "de \nf"
            },
          ],
        ]);
      });
    });
  });
}
