// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks between two ~~~ or ``` sequences.
///
/// See the CommonMark spec:
/// https://spec.commonmark.org/0.30/#fenced-code-blocks
class FencedCodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => codeFencePattern;

  const FencedCodeBlockSyntax();

  @override
  Node parse(BlockParser parser) {
    final openingFence = _FenceMatch.fromMatch(pattern.firstMatch(
      escapePunctuation(parser.current.content),
    )!);

    var text = parseChildLines(
      parser,
      openingFence.marker,
      openingFence.indent,
    ).map((e) => e.content).join('\n');

    if (parser.document.encodeHtml) {
      text = escapeHtml(text, escapeApos: false);
    }
    if (text.isNotEmpty) {
      text = '$text\n';
    }

    final code = Element.text('code', text);
    if (openingFence.hasLanguage) {
      var language = decodeHtmlCharacters(openingFence.language);
      if (parser.document.encodeHtml) {
        language = escapeHtmlAttribute(language);
      }
      code.attributes['class'] = 'language-$language';
    }

    return Element('pre', [code]);
  }

  String _removeIndentation(String content, int length) {
    final text = content.replaceFirst(RegExp('^\\s{0,$length}'), '');
    return content.substring(content.length - text.length);
  }

  @override
  List<Line> parseChildLines(
    BlockParser parser, [
    String openingMarker = '',
    int indent = 0,
  ]) {
    final childLines = <Line>[];

    parser.advance();

    _FenceMatch? closingFence;
    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current.content);
      closingFence = match == null ? null : _FenceMatch.fromMatch(match);

      // Closing code fences cannot have info strings:
      // https://spec.commonmark.org/0.30/#example-147
      if (closingFence == null ||
          !closingFence.marker.startsWith(openingMarker) ||
          closingFence.hasInfo) {
        childLines.add(
          Line(_removeIndentation(parser.current.content, indent)),
        );
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    // https://spec.commonmark.org/0.30/#example-127
    // https://spec.commonmark.org/0.30/#example-128
    if (closingFence == null &&
        childLines.isNotEmpty &&
        childLines.last.isBlankLine) {
      childLines.removeLast();
    }

    return childLines;
  }
}

class _FenceMatch {
  _FenceMatch._({
    required this.indent,
    required this.marker,
    required this.info,
  });

  factory _FenceMatch.fromMatch(RegExpMatch match) {
    String marker;
    String info;

    if (match.namedGroup('backtick') != null) {
      marker = match.namedGroup('backtick')!;
      info = match.namedGroup('backtickInfo')!;
    } else {
      marker = match.namedGroup('tilde')!;
      info = match.namedGroup('tildeInfo')!;
    }

    return _FenceMatch._(
      indent: match[1]!.length,
      marker: marker,
      info: info.trim(),
    );
  }

  final int indent;
  final String marker;

  // The info-string should be trimmed,
  // https://spec.commonmark.org/0.30/#info-string.
  final String info;

  // The first word of the info string is typically used to specify the language
  // of the code sample,
  // https://spec.commonmark.org/0.30/#example-143.
  String get language => info.split(' ').first;

  bool get hasInfo => info.isNotEmpty;

  bool get hasLanguage => language.isNotEmpty;
}
