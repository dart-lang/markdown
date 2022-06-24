// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:markdown/src/reverse_renderer.dart';
import 'package:path/path.dart' as p;
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() async {
  await testCases('common_mark');
  await testCases('gfm');
}

Future<void> testCases(String name) async {
  final fileName = {
    'common_mark': 'tool/common_mark_tests.json',
    'gfm': 'tool/gfm_tests.json'
  }[name];

  final url = {
    'common_mark': 'https://spec.commonmark.org/0.30',
    'gfm': 'https://github.github.com/gfm'
  }[name];

  final packageUri = Uri.parse('package:markdown/markdown.dart');
  final isolateUri = await Isolate.resolvePackageUri(packageUri);
  final rootDir = p.dirname(p.dirname(isolateUri!.toFilePath()));
  final file = File('$rootDir/$fileName');
  final json = file.readAsStringSync();
  final testCases = List<Map<String, dynamic>>.from(jsonDecode(json) as List);

  for (final testCase in testCases) {
    final description = '$url/#example-${testCase['example']}';
    test(description, () {
      final input = testCase['markdown'] as String;

      // TODO(Zhiguang): Fix the `\t` issue.
      // Skip the cases contain `\t`.
      if (RegExp('\t').hasMatch(input)) {
        return;
      }

      final output = markdownToMarkdown(input);

      expect(output, input);
    });
  }
}
