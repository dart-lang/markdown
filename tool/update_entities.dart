// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

// Generates and updates HTML entities.
void main() {
  final root = File(Platform.script.path).parent.parent.path;
  // Original file: https://html.spec.whatwg.org/entities.json
  final file = File('$root/tool/entities.json');
  final json = file.readAsStringSync();
  final map = jsonDecode(json) as Map<String, dynamic>;

  final result = <String, String>{};
  for (var name in map.keys) {
    if (name.endsWith(';')) {
      final value = map[name]!['characters'] as String;
      result[name] = value;
    }
  }

  final outputPath = '$root/lib/src/assets/html_entities.dart';
  final stringMap = JsonEncoder.withIndent('  ')
      .convert(result)
      .replaceAll(r'"$"', r'r"$"')
      .replaceAll(r'"\\"', r'r"\"');
  final output = '''
// Generated file. do not edit.
//
// Source: tool/entities.json
// Script: tool/update_entities.dart
// ignore_for_file: prefer_single_quotes

const htmlEntitiesMap = $stringMap;
''';
  File(outputPath).writeAsStringSync(output);
}
