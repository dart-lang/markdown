library markdown.tool.common_mark_stats;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;

const _commonMarkTests = 'common_mark_tests.json';

// Locate the "test" directory. Use mirrors so that this works with the test
// package, which loads this suite into an isolate.
String get _currentDir => p.dirname(currentMirrorSystem()
    .findLibrary(#markdown.tool.common_mark_stats)
    .uri
    .path);

void main(List<String> args) {
  var raw = args.any((s) => s == '--raw');

  var sections = loadCommonMarkSections();

  var scores = new SplayTreeMap<String, SplayTreeMap<int, bool>>(
      compareAsciiLowerCaseNatural);

  sections.forEach((section, examples) {
    for (var e in examples) {
      var output = markdownToHtml(e.markdown);

      var nestedMap =
          scores.putIfAbsent(section, () => new SplayTreeMap<int, bool>());

      nestedMap[e.example] = (output == e.html);
    }
  });

  if (raw) {
    var encoder = const JsonEncoder.withIndent(' ', _convert);
    try {
      print(encoder.convert(scores));
    } on JsonUnsupportedObjectError catch (e) {
      print(e.cause);
      print(e.unsupportedObject.runtimeType);
      rethrow;
    }
  } else {
    _printFriendly(scores);
  }
}

_convert(obj) {
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

void _printFriendly(SplayTreeMap<String, SplayTreeMap<int, bool>> scores) {
  const countWidth = 4;

  var totalValid = 0;
  var totalExamples = 0;

  scores.forEach((section, map) {
    var total = map.values.length;
    totalExamples += total;

    var sectionValidCount = map.values.where((val) => val).length;

    totalValid += sectionValidCount;

    var pct = (100 * sectionValidCount / total).toStringAsFixed(1).padLeft(5);

    print('${sectionValidCount.toString().padLeft(countWidth)} '
        'of ${total.toString().padLeft(countWidth)} '
        '– ${pct}%  $section');
  });

  var pct = (100 * totalValid / totalExamples).toStringAsFixed(1).padLeft(5);

  print('${totalValid.toString().padLeft(countWidth)} '
      'of ${totalExamples.toString().padLeft(countWidth)} '
      '– ${pct}%  TOTAL');
}

Map<String, List<CommonMarkTestCase>> loadCommonMarkSections() {
  var testFile = new File(p.join(_currentDir, _commonMarkTests));
  var testsJson = testFile.readAsStringSync();

  var testArray = JSON.decode(testsJson) as List<Map<String, dynamic>>;

  var sections = new Map<String, List<CommonMarkTestCase>>();

  for (var exampleMap in testArray) {
    var exampleTest = new CommonMarkTestCase.fromJson(exampleMap);

    var sectionList =
        sections.putIfAbsent(exampleTest.section, () => <CommonMarkTestCase>[]);

    sectionList.add(exampleTest);
  }

  return sections;
}

class CommonMarkTestCase {
  final String markdown;
  final String section;
  final int example;
  final String html;
  final int startLine;
  final int endLine;

  CommonMarkTestCase(this.example, this.section, this.startLine, this.endLine,
      this.markdown, this.html);

  factory CommonMarkTestCase.fromJson(Map<String, dynamic> json) {
    return new CommonMarkTestCase(json['example'], json['section'],
        json['start_line'], json['end_line'], json['markdown'], json['html']);
  }
}
