// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  group('Document', () {
    test('encodeHtml prevents less than and ampersand escaping', () {
      var document = new Document(encodeHtml: false);
      var result = document.parseInline('< &');
      expect(result, hasLength(1));
      expect(
          result[0],
          const TypeMatcher<Text>()
              .having((e) => e.text, 'text', equals('< &')));
    });
  });
}
