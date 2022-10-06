// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

// Generates and updates unicode case folding map.
// Here only extract status C + F capital letters.
void main() {
  final root = File(Platform.script.path).parent.parent.path;
  // Downloaded from http://www.unicode.org/Public/14.0.0/ucd/CaseFolding.txt
  final file = File('$root/tool/case_folding.txt');
  final text = file.readAsStringSync();
  final lines = LineSplitter().convert(text);

  final result = <String, String>{};

  for (final line in lines) {
    if (line.startsWith('#') ||
        line.trim().isEmpty ||
        !line.contains('CAPITAL LETTER')) {
      continue;
    }

    final content = line.substring(0, line.indexOf('#'));
    final match =
        RegExp(r'([0-9A-F]{1,6});\s+[CF];\s+(.+);').firstMatch(content);
    if (match == null) {
      continue;
    }

    final key = String.fromCharCode(int.parse(match[1]!, radix: 16));
    final value = match[2]!.split(RegExp('[ ]+')).map((e) {
      return String.fromCharCode(int.parse(e, radix: 16));
    }).join();
    result[key] = value;
  }

  final outputPath = '$root/lib/src/assets/case_folding.dart';
  final stringMap = JsonEncoder.withIndent('  ').convert(result);
  final output = '''
// Generated file. do not edit.
//
// Source: tool/case_folding.txt
// Script: tool/update_case_folding.dart
// ignore_for_file: prefer_single_quotes

const caseFoldingMap = $stringMap;
''';
  File(outputPath).writeAsStringSync(output);
}
