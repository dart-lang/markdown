import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:path/path.dart' as p;

const _commonMarkTests = 'common_mark_tests.json';

// Locate the "test" directory. Use mirrors so that this works with the test
// package, which loads this suite into an isolate.
String get _currentDir => p
    .dirname((reflect(main) as ClosureMirror).function.location.sourceUri.path);

main(List<String> args) async {
  final parser = new ArgParser()
    ..addOption('section',
        help: 'Restrict tests to one section, provided after the option.')
    ..addFlag('raw',
        defaultsTo: false, help: 'raw JSON format', negatable: false)
    ..addFlag('update-files',
        defaultsTo: false,
        help: 'Update stats files in $_currentDir',
        negatable: false)
    ..addFlag('verbose',
        defaultsTo: false, help: 'verbose output', negatable: false)
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

  if (options['help']) {
    print(parser.usage);
    return;
  }

  var specifiedSection = options['section'] as String;
  var raw = options['raw'] as bool;
  var verbose = options['verbose'] as bool;
  var updateFiles = options['update-files'] as bool;

  if (updateFiles && (raw || verbose || (specifiedSection != null))) {
    stderr.writeln('The `update-files` flag must be used by itself');
    print(parser.usage);
    exitCode = 64; // unix standard improper usage
    return;
  }

  var sections = _loadCommonMarkSections();

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
        print('FAIL: http://spec.commonmark.org/0.25/#example-${e.example}');
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

  if (raw || updateFiles) {
    await _printRaw(scores, updateFiles);
  }

  if (!raw || updateFiles) {
    await _printFriendly(scores, updateFiles);
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

Future _printRaw(scores, bool updateFiles) async {
  IOSink sink;
  if (updateFiles) {
    var path = p.join(_currentDir, 'common_mark_stats.json');
    print('Updating $path');
    var file = new File(path);
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

Future _printFriendly(SplayTreeMap<String, SplayTreeMap<int, bool>> scores,
    bool updateFiles) async {
  const countWidth = 4;

  var totalValid = 0;
  var totalExamples = 0;

  IOSink sink;
  if (updateFiles) {
    var path = p.join(_currentDir, 'common_mark_stats.txt');
    print('Updating $path');
    var file = new File(path);
    sink = file.openWrite();
  } else {
    sink = stdout;
  }

  scores.forEach((section, map) {
    var total = map.values.length;
    totalExamples += total;

    var sectionValidCount = map.values.where((val) => val).length;

    totalValid += sectionValidCount;

    var pct = (100 * sectionValidCount / total).toStringAsFixed(1).padLeft(5);

    sink.writeln('${sectionValidCount.toString().padLeft(countWidth)} '
        'of ${total.toString().padLeft(countWidth)} '
        '– ${pct}%  $section');
  });

  var pct = (100 * totalValid / totalExamples).toStringAsFixed(1).padLeft(5);

  sink.writeln('${totalValid.toString().padLeft(countWidth)} '
      'of ${totalExamples.toString().padLeft(countWidth)} '
      '– ${pct}%  TOTAL');

  await sink.flush();
  await sink.close();
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
          actual.attributes[actualAttrKey]) {
        return false;
      }
    }

    var childrenEqual = compareHtml(expected.children, actual.children);

    if (!childrenEqual) {
      return false;
    }
  }

  return true;
}

Map<String, List<CommonMarkTestCase>> _loadCommonMarkSections() {
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
