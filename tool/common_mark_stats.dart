library markdown.tool.common_mark_stats;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:mirrors';

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

void main() {
  var sections = loadCommonMarkSections();

  var scores = <String, int>{};

  int maxSectionLength = 0;
  int totalExamples = 0;
  int totalValid = 0;

  sections.forEach((section, examples) {
    int validCount = 0;
    for (var e in examples) {
      var output;

      try {
        output = markdownToHtml(e.markdown);
      } catch (exc) {
        continue;
      }

      var expected = parseFragment(e.html);
      var actual = parseFragment(output);

      if (compareHtml(expected.children, actual.children)) {
        validCount++;
      }
    }

    maxSectionLength = math.max(maxSectionLength, section.length);

    scores[section] = validCount;

    totalValid += validCount;
    totalExamples += examples.length;
  });

  scores.forEach((section, count) {
    var total = sections[section].length;
    var pct = (100 * count / total).toStringAsFixed(1).padLeft(5);

    print('${section.padLeft(maxSectionLength)} '
        '${count.toString().padLeft(3)} '
        'of ${total.toString().padLeft(3)} '
        '– ${pct}%');
  });

  var pct = (100 * totalValid / totalExamples).toStringAsFixed(1).padLeft(5);

  print('${"TOTAL".padLeft(maxSectionLength)} '
      '${totalValid.toString().padLeft(3)} '
      'of ${totalExamples.toString().padLeft(3)} '
      '– ${pct}%');
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

  var testArray = JSON.decode(testsJson) as List<Map>;

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
