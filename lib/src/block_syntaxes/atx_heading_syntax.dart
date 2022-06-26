// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../extensions.dart';
import '../parsers/block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

@Deprecated('Use AtxHeadingSyntax instead')
class HeaderSyntax extends AtxHeadingSyntax {}

/// Parses atx-style headers: `## Header ##`.
class AtxHeadingSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const AtxHeadingSyntax();

  @override
  Node parse(BlockParser parser) {
    final line = parser.current;
    final match = line.firstMatch(pattern)!;
    final lineString = match.match;

    final openMarker = match[1]!;
    final closeMarker = match[2];
    final level = openMarker.length;
    final openMarkerStart = lineString.indexOf(openMarker);
    final openMarkerEnd = openMarkerStart + level;

    SourceSpan? contentSpan;
    int? closeMarkerStart;
    if (closeMarker == null) {
      contentSpan = line.content.subspan(openMarkerEnd);
    } else {
      closeMarkerStart = lineString.lastIndexOf(closeMarker);
      contentSpan = line.content.subspan(
        openMarkerEnd,
        closeMarkerStart,
      );
    }
    contentSpan = contentSpan.trim();

    final markers = [
      line.content.subspan(openMarkerStart, openMarkerEnd),
      if (closeMarker != null) line.content.subspan(closeMarkerStart!),
    ];

    // https://github.github.com/gfm/#example-49.
    if (closeMarker == null && RegExp(r'^#+$').hasMatch(contentSpan.text)) {
      markers.add(contentSpan);
      contentSpan = null;
    }

    parser.advance();

    return Element(
      'atxHeading',
      markers: markers,
      children: [
        if (contentSpan != null) UnparsedContent.fromSpan(contentSpan.trim()),
      ],
      attributes: {'level': '$level'},
    );
  }
}
