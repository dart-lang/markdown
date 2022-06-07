// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks between two ~~~ or ``` sequences.
///
/// See the CommonMark spec: https://spec.commonmark.org/0.30/#fenced-code-blocks
class FencedCodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => codeFencePattern;

  const FencedCodeBlockSyntax();

  SourceSpan _removeIndentation(SourceSpan content, int length) {
    final text = content.text.replaceFirst(RegExp("^\\s{0,$length}"), '');
    return content.subspan(content.length - text.length);
  }

  BlockSyntaxChildSource parseChildLines(
    BlockParser parser,
    String endMarker,
    int indent,
  ) {
    final lines = <Line>[];
    final markders = [parser.current.content];
    final lineEndings = [parser.current.lineEnding!];

    parser.advance();

    while (!parser.isDone) {
      final match = parser.current.firstMatch(pattern);
      final parsedMatch = match == null ? null : _FenceMatch.fromMatch(match);

      // Closing code fences cannot have info strings:
      // https://spec.commonmark.org/0.30/#example-147
      if (parsedMatch == null ||
          !parsedMatch.marker.startsWith(endMarker) ||
          parsedMatch.info.isNotEmpty) {
        lines.add(Line(
          _removeIndentation(parser.current.content, indent),
          lineEnding: parser.current.lineEnding,
        ));
        parser.advance();
      } else {
        markders.add(parser.current.content);
        if (parser.current.lineEnding != null) {
          lineEndings.add(
            _removeIndentation(parser.current.lineEnding!, indent),
          );
        }
        parser.advance();
        break;
      }
    }

    return BlockSyntaxChildSource(
      lines: lines,
      markers: markders,
      lineEndings: lineEndings,
    );
  }

  @override
  Node parse(BlockParser parser) {
    final match = _FenceMatch.fromMatch(parser.current.firstMatch(pattern)!);
    final childSource = parseChildLines(parser, match.marker, match.indent);
    final codeLines = childSource.lines.toNodes((e) => Text.fromSpan(e)).nodes;

    final Map<String, String> attributes = {};
    if (match.info.isNotEmpty) {
      attributes['infoString'] = match.info;
    }

    return Element(
      'fencedCodeBlock',
      children: codeLines,
      attributes: attributes,
      lineEndings: childSource.lineEndings,
      markers: childSource.markers,
    );
  }
}

class _FenceMatch {
  _FenceMatch.fromMatch(Match match)
      : indent = match[1]!.length,
        marker = match[4] == null ? match[2]! : match[4]!,
        _info = match[4] == null ? match[3]! : match[5]!;

  final int indent;
  final String marker;
  final String _info;

  // the info-string should be trimmed
  // https://spec.commonmark.org/0.30/#info-string
  // only use the first word in the syntax
  // https://spec.commonmark.org/0.30/#example-143
  String get info => _info.trim().split(' ').first;
}
