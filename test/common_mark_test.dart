// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test/test.dart';

import '../tool/stats_lib.dart';

void main() {
  _registerTests(Config.commonMarkConfig);
  _registerTests(Config.gfmConfig);
}

void _registerTests(Config config) {
  var tests = loadCommonMarkSections(config.prefix);

  var statsFile = getStatsFile(config.prefix);
  var statsJson =
      jsonDecode(statsFile.readAsStringSync()) as Map<String, dynamic>;

  group(config.prefix, () {
    tests.forEach((section, examples) {
      group(section, () {
        var sectionStats = statsJson[section];
        for (var e in examples) {
          test('Example ${e.example}', () {
            var expected = sectionStats[e.example.toString()];

            expect(expected, isNotNull);

            var result = compareResult(config, e, throwOnError: true);

            // not super-pretty way to get the value section of an enum
            var resultString = result.toString().split('.')[1];
            expect(resultString, expected);
          });
        }
      });
    });
  });
}
