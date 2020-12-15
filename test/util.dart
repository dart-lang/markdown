// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

import 'dart:isolate';

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/expected_output.dart';

/// Run tests defined in "*.unit" files inside directory [name].
Future<void> testDirectory(String name, {ExtensionSet extensionSet}) async {
  await for (var dataCase in dataCasesUnder(testDirectory: name)) {
    var description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      extensionSet: extensionSet,
    );
  }
}

Future<String> get markdownPackageRoot async =>
    p.dirname(p.dirname((await Isolate.resolvePackageUri(
            Uri.parse('package:markdown/markdown.dart')))
        .path));

void testFile(String file,
    {Iterable<BlockSyntax> blockSyntaxes,
    Iterable<InlineSyntax> inlineSyntaxes}) async {
  var directory = p.join(await markdownPackageRoot, 'test');
  for (var dataCase in dataCasesInFile(path: p.join(directory, file))) {
    var description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(description, dataCase.input, dataCase.expectedOutput,
        blockSyntaxes: blockSyntaxes, inlineSyntaxes: inlineSyntaxes);
  }
}

void validateCore(
  String description,
  String markdown,
  String html, {
  Iterable<BlockSyntax> blockSyntaxes,
  Iterable<InlineSyntax> inlineSyntaxes,
  Resolver linkResolver,
  Resolver imageLinkResolver,
  ExtensionSet extensionSet,
  bool inlineOnly = false,
}) {
  test(description, () {
    var result = markdownToHtml(markdown,
        blockSyntaxes: blockSyntaxes,
        inlineSyntaxes: inlineSyntaxes,
        extensionSet: extensionSet,
        linkResolver: linkResolver,
        imageLinkResolver: imageLinkResolver,
        inlineOnly: inlineOnly);

    markdownPrintOnFailure(markdown, html, result);

    expect(result, html);
  });
}

String whitespaceColor(String input) => input
    .replaceAll(' ', ansi.lightBlue.wrap('·'))
    .replaceAll('\t', ansi.backgroundDarkGray.wrap('\t'));

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
