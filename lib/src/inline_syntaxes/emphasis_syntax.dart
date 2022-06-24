// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../charcode.dart';
import 'delimiter_syntax.dart';

class EmphasisSyntax extends DelimiterSyntax {
  /// Parses `__strong__` and `_emphasis_`.
  EmphasisSyntax.underscore()
      : super(
          '_+',
          startCharacter: $underscore,
          requiresDelimiterRun: true,
          tags: _tags,
        );

  /// Parses `**strong**` and `*emphasis*`.
  EmphasisSyntax.asterisk()
      : super(
          r'\*+',
          startCharacter: $asterisk,
          requiresDelimiterRun: true,
          allowIntraWord: true,
          tags: _tags,
        );

  static final _tags = [
    DelimiterTag('emphasis', 1),
    DelimiterTag('strongEmphasis', 2),
  ];
}
