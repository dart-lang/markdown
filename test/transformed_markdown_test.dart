// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/expected_output.dart';

import 'util.dart';

class OurSecondTestTransfomer extends CodeBlockTransformer {
  static const ourBlockTypeList = ['secondary'];

  String fakeTransformer(String codeBlockType, String rawCodeBlock) {
    switch (codeBlockType) {
      case 'secondary':
        return 'secondary\n${rawCodeBlock.toUpperCase()}';
    }
    return 'unsupported type';
  }

  @override
  Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, BlockParser parser) {
    return Text(fakeTransformer(codeBlockType, rawCodeBlock));
  }

  /// Set supported code block types to all those that Kroki package supports.
  OurSecondTestTransfomer() : super(handledCodeBlockTypes: ourBlockTypeList);
}

// Synchronous transformer for testing.
class OurTestTransfomer extends CodeBlockTransformer {
  static const ourBlockTypeList = ['testtype', 'mermaid', 'diagram2'];

  String fakeTransformer(String codeBlockType, String rawCodeBlock) {
    switch (codeBlockType) {
      case 'testtype':
        return 'testtype${rawCodeBlock}testtype';
      case 'mermaid':
        return '<svg fill="currentColor" viewBox="0 0 896 1024" xmlns="http://www.w3.org/2000/svg"><path d="M128 768h256v64H128v-64z m320-384H128v64h320v-64z m128 192V448L384 640l192 192V704h320V576H576z m-288-64H128v64h160v-64zM128 704h160v-64H128v64z m576 64h64v128c-1 18-7 33-19 45s-27 18-45 19H64c-35 0-64-29-64-64V192c0-35 29-64 64-64h192C256 57 313 0 384 0s128 57 128 128h192c35 0 64 29 64 64v320h-64V320H64v576h640V768zM128 256h512c0-35-29-64-64-64h-64c-35 0-64-29-64-64s-29-64-64-64-64 29-64 64-29 64-64 64h-64c-35 0-64 29-64 64z"></path></svg>';
      case 'diagram2':
        return '<div id="diagram2">$rawCodeBlock</div>';
    }
    return 'unsupported type';
  }

  @override
  Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, BlockParser parser) {
    return Text(fakeTransformer(codeBlockType, rawCodeBlock));
  }

  /// Set supported code block types to all those that Kroki package supports.
  OurTestTransfomer() : super(handledCodeBlockTypes: ourBlockTypeList);
}

final ourTestTransformingFencedCodeBlock =
    TransformableFencedCodeBlockSyntax([OurTestTransfomer()]);

// Async transformer for testing future completions.
class OurAsyncTestTransfomer extends CodeBlockTransformer {
  static const ourBlockTypeList = ['testtype', 'mermaid', 'diagram2'];

  Future<String> fakeAsyncTransformer(
      String codeBlockType, String rawCodeBlock) {
    switch (codeBlockType) {
      case 'testtype':
        return Future.delayed(Duration(milliseconds: 1000),
            () => 'testtype${rawCodeBlock}testtype');
      case 'mermaid':
        return Future.value(
            '<svg fill="currentColor" viewBox="0 0 896 1024" xmlns="http://www.w3.org/2000/svg"><path d="M128 768h256v64H128v-64z m320-384H128v64h320v-64z m128 192V448L384 640l192 192V704h320V576H576z m-288-64H128v64h160v-64zM128 704h160v-64H128v64z m576 64h64v128c-1 18-7 33-19 45s-27 18-45 19H64c-35 0-64-29-64-64V192c0-35 29-64 64-64h192C256 57 313 0 384 0s128 57 128 128h192c35 0 64 29 64 64v320h-64V320H64v576h640V768zM128 256h512c0-35-29-64-64-64h-64c-35 0-64-29-64-64s-29-64-64-64-64 29-64 64-29 64-64 64h-64c-35 0-64 29-64 64z"></path></svg>');
      case 'diagram2':
        return Future.sync(() => '<div id="diagram2">$rawCodeBlock</div>');
    }
    return Future.value('unsupported type');
  }

  @override
  Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, BlockParser parser) {
    final asyncText = AsyncText(
        fakeAsyncTransformer(codeBlockType, rawCodeBlock), parser,
        uncompletedFutureTextValue:
            rawCodeBlock // Fallback to showing original diagram source.
        );
    return asyncText;
  }

  /// Set supported code block types to all those that Kroki package supports.
  OurAsyncTestTransfomer() : super(handledCodeBlockTypes: ourBlockTypeList);
}

final ourAsyncTestTransformingFencedCodeBlock =
    TransformableFencedCodeBlockSyntax([OurAsyncTestTransfomer()]);

// This test 2 transformers in the list.
final ourTest2TransformingFencedCodeBlock = TransformableFencedCodeBlockSyntax(
    [OurTestTransfomer(), OurSecondTestTransfomer()]);

// This test 2 transformers in the list, one async and the other synchronous.
final ourAsyncMix2TestTransformingFencedCodeBlock =
    TransformableFencedCodeBlockSyntax(
        [OurAsyncTestTransfomer(), OurSecondTestTransfomer()]);

void main() async {
  // Test synchronous Transformed Fenced Block syntax extensions.
  testFile(
    'extensions/transformed_fenced_code_blocks.unit',
    blockSyntaxes: [
      ourTestTransformingFencedCodeBlock,
      FencedCodeBlockSyntax()
    ],
  );

  // Test Asynchronous transformed fenced code block.
  testFileAsync(
    'extensions/transformed_fenced_code_blocks.unit',
    blockSyntaxes: [
      ourAsyncTestTransformingFencedCodeBlock,
      FencedCodeBlockSyntax()
    ],
  );

  // Test unhandled data - synchronous Transformed Fenced Block syntax extensions.
  testFile(
    'extensions/fenced_code_blocks.unit',
    blockSyntaxes: [ourTestTransformingFencedCodeBlock],
  );

  // Test unhandled data Asynchronous transformed fenced code block.
  testFileAsync(
    'extensions/fenced_code_blocks.unit',
    blockSyntaxes: [ourAsyncTestTransformingFencedCodeBlock],
  );

  // Test 2 transformers in Transformed Fenced Block syntax extensions.
  testFile(
    'extensions/transformed2_fenced_code_blocks.unit',
    blockSyntaxes: [ourTest2TransformingFencedCodeBlock],
  );

  // Test 2 transformers in mix of Sync/Asynchronous transformed fenced code block.
  testFileAsync(
    'extensions/transformed2_fenced_code_blocks.unit',
    blockSyntaxes: [ourAsyncMix2TestTransformingFencedCodeBlock],
  );
}

void testFileAsync(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) async {
  final directory = p.join(await markdownPackageRoot, 'test');
  for (final dataCase in dataCasesInFile(path: p.join(directory, file))) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCoreAsync(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
    );
  }
}

void validateCoreAsync(
  String description,
  String markdown,
  String html, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
}) {
  test(description, () async {
    final result = await markdownToHtmlWithAsyncTransforms(
      markdown,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      extensionSet: extensionSet,
      linkResolver: linkResolver,
      imageLinkResolver: imageLinkResolver,
    );

    markdownPrintOnFailure(markdown, html, result);

    expect(result, html);
  });
}
