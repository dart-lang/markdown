// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../markdown.dart';
import '../charcode.dart';
import '../patterns.dart';

@Deprecated('Use RawHtmlSyntax instead')
class InlineHtmlSyntax extends RawHtmlSyntax {}

/// Leave inline HTML tags alone, from
/// [CommonMark 0.30](http://spec.commonmark.org/0.30/#raw-html).
///
/// This is not actually a good definition (nor CommonMark's) of an HTML tag,
/// but it is fast. It will leave text like `<a href='hi">` alone, which is
/// incorrect.
// TODO(srawlins): improve accuracy while ensuring performance, once
/// Markdown benchmarking is more mature.
class RawHtmlSyntax extends InlineSyntax {
  RawHtmlSyntax() : super(rawHtmlPattern, startCharacter: $lt);

  @override
  Node? parse(InlineParser parser, Match match) {
    final spans = parser.consumeBy(match[0]!.length);

    return Element(
      'rawHtml',
      children: spans.map((span) => Text.fromSpan(span)).toList(),
    );
  }
}
