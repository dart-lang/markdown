import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:expected_output/expected_output.dart';
import 'package:path/path.dart' as p;

import 'stats_lib.dart';

final _configs =
    List<Config>.unmodifiable([Config.commonMarkConfig, Config.gfmConfig]);

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('section',
        help: 'Restrict tests to one section, provided after the option.')
    ..addFlag('raw',
        defaultsTo: false, help: 'raw JSON format', negatable: false)
    ..addFlag('update-files',
        defaultsTo: false,
        help: 'Update stats files in $toolDir',
        negatable: false)
    ..addFlag('verbose',
        defaultsTo: false,
        help: 'Print details for failures and errors.',
        negatable: false)
    ..addFlag('verbose-loose',
        defaultsTo: false,
        help: 'Print details for "loose" matches.',
        negatable: false)
    ..addOption('flavor', allowed: _configs.map((c) => c.prefix))
    ..addFlag('help', defaultsTo: false, negatable: false);

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

  var specifiedSection = options['section'] as String;
  var raw = options['raw'] as bool;
  var verbose = options['verbose'] as bool;
  var verboseLooseMatch = options['verbose-loose'] as bool;
  var updateFiles = options['update-files'] as bool;

  if (updateFiles && (raw || verbose || (specifiedSection != null))) {
    stderr.writeln('The `update-files` flag must be used by itself');
    print(parser.usage);
    exitCode = 64; // unix standard improper usage
    return;
  }

  var testPrefix = options['flavor'] as String;
  if (!updateFiles) {
    testPrefix = _configs.first.prefix;
  }

  final testPrefixes =
      testPrefix == null ? _configs.map((c) => c.prefix) : <String>[testPrefix];

  for (var testPrefix in testPrefixes) {
    await _processConfig(testPrefix, raw, updateFiles, verbose,
        specifiedSection, verboseLooseMatch);
  }
}

final _sectionNameReplace = RegExp('[ \\)\\(]+');

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
  String specifiedSection,
  bool verboseLooseMatch,
) async {
  final config = _configs.singleWhere((c) => c.prefix == testPrefix);

  var sections = loadCommonMarkSections(testPrefix);

  var scores = SplayTreeMap<String, SplayTreeMap<int, CompareLevel>>(
      compareAsciiLowerCaseNatural);

  for (var entry in sections.entries) {
    if (specifiedSection != null && entry.key != specifiedSection) {
      continue;
    }

    final units = <DataCase>[];

    for (var e in entry.value) {
      final result = compareResult(config, e,
          verboseFail: verbose, verboseLooseMatch: verboseLooseMatch);

      units.add(DataCase(
        front_matter: result.testCase.toString(),
        input: result.testCase.markdown,
        expectedOutput:
            (_improveStrict && result.compareLevel == CompareLevel.loose)
                ? result.testCase.html
                : result.result,
      ));

      var nestedMap = scores.putIfAbsent(
          entry.key, () => SplayTreeMap<int, CompareLevel>());
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

Object _convert(Object obj) {
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
    var map = <String, Object>{};
    obj.forEach((k, v) {
      var newKey = k.toString();
      map[newKey] = v;
    });
    return map;
  }
  return obj;
}

Future<void> _printRaw(String testPrefix,
    Map<String, Map<int, CompareLevel>> scores, bool updateFiles) async {
  IOSink sink;
  if (updateFiles) {
    var file = getStatsFile(testPrefix);
    print('Updating ${file.path}');
    sink = file.openWrite();
  } else {
    sink = stdout;
  }

  var encoder = const JsonEncoder.withIndent(' ', _convert);
  try {
    sink.writeln(encoder.convert(scores));
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
    bool updateFiles) async {
  var totalValid = 0;
  var totalStrict = 0;
  var totalExamples = 0;

  IOSink sink;
  if (updateFiles) {
    var path = p.join(toolDir, '${testPrefix}_stats.txt');
    print('Updating $path');
    var file = File(path);
    sink = file.openWrite();
  } else {
    sink = stdout;
  }

  scores.forEach((section, Map<int, CompareLevel> map) {
    var total = map.values.length;
    totalExamples += total;

    var sectionStrictCount =
        map.values.where((val) => val == CompareLevel.strict).length;

    var sectionLooseCount =
        map.values.where((val) => val == CompareLevel.loose).length;

    var sectionValidCount = sectionStrictCount + sectionLooseCount;

    totalStrict += sectionStrictCount;
    totalValid += sectionValidCount;

    sink.writeln(_pct(sectionValidCount, total, section));
  });

  sink.writeln(_pct(totalValid, totalExamples, 'TOTAL'));
  sink.writeln(_pct(totalStrict, totalValid, 'TOTAL Strict'));

  await sink.flush();
  await sink.close();
}
