// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../patterns.dart';
import 'list_syntax.dart';

/// Parses unordered lists.
class UnorderedListWithCheckBoxSyntax extends ListSyntax {
  @override
  RegExp get pattern => ulWithCheckBoxPattern;

  @override
  String get listTag => 'ul_with_checkbox';

  const UnorderedListWithCheckBoxSyntax();
}
