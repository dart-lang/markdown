// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ordered_list_syntax.dart';

/// Parses ordered lists with checkboxes.
class OrderedListWithCheckBoxSyntax extends OrderedListSyntax {
  const OrderedListWithCheckBoxSyntax() : super(enableCheckbox: true);
}
