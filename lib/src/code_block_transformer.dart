// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_parser.dart';

abstract class CodeBlockTransformer {
  /// [handledCodeBlockTypes] is set by constructor to the list of code
  /// block types that the [CodeBlockProcessor] subclass handles.  The list
  /// of strings should all be lower-case as it will be checked with lower
  /// cased strings so as to be case insensitive.
  late final List<String> handledCodeBlockTypes;

  bool expectsEncodedHtml = false;

  /// Override with more complex logic if desired.
  bool canTransformCodeBlockType(String blockType) {
    return handledCodeBlockTypes.contains(blockType.toLowerCase());
  }

  /// Implement this method to handle code block transformations.
  /// This will be called only with code block of the types specified
  /// in the constructor. [null] can be returned if no transformation
  /// is performed and you want to pass to the next [CodeBlockTransformer]
  /// in the [TransformableFencedCodeBlockSyntax]'s list.
  /// If asynchronous transformations are required return [AsyncText]
  /// nodes and be sure to use the [markdownToHtmlWithAsyncTransforms]
  /// method to initiate the transform.
  Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, BlockParser parser);

  CodeBlockTransformer({required this.handledCodeBlockTypes});
}
