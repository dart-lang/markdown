// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../block_parser.dart';
import '../patterns.dart';
import 'list_syntax.dart';

/// Parses unordered lists.
class UnorderedListSyntax extends ListSyntax {
  @override
  RegExp get pattern => ulPattern;

  @override
  bool canParse(BlockParser parser) {
    if (hrPattern.hasMatch(parser.current)) {
      return false;
    }

    return pattern.hasMatch(parser.current);
  }

  @override
  String get listTag => 'ul';

  const UnorderedListSyntax({super.enableCheckbox = false});
}
