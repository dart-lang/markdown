// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';

abstract class CodeBlockTransformer {
  /// override this with list of code block types the CodeBlockProcessor
  /// handles.  The list of strings should be all lower-case as it will be
  /// checked with lower cased strings so that it is case insensitive.
  List<String> handledCodeBlockTypes = []; 

  bool expectsEncodedHtml = false;

  bool canTransformCodeBlockType(String blockType) {
    return handledCodeBlockTypes.contains(blockType.toLowerCase());
  }

  Node? transformCodeBlock(String rawCodeBlock);

  CodeBlockTransformer();
}