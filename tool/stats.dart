// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../tool/expected_output.dart';
import 'stats_lib.dart';

final _configs = List<Config>.unmodifiable([
  Config.commonMarkConfig,
  Config.gfmConfig,
]);

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'section',
      help: 'Restrict tests to one section, provided after the option.',
    )
    ..addFlag(
      'raw',
      help: 'raw JSON format',
      negatable: false,
    )
    ..addFlag(
      'update-files',
      help: 'Update stats files in $toolDir',
      negatable: false,
    )
    ..addFlag(
      'verbose',
      help: 'Print details for failures and errors.',
      negatable: false,
    )
    ..addFlag(
      'verbose-loose',
      help: 'Print details for "loose" matches.',
      negatable: false,
    )
    ..addOption('flavor', allowed: _configs.map((c) => c.prefix))
    ..addFlag('help', negatable: false);

  ArgResults options;

  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e);
    print(parser.usage);
    exitCode = 64; // unix standard improper usage
    return;
  }

  if (options['help'] as bool) {
    print(parser.usage);
    return;
  }

  final specifiedSection = options['section'] as String?;
  final raw = options['raw'] as bool;
  final verbose = options['verbose'] as bool;
  final verboseLooseMatch = options['verbose-loose'] as bool;
  final updateFiles = options['update-files'] as bool;

  if (updateFiles && (raw || verbose || (specifiedSection != null))) {
    stderr.writeln('The `update-files` flag must be used by itself');
    print(parser.usage);
    exitCode = 64; // unix standard improper usage
    return;
  }

  var testPrefix = options['flavor'] as String?;
  if (!updateFiles) {
    testPrefix = _configs.first.prefix;
  }

  final testPrefixes =
      testPrefix == null ? _configs.map((c) => c.prefix) : <String>[testPrefix];

  for (final testPrefix in testPrefixes) {
    await _processConfig(
      testPrefix,
      raw,
      updateFiles,
      verbose,
      specifiedSection,
      verboseLooseMatch,
    );
  }
}

final _sectionNameReplace = RegExp(r'[ \)\(]+');

String _unitOutput(Iterable<DataCase> cases) => cases.map((dataCase) => '''
>>> ${dataCase.front_matter}
${dataCase.input}<<<
${dataCase.expectedOutput}''').join();

/// Set this to `true` and rerun `--update-files` to ease finding easy strict
/// fixes.
const _improveStrict = false;

Future<void> _processConfig(
  String testPrefix,
  bool raw,
  bool updateFiles,
  bool verbose,
  String? specifiedSection,
  bool verboseLooseMatch,
) async {
  final config = _configs.singleWhere((c) => c.prefix == testPrefix);

  final sections = loadCommonMarkSections(testPrefix);

  final scores = SplayTreeMap<String, SplayTreeMap<int, CompareLevel>>(
      compareAsciiLowerCaseNatural);

  for (final entry in sections.entries) {
    if (specifiedSection != null && entry.key != specifiedSection) {
      continue;
    }

    final units = <DataCase>[];

    for (final e in entry.value) {
      final result = compareResult(
        config,
        e,
        verboseFail: verbose,
        verboseLooseMatch: verboseLooseMatch,
        extensions: e.extensions,
      );

      units.add(DataCase(
        front_matter: result.testCase.toString(),
        input: result.testCase.markdown,
        expectedOutput:
            (_improveStrict && result.compareLevel == CompareLevel.loose)
                ? result.testCase.html
                : result.result!,
      ));

      final nestedMap = scores.putIfAbsent(
        entry.key,
        SplayTreeMap<int, CompareLevel>.new,
      );
      nestedMap[e.example] = result.compareLevel;
    }

    if (updateFiles && units.isNotEmpty) {
      var fileName =
          entry.key.toLowerCase().replaceAll(_sectionNameReplace, '_');
      while (fileName.endsWith('_')) {
        fileName = fileName.substring(0, fileName.length - 1);
      }
      fileName = '$fileName.unit';
      File(p.join('test', testPrefix, fileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(_unitOutput(units));
    }
  }

  if (raw || updateFiles) {
    await _printRaw(testPrefix, scores, updateFiles);
  }

  if (!raw || updateFiles) {
    await _printFriendly(testPrefix, scores, updateFiles);
  }
}

Object? _convert(Object? obj) {
  if (obj is CompareLevel) {
    switch (obj) {
      case CompareLevel.strict:
        return 'strict';
      case CompareLevel.error:
        return 'error';
      case CompareLevel.fail:
        return 'fail';
      case CompareLevel.loose:
        return 'loose';
      default:
        throw ArgumentError('`$obj` is unknown.');
    }
  }
  if (obj is Map) {
    final map = <String, Object?>{};
    obj.forEach((k, v) {
      final newKey = k.toString();
      map[newKey] = v;
    });
    return map;
  }
  return obj;
}

Future<void> _printRaw(
  String testPrefix,
  Map<String, Map<int, CompareLevel>> scores,
  bool updateFiles,
) async {
  IOSink sink;
  if (updateFiles) {
    final file = getStatsFile(testPrefix);
    print('Updating ${file.path}');
    sink = file.openWrite();
  } else {
    sink = stdout;
  }

  const encoder = JsonEncoder.withIndent(' ', _convert);
  try {
    sink.writeln(encoder.convert(scores));
    // ignore: avoid_catching_errors
  } on JsonUnsupportedObjectError catch (e) {
    stderr.writeln(e.cause);
    stderr.writeln(e.unsupportedObject.runtimeType);
    rethrow;
  }

  await sink.flush();
  await sink.close();
}

String _pct(int value, int total, String section) =>
    '${value.toString().padLeft(4)} '
    'of ${total.toString().padLeft(4)} '
    '– ${(100 * value / total).toStringAsFixed(1).padLeft(5)}%  $section';

Future<void> _printFriendly(
  String testPrefix,
  SplayTreeMap<String, SplayTreeMap<int, CompareLevel>> scores,
  bool updateFiles,
) async {
  var totalValid = 0;
  var totalStrict = 0;
  var totalExamples = 0;

  IOSink sink;
  if (updateFiles) {
    final path = p.join(toolDir, '${testPrefix}_stats.txt');
    print('Updating $path');
    final file = File(path);
    sink = file.openWrite();
  } else {
    sink = stdout;
  }

  scores.forEach((section, Map<int, CompareLevel> map) {
    final total = map.values.length;
    totalExamples += total;

    final sectionStrictCount =
        map.values.where((val) => val == CompareLevel.strict).length;

    final sectionLooseCount =
        map.values.where((val) => val == CompareLevel.loose).length;

    final sectionValidCount = sectionStrictCount + sectionLooseCount;

    totalStrict += sectionStrictCount;
    totalValid += sectionValidCount;

    sink.writeln(_pct(sectionValidCount, total, section));
  });

  sink.writeln(_pct(totalValid, totalExamples, 'TOTAL'));
  sink.writeln(_pct(totalStrict, totalValid, 'TOTAL Strict'));

  await sink.flush();
  await sink.close();
}
