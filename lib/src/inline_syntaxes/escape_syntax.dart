// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';
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
    if (parser.encodeHtml) {
      if (char == $double_quote) {
        parser.addNode(Text('&quot;'));
      } else if (char == $lt) {
        parser.addNode(Text('&lt;'));
      } else if (char == $gt) {
        parser.addNode(Text('&gt;'));
      } else {
        parser.addNode(Text(chars[1]));
      }
    } else {
      parser.addNode(Text(chars[1]));
    }
    return true;
  }
}
