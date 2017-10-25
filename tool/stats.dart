import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'stats_lib.dart';

Future main(List<String> args) async {
  final parser = new ArgParser()
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
    ..addOption('flavor',
        allowed: [Config.commonMarkConfig.prefix, Config.gfmConfig.prefix],
        defaultsTo: Config.commonMarkConfig.prefix)
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

  final testPrefix = options['flavor'] as String;

  Config config;
  switch (testPrefix) {
    case 'gfm':
      config = Config.gfmConfig;
      break;
    case 'common_mark':
      config = Config.commonMarkConfig;
      break;
    default:
      throw new ArgumentError('Does not support `$testPrefix`.');
  }

  var sections = loadCommonMarkSections(testPrefix);

  var scores = new SplayTreeMap<String, SplayTreeMap<int, CompareLevel>>(
      compareAsciiLowerCaseNatural);

  sections.forEach((section, examples) {
    if (specifiedSection != null && section != specifiedSection) {
      return;
    }
    for (var e in examples) {
      var nestedMap = scores.putIfAbsent(
          section, () => new SplayTreeMap<int, CompareLevel>());

      nestedMap[e.example] = compareResult(config, e,
          verboseFail: verbose, verboseLooseMatch: verboseLooseMatch);
    }
  });

  if (raw || updateFiles) {
    await _printRaw(testPrefix, scores, updateFiles);
  }

  if (!raw || updateFiles) {
    await _printFriendly(testPrefix, scores, updateFiles);
  }
}

Object _convert(obj) {
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
        throw new ArgumentError("`$obj` is unknown.");
    }
  }
  if (obj is Map) {
    var map = {};
    obj.forEach((k, v) {
      var newKey = k.toString();
      map[newKey] = v;
    });
    return map;
  }
  return obj;
}

Future _printRaw(String testPrefix, Map scores, bool updateFiles) async {
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

Future _printFriendly(
    String testPrefix,
    SplayTreeMap<String, SplayTreeMap<int, CompareLevel>> scores,
    bool updateFiles) async {
  const countWidth = 4;

  var totalValid = 0;
  var totalExamples = 0;

  IOSink sink;
  if (updateFiles) {
    var path = p.join(toolDir, '${testPrefix}_stats.txt');
    print('Updating $path');
    var file = new File(path);
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

    totalValid += sectionValidCount;

    var pct = (100 * sectionValidCount / total).toStringAsFixed(1).padLeft(5);

    sink.writeln('${sectionValidCount.toString().padLeft(countWidth)} '
        'of ${total.toString().padLeft(countWidth)} '
        '– $pct%  $section');
  });

  var pct = (100 * totalValid / totalExamples).toStringAsFixed(1).padLeft(5);

  sink.writeln('${totalValid.toString().padLeft(countWidth)} '
      'of ${totalExamples.toString().padLeft(countWidth)} '
      '– $pct%  TOTAL');

  await sink.flush();
  await sink.close();
}
