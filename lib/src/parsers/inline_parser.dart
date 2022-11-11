// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../document.dart';
import '../inline_parser.dart' as deprecated_inline_parser;
import '../markdown.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
// TODO(Zhiguang): merge in the old InlineParser in the next major version.
class InlineParser extends deprecated_inline_parser.InlineParser {
  InlineParser(String source, Markdown markdown)
      : super(source, Document(), markdown: markdown);
}
