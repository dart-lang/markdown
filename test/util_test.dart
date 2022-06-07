// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  group("for stringToLines()", () {
    test('a single line without a line ending', () {
      final text = 'Foo';
      final lines = stringToLines(text);
      expect(lines.map((e) => e.toMap()), [
        {
          "text": "Foo",
          "content": {
            "start": {"line": 0, "column": 0, "offset": 0},
            "end": {"line": 0, "column": 3, "offset": 3},
            "text": "Foo"
          },
          "lineEnding": null,
          "start": {"line": 0, "column": 0, "offset": 0},
          "end": {"line": 0, "column": 3, "offset": 3},
          "isBlankLine": false,
          "tabRemaining": null,
        }
      ]);
    });

    test('a single line with a line ending', () {
      final text = 'Foo\n';
      final lines = stringToLines(text);
      expect(lines.map((e) => e.toMap()), [
        {
          "text": "Foo\n",
          "content": {
            "start": {"line": 0, "column": 0, "offset": 0},
            "end": {"line": 0, "column": 3, "offset": 3},
            "text": "Foo"
          },
          "lineEnding": {
            "start": {"line": 0, "column": 3, "offset": 3},
            "end": {"line": 1, "column": 0, "offset": 4},
            "text": "\n"
          },
          "start": {"line": 0, "column": 0, "offset": 0},
          "end": {"line": 1, "column": 0, "offset": 4},
          "isBlankLine": false,
          "tabRemaining": null,
        },
        {
          "text": "",
          "content": {
            "start": {"line": 1, "column": 0, "offset": 4},
            "end": {"line": 1, "column": 0, "offset": 4},
            "text": ""
          },
          "lineEnding": null,
          "start": {"line": 1, "column": 0, "offset": 4},
          "end": {"line": 1, "column": 0, "offset": 4},
          "isBlankLine": true,
          "tabRemaining": null,
        }
      ]);
    });
    test('multiple lines with a blank line in between', () {
      final text = 'Foo\n\nBar';
      final lines = stringToLines(text);
      expect(lines.map((e) => e.toMap()), [
        {
          "text": "Foo\n",
          "content": {
            "start": {"line": 0, "column": 0, "offset": 0},
            "end": {"line": 0, "column": 3, "offset": 3},
            "text": "Foo"
          },
          "lineEnding": {
            "start": {"line": 0, "column": 3, "offset": 3},
            "end": {"line": 1, "column": 0, "offset": 4},
            "text": "\n"
          },
          "start": {"line": 0, "column": 0, "offset": 0},
          "end": {"line": 1, "column": 0, "offset": 4},
          "isBlankLine": false,
          "tabRemaining": null,
        },
        {
          "text": "\n",
          "content": {
            "start": {"line": 1, "column": 0, "offset": 4},
            "end": {"line": 1, "column": 0, "offset": 4},
            "text": ""
          },
          "lineEnding": {
            "start": {"line": 1, "column": 0, "offset": 4},
            "end": {"line": 2, "column": 0, "offset": 5},
            "text": "\n"
          },
          "start": {"line": 1, "column": 0, "offset": 4},
          "end": {"line": 2, "column": 0, "offset": 5},
          "isBlankLine": true,
          "tabRemaining": null,
        },
        {
          "text": "Bar",
          "content": {
            "start": {"line": 2, "column": 0, "offset": 5},
            "end": {"line": 2, "column": 3, "offset": 8},
            "text": "Bar"
          },
          "lineEnding": null,
          "start": {"line": 2, "column": 0, "offset": 5},
          "end": {"line": 2, "column": 3, "offset": 8},
          "isBlankLine": false,
          "tabRemaining": null,
        }
      ]);
    });
  });
  group("for toGroupsWithIndex()", () {
    final text = "> Hello Markdown!";
    test('has no capturing', () {
      final pattern = RegExp(r'^[ ]{0,3}>[ ]?.*$');
      final match = pattern.firstMatch(text);
      final groups = toGroupsWithIndex(match!);

      expect(groups.map((e) => e!.toMap()), [
        {"text": "> Hello Markdown!", "start": 0, "end": 17},
      ]);
    });
    test('has capturing', () {
      final pattern = RegExp(r'^[ ]{0,3}(>)[ ]?(.*)$');
      final match = pattern.firstMatch(text);
      final groups = toGroupsWithIndex(match!);

      expect(groups.map((e) => e!.toMap()), [
        {"text": ">", "start": 0, "end": 1},
        {"text": "Hello Markdown!", "start": 2, "end": 17}
      ]);
    });
  });
}
