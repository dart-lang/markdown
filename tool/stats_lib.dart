// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parseFragment;
import 'package:markdown/markdown.dart' show markdownToHtml, ExtensionSet;
import 'package:path/path.dart' as p;

import '../test/util.dart';

// Locate the "tool" directory. Use mirrors so that this works with the test
// package, which loads this suite into an isolate.
String get toolDir =>
    p.dirname((reflect(loadCommonMarkSections) as ClosureMirror)
        .function
        .location
        .sourceUri
        .path);

File getStatsFile(String prefix) =>
    File(p.join(toolDir, '${prefix}_stats.json'));

Map<String, List<CommonMarkTestCase>> loadCommonMarkSections(
    String testPrefix) {
  var testFile = File(p.join(toolDir, '${testPrefix}_tests.json'));
  var testsJson = testFile.readAsStringSync();

  var testArray = jsonDecode(testsJson) as List;

  var sections = <String, List<CommonMarkTestCase>>{};

  for (var exampleMap in testArray) {
    var exampleTest =
        CommonMarkTestCase.fromJson(exampleMap as Map<String, dynamic>);

    var sectionList =
        sections.putIfAbsent(exampleTest.section, () => <CommonMarkTestCase>[]);

    sectionList.add(exampleTest);
  }

  return sections;
}

class Config {
  static final Config commonMarkConfig =
      Config._('common_mark', 'http://spec.commonmark.org/0.28/', null);
  static final Config gfmConfig = Config._(
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
    return CommonMarkTestCase(
        json['example'] as int,
        json['section'] as String,
        json['start_line'] as int,
        json['end_line'] as int,
        json['markdown'] as String,
        json['html'] as String);
  }

  @override
  String toString() => '$section - $example';
}

enum CompareLevel { strict, loose, fail, error }

class CompareResult {
  final CompareLevel compareLevel;
  final CommonMarkTestCase testCase;
  final String result;

  CompareResult(this.testCase, this.result, this.compareLevel);
}

CompareResult compareResult(Config config, CommonMarkTestCase testCase,
    {bool throwOnError = false,
    bool verboseFail = false,
    bool verboseLooseMatch = false}) {
  String output;
  try {
    output =
        markdownToHtml(testCase.markdown, extensionSet: config.extensionSet);
  } catch (err, stackTrace) {
    if (throwOnError) {
      rethrow;
    }
    if (verboseFail) {
      _printVerboseFailure(
          config.baseUrl, 'ERROR', testCase, 'Thrown: $err\n$stackTrace');
    }

    return CompareResult(testCase, null, CompareLevel.error);
  }

  if (testCase.html == output) {
    return CompareResult(testCase, output, CompareLevel.strict);
  }

  var expectedParsed = parseFragment(testCase.html);
  var actual = parseFragment(output);

  var looseMatch = _compareHtml(expectedParsed.children, actual.children);

  if (!looseMatch && verboseFail) {
    _printVerboseFailure(config.baseUrl, 'FAIL', testCase, output);
  }

  if (looseMatch && verboseLooseMatch) {
    _printVerboseFailure(config.baseUrl, 'LOOSE', testCase, output);
  }

  return CompareResult(
      testCase, output, looseMatch ? CompareLevel.loose : CompareLevel.fail);
}

String _indent(String s) =>
    s.splitMapJoin('\n', onNonMatch: (n) => '    ${whitespaceColor(n)}');

void _printVerboseFailure(String baseUrl, String message,
    CommonMarkTestCase testCase, String actual) {
  print('$message: $baseUrl#example-${testCase.example} '
      '@ ${testCase.section}');
  print('input:');
  print(_indent(testCase.markdown));
  print('expected:');
  print(_indent(testCase.html));
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
