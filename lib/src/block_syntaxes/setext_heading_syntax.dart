// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../extensions.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'paragraph_syntax.dart';

@Deprecated('Use SetextHeadingSyntax instead')
class SetextHeaderSyntax extends SetextHeadingSyntax {}

/// Parses setext-style headers.
class SetextHeadingSyntax extends BlockSyntax {
  @override
  RegExp get pattern => setextPattern;

  const SetextHeadingSyntax();

  @override
  bool canParse(BlockParser parser) {
    final lastSyntax = parser.currentSyntax;
    if (parser.setextHeadingDisabled || lastSyntax is! ParagraphSyntax) {
      return false;
    }
    final matched = parser.current.hasMatch(pattern, syntax: this);
    if (matched) {
      if (parser.linesBuffer.isEmpty) {
        parser.current.neverMatch(this);
        return false;
      }
    }

    return matched;
  }

  @override
  Node? parse(BlockParser parser) {
    // The `linesBuffer` could have been consumed and transformed to link
    // reference definitions.
    if (parser.linesBuffer.isEmpty) {
      return null;
    }

    final marker = parser.current.content.trim();
    final level = (marker.text[0] == '=') ? '1' : '2';
    final lineEndings = <SourceSpan>[
      if (parser.current.lineEnding != null) parser.current.lineEnding!
    ];

    final content = parser.linesBuffer.toNodes(
      ((e) => UnparsedContent.fromSpan(e)),
      trimLeading: true,
      trimTrailing: true,
      popLineEnding: true,
    );

    if (content.lineEnding != null) {
      lineEndings.add(content.lineEnding!);
    }

    // TODO(Zhiguang): Fix https://spec.commonmark.org/0.30/#example-91

    parser.linesBuffer.clear();
    parser.advance();

    return Element(
      'setextHeading',
      children: content.nodes,
      lineEndings: lineEndings,
      attributes: {'level': level},
    );
  }
}
