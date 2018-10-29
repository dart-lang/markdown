import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:path/path.dart' as p;

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:markdown/markdown.dart' show markdownToHtml, ExtensionSet;

// Locate the "tool" directory. Use mirrors so that this works with the test
// package, which loads this suite into an isolate.
String get toolDir =>
    p.dirname((reflect(loadCommonMarkSections) as ClosureMirror)
        .function
        .location
        .sourceUri
        .path);

File getStatsFile(String prefix) =>
    new File(p.join(toolDir, '${prefix}_stats.json'));

Map<String, List<CommonMarkTestCase>> loadCommonMarkSections(
    String testPrefix) {
  var testFile = new File(p.join(toolDir, '${testPrefix}_tests.json'));
  var testsJson = testFile.readAsStringSync();

  var testArray = jsonDecode(testsJson) as List;

  var sections = new Map<String, List<CommonMarkTestCase>>();

  for (var exampleMap in testArray) {
    var exampleTest =
        new CommonMarkTestCase.fromJson(exampleMap as Map<String, dynamic>);

    var sectionList =
        sections.putIfAbsent(exampleTest.section, () => <CommonMarkTestCase>[]);

    sectionList.add(exampleTest);
  }

  return sections;
}

class Config {
  static final Config commonMarkConfig =
      new Config._('common_mark', 'http://spec.commonmark.org/0.28/', null);
  static final Config gfmConfig = new Config._(
      'gfm', 'https://github.github.com/gfm/', ExtensionSet.gitHubFlavored);

  final String prefix;
  final String baseUrl;
  final ExtensionSet extensionSet;

  Config._(this.prefix, this.baseUrl, this.extensionSet);
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
    return new CommonMarkTestCase(
        json['example'] as int,
        json['section'] as String,
        json['start_line'] as int,
        json['end_line'] as int,
        json['markdown'] as String,
        json['html'] as String);
  }
}

enum CompareLevel { strict, loose, fail, error }

CompareLevel compareResult(Config config, CommonMarkTestCase expected,
    {bool throwOnError = false,
    bool verboseFail = false,
    bool verboseLooseMatch = false}) {
  String output;
  try {
    output =
        markdownToHtml(expected.markdown, extensionSet: config.extensionSet);
  } catch (err, stackTrace) {
    if (throwOnError) {
      rethrow;
    }
    if (verboseFail) {
      _printVerboseFailure(config.baseUrl, 'ERROR', expected, expected.html,
          'Thrown: $err\n$stackTrace');
    }

    return CompareLevel.error;
  }

  if (expected.html == output) {
    return CompareLevel.strict;
  }

  var expectedParsed = parseFragment(expected.html);
  var actual = parseFragment(output);

  var looseMatch = _compareHtml(expectedParsed.children, actual.children);

  if (!looseMatch && verboseFail) {
    _printVerboseFailure(config.baseUrl, 'FAIL', expected,
        expectedParsed.outerHtml, actual.outerHtml);
  }

  if (looseMatch && verboseLooseMatch) {
    _printVerboseFailure(
        config.baseUrl, 'LOOSE', expected, output, actual.outerHtml);
  }

  return looseMatch ? CompareLevel.loose : CompareLevel.fail;
}

String _indent(String s) => s.splitMapJoin('\n', onNonMatch: (n) => '    $n');

void _printVerboseFailure(String baseUrl, String message,
    CommonMarkTestCase test, String expected, String actual) {
  print('$message: $baseUrl#example-${test.example} '
      '@ ${test.section}');
  print('input:');
  print(_indent(test.markdown));
  print('expected:');
  print(_indent(expected));
  print('actual:');
  print(_indent(actual));
  print('-----------------------');
}

/// Compare two DOM trees for equality.
bool _compareHtml(
    List<Element> expectedElements, List<Element> actualElements) {
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

    var childrenEqual = _compareHtml(expected.children, actual.children);

    if (!childrenEqual) {
      return false;
    }
  }

  return true;
}
