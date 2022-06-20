// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:source_span/source_span.dart';

import '../charcode.dart';
import '../extensions.dart';

/// Matches backtick-enclosed inline code blocks.
class CodeSyntax extends InlineSyntax {
  // This pattern matches:
  //
  // * a string of backticks (not followed by any more), followed by
  // * a non-greedy string of anything, including newlines, ending with anything
  //   except a backtick, followed by
  // * a string of backticks the same length as the first, not followed by any
  //   more.
  //
  // This conforms to the delimiters of inline code, both in Markdown.pl, and
  // CommonMark.
  static const _pattern = r'(`+(?!`))(?:.|\n)*?[^`](\1)(?!`)';

  CodeSyntax()
      : super(
          RegExp(_pattern, multiLine: true),
          startCharacter: $backquote,
        );

  @override
  Match? tryMatch(InlineParser parser, [int? start]) {
    if (parser.position > 0 &&
        parser.charAt(parser.position - 1) == $backquote) {
      // Not really a match! We can't just sneak past one backtick to try the
      // next character. An example of this situation would be:
      //
      //     before ``` and `` after.
      //             ^--parser.pos
      return null;
    }

    return super.tryMatch(parser, start);
  }

  @override
  Node parse(InlineParser parser, Match match) {
    final markerLength = match[1]!.length;
    final contentLength = match.match.length - markerLength * 2;
    final markers = parser.consumeBy(markerLength);
    final lineEndings = <SourceSpan>[];
    final contentSpans = <SourceSpan>[];

    _parseAndStrip(
      parser,
      contentLength: contentLength,
      lineEndings: lineEndings,
      contentSpans: contentSpans,
    );

    if (contentSpans.isEmpty) {
      contentSpans.addAll(parser.consumeBy(contentLength));
    }

    markers.add(parser.consumeBy(markerLength).first);

    // Convert any line endings left with whitespaces.
    final finalContent = <SourceSpan>[];
    for (final span in contentSpans) {
      finalContent.addAll(span.convertLineEndings());
    }

    return Element(
      'codeSpan',
      children: finalContent.map((span) => Text.fromSpan(span)).toList(),
      markers: markers,
      lineEndings: lineEndings,
    );
  }

  void _parseAndStrip(
    InlineParser parser, {
    required int contentLength,
    required List<SourceSpan> lineEndings,
    required List<SourceSpan> contentSpans,
  }) {
    final contentText = parser.substring(
      parser.position,
      parser.position + contentLength,
    );

    // No stripping occurs if the code span contains only spaces:
    // https://spec.commonmark.org/0.30/#example-334.
    if (contentText.trim().isEmpty) {
      return;
    }

    final startsWithLineEnding = contentText.startsWith('\n');
    final endsWithLineEnding = contentText.endsWith('\n');

    // Only spaces, and not unicode whitespace in general, are stripped in this
    // way, see https://spec.commonmark.org/0.30/#example-333.
    final startWithSpace = startsWithLineEnding || contentText.startsWith(' ');
    final endsWithSpace = endsWithLineEnding || contentText.endsWith(' ');

    // The stripping only happens if the space is on both sides of the string:
    // https://spec.commonmark.org/0.30/#example-332.
    if (!startWithSpace || !endsWithSpace) {
      return;
    }

    // Save the stripped line ending.
    if (startsWithLineEnding) {
      lineEndings.add(parser.consume());
    } else {
      parser.advance();
    }

    contentSpans.addAll(parser.consumeBy(contentLength - 2));

    // Save the stripped line ending.
    if (endsWithLineEnding) {
      lineEndings.add(parser.consume());
    } else {
      parser.advance();
    }
  }
}
