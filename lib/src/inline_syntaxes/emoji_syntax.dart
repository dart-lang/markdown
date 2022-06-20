// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../../assets/emojis.dart';
import '../ast.dart';
import '../extensions.dart';
import '../parsers/inline_parser.dart';
import 'inline_syntax.dart';

/// Matches GitHub Markdown emoji syntax like `:smile:`.
///
/// There is no formal specification of GitHub's support for this colon-based
/// emoji support, so this syntax is based on the results of Markdown-enabled
/// text fields at github.com.
class EmojiSyntax extends InlineSyntax {
  // Emoji "aliases" are mostly limited to lower-case letters, numbers, and
  // underscores, but GitHub also supports `:+1:` and `:-1:`.
  EmojiSyntax() : super(RegExp(':([a-z0-9_+-]+):'));

  @override
  Node? parse(InlineParser parser, Match match) {
    final alias = match[1]!;
    final emoji = emojis[alias];
    final markers = <SourceSpan>[];

    if (emoji == null) {
      return null;
    }

    markers.addAll(parser.consumeBy(match.match.length));

    return Element(
      'emoji',
      markers: markers,
      attributes: {'emoji': emoji},
    );
  }
}
