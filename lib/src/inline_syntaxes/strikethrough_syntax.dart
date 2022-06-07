// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'delimiter_syntax.dart';

/// Matches strikethrough syntax according to the GFM spec.
class StrikethroughSyntax extends DelimiterSyntax {
  StrikethroughSyntax()
      : super(
          '~+',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          tags: [DelimiterTag('strikethrough', 2)],
        );
}
