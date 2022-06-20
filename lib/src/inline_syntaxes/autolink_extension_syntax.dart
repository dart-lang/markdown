// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/src/charcode.dart';

import '../ast.dart';
import '../extensions.dart';
import '../parsers/inline_parser.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `http://foo.com`.
class AutolinkExtensionSyntax extends InlineSyntax {
  static const _linkPattern =
      // Autolinks can only come at the beginning of a line, after whitespace,
      // or any of the delimiting characters *, _, ~, and (.
      r'(?<=^|[\s*_~(>])'

      // An extended url autolink will be recognised when one of the schemes
      // http://, or https://, followed by a valid domain. See
      // https://github.github.com/gfm/#extended-url-autolink.
      r'(?:(?:https?|ftp):\/\/|www\.)'

      // A valid domain consists of segments of alphanumeric characters,
      // underscores (_) and hyphens (-) separated by periods (.). There must
      // be at least one period, and no underscores may be present in the last
      // two segments of the domain. See
      // https://github.github.com/gfm/#valid-domain.
      r'(?:[-_a-z0-9]+\.)*(?:[-a-z0-9]+\.[-a-z0-9]+)'

      // After a valid domain, zero or more non-space non-< characters may
      // follow.
      r'[^\s<]*'

      // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will
      // not be considered part of the autolink, though they may be included in
      // the interior of the link. See
      // https://github.github.com/gfm/#extended-autolink-path-validation.
      '(?<![?!.,:*_~])';

  // An extended email autolink, see
  // https://github.github.com/gfm/#extended-email-autolink.
  static const _emailPattern =
      r'[-_.+a-z0-9]+@(?:[-_a-z0-9]+\.)+[-_a-z0-9]*[a-z0-9](?![-_])';

  AutolinkExtensionSyntax({
    bool enableLink = true,
    bool enableEmail = true,
  })  : assert(enableLink == true || enableEmail == true),
        super(RegExp(
          '(${enableLink ? _linkPattern : ''})'
          '|(${enableEmail ? _emailPattern : ''})',
          multiLine: true,
          caseSensitive: false,
        ));

  @override
  Node? parse(InlineParser parser, Match match) {
    final text = match.match;

    int consumeLength;
    var isEmail = false;
    if (match[2] == null) {
      consumeLength = _getConsumeLength(text);
    } else {
      consumeLength = text.length;
      isEmail = true;
    }

    final span = parser.consumeBy(consumeLength).first;
    var destination = span.text;
    if (isEmail) {
      destination = 'mailto:$destination';
    } else if (!destination.startsWith(RegExp(r'(https?|ftp):\/\/'))) {
      destination = 'http://$destination';
    }

    return Element(
      'extendedAutolink',
      children: [Text.fromSpan(span)],
      attributes: {'destination': destination},
    );
  }

  int _getConsumeLength(String text) {
    var spareLength = 0;

    // When an autolink ends in `)`, see
    // https://github.github.com/gfm/#example-624.
    if (text.endsWith(')')) {
      final match = RegExp(r'(\(.*)?(\)+)$').firstMatch(text)!;

      if (match[1] == null) {
        spareLength = match[2]!.length;
      } else {
        final segment = match.match;
        var parenCount = 0;
        for (var i = 0; i < segment.length; i++) {
          final char = segment.codeUnitAt(i);
          if (char == $lparen) {
            parenCount++;
          } else if (char == $rparen) {
            parenCount--;
          }
        }
        if (parenCount < 0) {
          spareLength = parenCount.abs();
        }
      }
    }
    // If an autolink ends in a semicolon `;`, see
    // https://github.github.com/gfm/#example-626
    else if (text.endsWith(';')) {
      final match = RegExp(r'&[0-9a-z]+;$').firstMatch(text);
      if (match != null) {
        spareLength = match.match.length;
      }
    }

    return text.length - spareLength;
  }
}
