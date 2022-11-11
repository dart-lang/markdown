// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../block_parser.dart' as deprecated_block_parser;
import '../document.dart';
import '../markdown.dart';

/// Maintains the internal state needed to parse a series of lines into blocks
/// of Markdown suitable for further inline parsing.
// TODO(Zhiguang): merge in the old BlockParser in the next major version.
class BlockParser extends deprecated_block_parser.BlockParser {
  BlockParser(List<String> lines, Markdown markdown)
      : super(lines, Document(), markdown: markdown);
}
