// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:markdown/src/inline_syntaxes/text_syntax.dart';

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';

/// Leave inline HTML tags alone, from
/// [CommonMark 0.28](http://spec.commonmark.org/0.28/#raw-html).
///
/// This is not actually a good definition (nor CommonMark's) of an HTML tag,
/// but it is fast. It will leave text like `<a href='hi">` alone, which is
/// incorrect.
///
/// TODO(srawlins): improve accuracy while ensuring performance, once
/// Markdown benchmarking is more mature.
class InlineHtmlSyntax extends TextSyntax {
  InlineHtmlSyntax()
      : super(
          r'<[/!?]?[A-Za-z][A-Za-z0-9-]*(?:\s[^>]*)?>',
          startCharacter: $lt,
        );
  final brPattern = RegExp('<br>');
  @override
  bool onMatch(InlineParser parser, Match match) {
    if (brPattern.firstMatch(match.match) != null) {
      parser.addNode(Element.empty('br'));
    } else {
      if (substitute.isEmpty ||
          (match.start > 0 &&
              match.input.substring(match.start - 1, match.start) == '/')) {
        // Just use the original matched text.
        parser.advanceBy(match.match.length);
        return false;
      }
      // Insert the substitution.
      parser.addNode(Text(substitute));
    }

    return true;
  }
}
