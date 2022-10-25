// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Decodes numeric character references, for example decode `&#35;` to `#`.
// https://spec.commonmark.org/0.30/#entity-and-numeric-character-references
class DecodeHtmlSyntax extends InlineSyntax {
  DecodeHtmlSyntax()
      : super(htmlCharactersPattern.pattern,
            caseSensitive: false, startCharacter: $ampersand);

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    if (parser.pos > 0 && parser.charAt(parser.pos - 1) == $backquote) {
      return false;
    }

    final match = pattern.matchAsPrefix(parser.source, parser.pos);
    if (match == null) {
      return false;
    }

    // TODO(Zhiguang): Enable HTML entity decoding when working on HTML escape
    // issues.
    if (match[1] != null) {
      return false;
    }

    parser.writeText();
    if (onMatch(parser, match)) parser.consume(match.match.length);
    return true;
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    final decodedText = decodeHtmlCharacterFromMatch(match);

    parser.addNode(Text(decodedText));
    return true;
  }
}
