// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/expected_output.dart';

final extensionMap = <String, dynamic>{
  'tables': TableSyntax(),
  'strikethrough': StrikethroughSyntax(),
  'autolinks': AutolinkExtensionSyntax(),
};

/// Removes the last line feed of each test case from "*.unit" files.
String _removeLineFeed(String text) =>
    text.endsWith('\n') ? text.substring(0, text.length - 1) : text;

/// Runs tests defined in "*.unit" files inside directory [name].
Future<void> testDirectory(String name) async {
  await for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    final blockSyntaxes = <BlockSyntax>[];
    final inlineSyntaxes = <InlineSyntax>[];

    if (dataCase.file.endsWith('_extension')) {
      final syntaxName = dataCase.file.substring(
        0,
        dataCase.file.lastIndexOf('_extension'),
      );

      final syntax = extensionMap[syntaxName];
      if (syntax is InlineSyntax) {
        inlineSyntaxes.add(syntax);
      } else if (syntax is BlockSyntax) {
        blockSyntaxes.add(syntax);
      }
    }
    validateCore(
      description,
      dataCase.input,
      _removeLineFeed(dataCase.expectedOutput),
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
    );
  }
}

Future<String> get markdownPackageRoot async {
  final packageUri = Uri.parse('package:markdown/markdown.dart');
  final isolateUri = await Isolate.resolvePackageUri(packageUri);
  return p.dirname(p.dirname(isolateUri!.toFilePath()));
}

void testFile(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) async {
  final directory = p.join(await markdownPackageRoot, 'test');
  for (final dataCase in dataCasesInFile(path: p.join(directory, file))) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      _removeLineFeed(dataCase.expectedOutput),
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
    );
  }
}

void validateCore(
  String description,
  String markdown,
  String html, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
}) {
  test(description, () {
    final result = markdownToHtml(
      markdown,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      linkResolver: linkResolver,
      imageLinkResolver: imageLinkResolver,
      inlineOnly: inlineOnly,
    );

    markdownPrintOnFailure(markdown, html, result);

    expect(result, html);
  });
}

String whitespaceColor(String input) => input
    .replaceAll(' ', ansi.lightBlue.wrap('·')!)
    .replaceAll('\t', ansi.backgroundDarkGray.wrap('\t')!);

void markdownPrintOnFailure(String markdown, String expected, String actual) {
  printOnFailure("""
INPUT:
'''r
${whitespaceColor(markdown)}'''            
           
EXPECTED:
'''r
${whitespaceColor(expected)}'''

GOT:
'''r
${whitespaceColor(actual)}'''
""");
}

void testAstFromFile(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) async {
  final directory = p.join(await markdownPackageRoot, 'test');
  final path = p.join(directory, file);
  final cases = json.decode(File(path).readAsStringSync());

  for (final testCase in cases) {
    test(testCase['description'], () {
      final document = Document();
      final nodes = document.parseLines(testCase['input'] as String);
      expect(nodes.map((e) => e.toMap()), testCase['output']);
    });
  }
}
