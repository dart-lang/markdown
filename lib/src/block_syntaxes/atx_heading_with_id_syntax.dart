// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import 'atx_heading_syntax.dart';
import 'block_syntax.dart';

@Deprecated('Use AtxHeadingWithIdSyntax instead')
class HeaderWithIdSyntax extends AtxHeadingWithIdSyntax {}

/// Parses atx-style headers, and adds generated IDs to the generated elements.
class AtxHeadingWithIdSyntax extends AtxHeadingSyntax {
  const AtxHeadingWithIdSyntax();

  @override
  Node parse(BlockParser parser) {
    final element = super.parse(parser) as Element;
    element.attributes['generatedId'] = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}
