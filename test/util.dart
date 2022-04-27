// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:markdown/src/reverse_renderer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/expected_output.dart';

/// Runs tests defined in "*.unit" files inside directory [name].
Future<void> testDirectory(
  String name, {
  ExtensionSet? extensionSet,
  bool inputAsOutput = false,
}) async {
  await for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      extensionSet: extensionSet,
      inputAsOutput: inputAsOutput,
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
  bool inputAsOutput = false,
}) async {
  final directory = p.join(await markdownPackageRoot, 'test');
  for (final dataCase in dataCasesInFile(path: p.join(directory, file))) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
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
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
  bool inputAsOutput = false,
}) {
  test(description, () {
    String result;
    String expected;
    if (!inputAsOutput) {
      expected = html;
      result = markdownToHtml(markdown,
          blockSyntaxes: blockSyntaxes,
          inlineSyntaxes: inlineSyntaxes,
          extensionSet: extensionSet,
          linkResolver: linkResolver,
          imageLinkResolver: imageLinkResolver,
          inlineOnly: inlineOnly);
    } else {
      expected = markdown;
      result = markdownToMarkdown(markdown,
          blockSyntaxes: blockSyntaxes,
          inlineSyntaxes: inlineSyntaxes,
          extensionSet: extensionSet,
          linkResolver: linkResolver,
          imageLinkResolver: imageLinkResolver,
          // TODO(Zhiguang) Enable default syntaxes when all syntaxes are ready
          withDefaultBlockSyntaxes: false,
          withDefaultInlineSyntaxes: false,
          inlineOnly: inlineOnly);
    }

    markdownPrintOnFailure(markdown, html, result);
    markdownPrintOnFailure(markdown, expected, result);

    expect(result, html);
    expect(result, expected);
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
