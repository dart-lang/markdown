// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `<http://foo.com>` or `<mailto:foo@bar.baz>`.
class AutolinkSyntax extends InlineSyntax {
  AutolinkSyntax() : super(r'<(([a-zA-Z][a-zA-Z\-\+\.]+):(?://)?[^\s>]*)>');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final uri = match[1]!;
    final text = parser.encodeHtml ? escapeHtml(uri) : uri;
    final anchor = Element.todo(
      'autolink',
      children: [Text.todo(text)],
      attributes: {'uri': uri},
    );
    parser.addNode(anchor);

    return true;
  }
}
