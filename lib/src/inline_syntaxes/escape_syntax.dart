// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../extensions.dart';
import '../inline_parser.dart';
import 'inline_syntax.dart';

/// Escape punctuation preceded by a backslash.
class EscapeSyntax extends InlineSyntax {
  EscapeSyntax() : super(r'''\\[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final chars = match.match;
    final char = chars.codeUnitAt(1);
    // Insert the substitution. Why these three charactes are replaced with
    // their equivalent HTML entity referenced appears to be missing from the
    // CommonMark spec, but is very present in all of the examples.
    // https://talk.commonmark.org/t/entity-ification-of-quotes-and-brackets-missing-from-spec/3207
    // TODO(Zhiguang): remove HTML encoding from here
    if (parser.encodeHtml) {
      if (char == $double_quote) {
        parser.addNode(Text.todo('&quot;'));
      } else if (char == $lt) {
        parser.addNode(Text.todo('&lt;'));
      } else if (char == $gt) {
        parser.addNode(Text.todo('&gt;'));
      } else if (char == $ampersand) {
        parser.addNode(Text.todo('&amp;'));
      } else {
        parser.addNode(_createText(parser));
      }
    } else {
      parser.addNode(_createText(parser));
    }
    return true;
  }

  Text _createText(InlineParser parser) =>
      parser.subText(parser.start + 1, parser.start + 2);
}
