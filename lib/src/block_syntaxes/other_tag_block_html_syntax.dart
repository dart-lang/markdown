// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../block_parser.dart';
import 'block_tag_block_html_syntax.dart';

class OtherTagBlockHtmlSyntax extends BlockTagBlockHtmlSyntax {
  @override
  bool canEndBlock(BlockParser parser) => false;

  // Really hacky way to detect "other" HTML. This matches:
  //
  // * any opening spaces
  // * open bracket and maybe a slash ("<" or "</")
  // * some word characters
  // * either:
  //   * a close bracket, or
  //   * whitespace followed by not-brackets followed by a close bracket
  // * possible whitespace and the end of the line.
  @override
  RegExp get pattern => RegExp(r'^ {0,3}</?\w+(?:>|\s+[^>]*>)\s*$');

  const OtherTagBlockHtmlSyntax();
}
