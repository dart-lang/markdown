// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates and updates HTML entities.
void main() {
  // Original file: https://html.spec.whatwg.org/entities.json
  final file = File('${p.current}/tool/entities.json');
  final json = file.readAsStringSync();
  final map = Map<String, Map<String, dynamic>>.from(jsonDecode(json) as Map);

  final result = <String, String>{};
  for (var name in map.keys) {
    if (name.endsWith(';')) {
      final value = map[name]!['characters'] as String;
      result[name] = value;
    }
  }

  final outputPath = '${p.current}/lib/src/assets/html_entities.dart';
  final stringMap = const JsonEncoder.withIndent('  ')
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
