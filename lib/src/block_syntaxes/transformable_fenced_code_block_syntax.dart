// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../code_block_transformer.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks between two ~~~ or ``` sequences.
/// This differs from [FencedCodeBlockSyntax] in that a list of
/// [CodeBlockProcessor] processors is checked to see if any further
/// transformation is possible.
/// After gathering the code block the [postProcessors] list is checked to see
/// if there are any processors which handle the code block's
/// type [infoString] (check is not case sensitive).  If a processor is found
/// which handles the block's type then that processor is called with the
/// code block contents and given a chance to transform it.  If the processor
/// returns an Element than that Element is returned, else the [postProcessors]
/// list continues to be checked until there are no more processors.
/// If no processor transforms the code block then the code block is
/// handled as [FencedCodeBlockSyntax] would and a
///   `<pre><code [class='language-$infoString']>...</code><pre>`
/// Element is returned.
///
/// See the CommonMark spec: https://spec.commonmark.org/0.29/#fenced-code-blocks
class TransformableFencedCodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => codeFencePattern;

  Iterable<CodeBlockTransformer> codeBlockTransformers;

  TransformableFencedCodeBlockSyntax(Iterable<CodeBlockTransformer> this.codeBlockTransformers);

  @override
  bool canParse(BlockParser parser) {
    final match = pattern.firstMatch(parser.current);
    if (match == null) return false;
    final codeFence = match.group(1)!;
    final infoString = match.group(2);
    // From the CommonMark spec:
    //
    // > If the info string comes after a backtick fence, it may not contain
    // > any backtick characters.
    return (codeFence.codeUnitAt(0) != $backquote ||
        !infoString!.codeUnits.contains($backquote));
  }

  @override
  List<String> parseChildLines(BlockParser parser, [String? endBlock]) {
    endBlock ??= '';

    final childLines = <String>[];
    parser.advance();

    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current);
      if (match == null || !match[1]!.startsWith(endBlock)) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    // Get the syntax identifier, if there is one.
    final match = pattern.firstMatch(parser.current)!;
    final endBlock = match.group(1);
    var infoString = match.group(2)!;

    final childLines = parseChildLines(parser, endBlock);

    // The Markdown tests expect a trailing newline.
    childLines.add('');

    var text = childLines.join('\n');
    String? encodedHtmlText; 

    // The info-string should be trimmed.
    // http://spec.commonmark.org/0.22/#example-100
    infoString = infoString.trim();
    if (infoString.isNotEmpty) {
      // Only use the first word in the syntax.
      // http://spec.commonmark.org/0.22/#example-100
      final firstSpace = infoString.indexOf(' ');
      if (firstSpace >= 0) {
        infoString = infoString.substring(0, firstSpace);
      }
      if (parser.document.encodeHtml) {
        infoString = escapeHtmlAttribute(infoString);
      }
    }

    // Now loop through code block transformers as see if the block
    // can be transformed.
    for (final transformer in codeBlockTransformers) {
      if (transformer.canTransformCodeBlockType(infoString)) {
        final codeblock = transformer.expectsEncodedHtml ? 
                    (encodedHtmlText ?? (encodedHtmlText=escapeHtml(text))) :
                    text;
        final transformedBlock = transformer.transformCodeBlock(codeblock);
        if (transformedBlock != null) return transformedBlock;
      }
    }

    // No transformers, treat this code block as we normally would in
    // [FencedCodeBlockSyntax].
    if (parser.document.encodeHtml) {
      text = encodedHtmlText ?? escapeHtml(text);
    }
    final code = Element.text('code', text);
    code.attributes['class'] = 'language-$infoString';
    final element = Element('pre', [code]);
    return element;
  }
}
