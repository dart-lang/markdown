// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/expected_output.dart';

/// Runs tests defined in "*.unit" files inside directory [name].
// TODO(Zhiguang): Delete it when `Document` is removed.
void testDirectoryDeprecated(String name, {ExtensionSet? extensionSet}) {
  for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';

    final inlineSyntaxes = <InlineSyntax>[];
    final blockSyntaxes = <BlockSyntax>[];

    if (dataCase.file.endsWith('_extension')) {
      final extension = dataCase.file.substring(
        0,
        dataCase.file.lastIndexOf('_extension'),
      );
      switch (extension) {
        case 'autolinks':
          inlineSyntaxes.add(AutolinkExtensionSyntax());
          break;
        case 'strikethrough':
          inlineSyntaxes.add(StrikethroughSyntax());
          break;
        case 'tables':
          blockSyntaxes.add(const TableSyntax());
          break;
        case 'disallowed_raw_html':
          // TODO(Zhiguang): https://github.com/dart-lang/markdown/pull/447
          break;
        default:
          throw UnimplementedError('Unimplemented extension "$extension"');
      }
    }

    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      extensionSet: extensionSet,
      inlineSyntaxes: inlineSyntaxes,
      blockSyntaxes: blockSyntaxes,
    );
  }
}

void testFile(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) {
  for (final dataCase
      in dataCasesInFile(path: p.join(p.current, 'test', file))) {
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
  //
  bool isNewVersion = false,
  bool enableTable = false,
  bool enableStrikethrough = false,
  bool enableAutolinkExtension = false,
  bool enableHeadingId = false,
  bool enableTaskList = false,
}) {
  test(description, () {
    final String result;
    if (isNewVersion) {
      result = Markdown(
        enableTable: enableTable,
        enableStrikethrough: enableStrikethrough,
        enableAutolinkExtension: enableAutolinkExtension,
      ).parse(markdown).toHtml();
    } else {
      result = markdownToHtml(
        markdown,
        blockSyntaxes: blockSyntaxes,
        inlineSyntaxes: inlineSyntaxes,
        extensionSet: extensionSet,
        linkResolver: linkResolver,
        imageLinkResolver: imageLinkResolver,
        inlineOnly: inlineOnly,
      );
    }

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

void testDirectory(String name) {
  for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';

    var enableTable = false;
    var enableStrikethrough = false;
    var enableAutolinkExtension = false;

    if (dataCase.file.endsWith('_extension')) {
      final extension = dataCase.file.substring(
        0,
        dataCase.file.lastIndexOf('_extension'),
      );

      if (extension == 'tables') {
        enableTable = true;
      } else if (extension == 'strikethrough') {
        enableStrikethrough = true;
      } else if (extension == 'autolinks') {
        enableAutolinkExtension = true;
      } else if (extension == 'disallowed_raw_html') {
        // TODO(Zhiguang): For https://github.com/dart-lang/markdown/pull/447
      }
    }

    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      enableTable: enableTable,
      enableStrikethrough: enableStrikethrough,
      enableAutolinkExtension: enableAutolinkExtension,
      isNewVersion: true,
    );
  }
}
