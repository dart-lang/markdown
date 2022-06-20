// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../extensions.dart';
import '../parsers/inline_parser.dart';
import 'inline_syntax.dart';

@Deprecated('Use AutolinkSyntax instead')
class EmailAutolinkSyntax extends AutolinkSyntax {}

/// Matches autolinks like `<http://foo.com>` or `<mailto:foo@bar.baz>`.
class AutolinkSyntax extends InlineSyntax {
  // See https://spec.commonmark.org/0.30/#autolink.
  static const _linkPattern = r'[a-z][a-z\-\+\.]+:(?://)?[^\s>]*';

  // See https://spec.commonmark.org/0.30/#email-autolink.
  static const _emailPattern =
      r'''[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}'''
      r'''[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*''';

  AutolinkSyntax({
    bool enableLink = true,
    bool enableEmail = true,
  })  : assert(enableLink == true || enableEmail == true),
        super(
          RegExp(
            '<(?:(${enableLink ? _linkPattern : ''})'
            '|(${enableEmail ? _emailPattern : ''}))>',
            caseSensitive: false,
            multiLine: true,
          ),
          startCharacter: $lt,
        );

  @override
  Node? parse(InlineParser parser, Match match) {
    final markers = [parser.consume()];
    final span = parser.consumeBy(match.match.length - 2).first;
    markers.add(parser.consume());

    String destination;
    if (match[2] == null) {
      destination = Uri.encodeFull(span.text).toHtmlText();
    } else {
      destination = 'mailto:${span.text.toHtmlText()}';
    }

    return Element(
      'autolink',
      children: [Text.fromSpan(span)],
      markers: markers,
      attributes: {
        'destination': destination,
        'text': span.text.toHtmlText(),
      },
    );
  }
}
