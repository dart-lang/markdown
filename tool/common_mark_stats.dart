library markdown.tool.common_mark_stats;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:args/args.dart' show ArgParser;
import 'package:collection/collection.dart';
import 'package:html/parser.dart' show parseFragment;
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
  final parser = new ArgParser()
    ..addOption('section', help: 'Restrict tests to one section')
    ..addFlag('raw', defaultsTo: false, help: 'raw JSON format')
    ..addFlag('verbose', defaultsTo: false, help: 'verbose output');
  var options = parser.parse(args);

  var specifiedSection = options['section'];
  var raw = options['raw'];
  var verbose = options['verbose'];

  var sections = loadCommonMarkSections();

  var scores = new SplayTreeMap<String, SplayTreeMap<int, bool>>(
      compareAsciiLowerCaseNatural);

  String indent(String s) => s.splitMapJoin('\n', onNonMatch: (n) => '    $n');

  sections.forEach((section, examples) {
    if (specifiedSection != null && section != specifiedSection) {
      return;
    }
    for (var e in examples) {
      var output;
      var nestedMap =
          scores.putIfAbsent(section, () => new SplayTreeMap<int, bool>());

      try {
        output = markdownToHtml(e.markdown);
      } catch (exc) {
        nestedMap[e.example] = false;
        continue;
      }

      var expected = parseFragment(e.html);
      var actual = parseFragment(output);
      nestedMap[e.example] = compareHtml(expected.children, actual.children);
      if (verbose && !nestedMap[e.example]) {
        print('FAIL: http://spec.commonmark.org/0.24/#example-${e.example}');
        print('input:');
        print(indent(e.markdown));
        print('expected:');
        print(indent(expected.outerHtml));
        print('actual:');
        print(indent(actual.outerHtml));
        print('-----------------------');
      }
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

/// Compare two DOM trees for equality.
bool compareHtml(List<Element> expectedElements, List<Element> actualElements) {
  if (expectedElements.length != actualElements.length) {
    return false;
  }

  for (var childNum = 0; childNum < expectedElements.length; childNum++) {
    var expected = expectedElements[childNum];
    var actual = actualElements[childNum];

    if (expected.runtimeType != actual.runtimeType) {
      return false;
    }

    if (expected is Element) {
      if (expected.localName != actual.localName) {
        return false;
      }

      if (expected.attributes.length != actual.attributes.length) {
        return false;
      }

      var expectedAttrKeys = expected.attributes.keys.toList();
      expectedAttrKeys.sort();

      var actualAttrKeys = actual.attributes.keys.toList();
      actualAttrKeys.sort();

      for (var attrNum = 0; attrNum < actualAttrKeys.length; attrNum++) {
        var expectedAttrKey = expectedAttrKeys[attrNum];
        var actualAttrKey = actualAttrKeys[attrNum];

        if (expectedAttrKey != actualAttrKey) {
          return false;
        }

        if (expected.attributes[expectedAttrKey] !=
            actual.attributes.keys[actualAttrKey]) {
          return false;
        }
      }
    }

    var childrenEqual = compareHtml(expected.children, actual.children);

    if (!childrenEqual) {
      return false;
    }
  }

  return true;
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
