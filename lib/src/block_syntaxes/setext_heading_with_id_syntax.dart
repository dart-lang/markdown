// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../parsers/block_parser.dart';
import 'block_syntax.dart';
import 'setext_heading_syntax.dart';

@Deprecated('Use SetextHeadingWithIdSyntax instead')
class SetextHeaderWithIdSyntax extends SetextHeadingWithIdSyntax {}

/// Parses setext-style headers, and adds generated IDs to the generated
/// elements.
class SetextHeadingWithIdSyntax extends SetextHeadingSyntax {
  const SetextHeadingWithIdSyntax();

  @override
  Node parse(BlockParser parser) {
    final element = super.parse(parser) as Element;
    element.attributes['generatedId'] = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}
