// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'package:source_span/source_span.dart';

import '../charcode.dart';
import '../extensions.dart';
import '../util.dart';
import 'backslash_parser.dart';
import 'source_parser.dart';

class LinkParser extends SourceParser {
  /// If there is a valid link formed.
  bool valid = false;

  /// Link label.
  final label = <SourceSpan>[];

  /// Link destination.
  final destination = <SourceSpan>[];

  /// Link title.
  List<SourceSpan>? title;

  /// The formatted destination and title.
  final formatted = _FormattedAttributes();

  ///
  final markers = <SourceSpan>[];

  LinkParser(List<SourceSpan> source) : super(source);

  /// Parses [source] to a link reference definition.
  void parseDefinition() {
    if (!parseLabel() || isDone || charAt() != $colon) {
      return;
    }

    // Add `:` to markers.
    markers.add(spanAt());

    advance();
    if (!_parseDestination()) {
      return;
    }

    var precedingWhitespaces = moveThroughWhitespace();
    if (isDone) {
      valid = true;
      return;
    }

    final multiline = charAt() == $lf;
    precedingWhitespaces += moveThroughWhitespace(multiLine: true);

    // The title must be preceded by whitespaces.
    if (precedingWhitespaces == 0 || isDone) {
      valid = isDone;
      return;
    }

    final validTitle = _parseTitle();
    // For example: `[foo]: <bar> "baz` is a invalid definition, but this one is
    // valid:
    // ```
    // [foo]: <bar>
    // "baz
    // ```
    if (!validTitle && !multiline) {
      return;
    }

    if (validTitle) {
      moveThroughWhitespace();
      if (!isDone && charAt() != $lf) {
        // It is not a valid definition if the title is followed by
        // non-whitespace character, for example: `[foo]: <bar> "baz" hello`.
        // See https://spec.commonmark.org/0.30/#example-209.
        if (!multiline) {
          return;
        }
        // But if it is valid if the definition is multiline, see
        // https://spec.commonmark.org/0.30/#example-210.
        title = null;
      }
    }

    // In order to collect the final line ending.
    moveThroughWhitespace(multiLine: true);
    valid = true;
  }

  /// Parses [source] to a inline link.
  void parseInlineLink() {
    // Add `(` to markers.
    markers.add(spanAt());

    // Walk past the opening `(`.
    advance();
    if (!_parseDestination(isInlineLink: true)) {
      return;
    }
    final hasWhitespace = moveThroughWhitespace(multiLine: true) > 0;

    // Does not hit ending `)`, invalid;
    if (isDone) {
      return;
    }

    // Hit the ending `)`, no title, valid.
    if (charAt() == $rparen) {
      // Add `)` to markers.
      markers.add(spanAt());
      valid = true;
      return;
    }

    // No whitespaces between the destination and possible title, invalid.
    if (!hasWhitespace) {
      return;
    }

    // The title is invalid which makes the entire link invalid.
    if (!_parseTitle()) {
      return;
    }
    moveThroughWhitespace(multiLine: true);

    // No ending `)` is found, invalid.
    if (isDone || charAt() != $rparen) {
      return;
    }

    // Add `)` to markers.
    markers.add(spanAt());
    valid = true;
  }

  /// Parses the link label, returns `true` there is a valid link label found.
  bool parseLabel() {
    moveThroughWhitespace(multiLine: true);
    if (length - position < 2) {
      return false;
    }

    if (charAt() != $lbracket) {
      return false;
    }

    // Add `[` to markers.
    markers.add(spanAt());

    // Advance past the opening `[`.
    advance();
    final start = position;

    // A link label can have at most 999 characters inside the square brackets.
    // See https://spec.commonmark.org/0.30/#link-label.
    var maxLoop = 999;
    while (true) {
      if (maxLoop-- < 0) {
        return false;
      }
      final char = charAt(position);
      if (char == $backslash) {
        advance();
      } else if (char == $lbracket) {
        return false;
      } else if (char == $rbracket) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    final spans = subspan(start, position);
    if (spans.isEmpty || spans.isEmptyContent()) {
      return false;
    }
    spans
      ..first.trimLeft()
      ..last.trimLeft();
    // Add `]` to markers.
    markers.add(spanAt());

    // Advance past the closing `]`.
    advance();
    label.addAll(spans);
    return true;
  }

  /// Parses the link destination, returns `true` there is a valid link
  /// destination found.
  bool _parseDestination({
    bool isInlineLink = false,
  }) {
    moveThroughWhitespace(multiLine: true);
    if (isDone) {
      return false;
    }

    final validDestination = charAt() == $lt
        ? _parseInlineBracketedLink()
        : _parseInlineBareDestinationLink(isInlineLink: isInlineLink);

    if (validDestination) {
      _formatAttribute(
        'destination',
        destination,
      );
    }

    return validDestination;
  }

  /// Parse an inline link with a bracketed destination (a destination wrapped
  /// in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns `true` if there is a valid link destination found.
  bool _parseInlineBracketedLink() {
    // Add `<` to markers.
    markers.add(spanAt());

    // Walk past the opening `<`.
    advance();

    final start = position;
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == $lf || char == $cr || char == $ff) {
        return false;
      } else if (char == $gt) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    final spans = subspan(start, position);

    markers.addAll(spans);

    // Add `>` to markers.
    markers.add(spanAt());

    // Advance past the closing `>`.
    advance();
    destination.addAll(spans);
    return true;
  }

  /// Parse an inline link with a "bare" destination (a destination _not_
  /// wrapped in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns `true` if there is a valid link destination found.
  bool _parseInlineBareDestinationLink({
    bool isInlineLink = false,
  }) {
    var parenCount = 0;
    final start = position;
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == $space || char == $lf || char == $cr || char == $ff) {
        break;
      } else if (char == $lparen) {
        parenCount++;
      } else if (char == $rparen) {
        parenCount--;
        if (!isInlineLink && parenCount == 0) {
          advance();
          break;
        } else if (isInlineLink && parenCount == -1) {
          break;
        }
      }
      advance();

      // There is no ending delimiter, so `isDone` also means it is at the end
      // of a link destination.
      if (isDone) {
        break;
      }
    }

    destination.addAll(subspan(start, position));
    markers.addAll(destination);
    return true;
  }

  /// Parses the **optional** link title, returns `true` if there is a valid
  /// link title found.
  bool _parseTitle() {
    // See: https://spec.commonmark.org/0.30/#link-title
    // The whitespace should be followed by a title delimiter.
    final delimiter = charAt();
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return false;
    }

    final closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    markers.add(spanAt());
    advance();
    if (isDone) {
      return false;
    }
    final start = position;

    // Now we look for an un-escaped closing delimiter.
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == closeDelimiter) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    if (isDone) {
      return false;
    }

    title = subspan(start, position);
    markers
      ..addAll(title!)
      ..add(spanAt());
    // Advance past the closing delimiter.
    advance();
    _formatAttribute('title', title!);
    return true;
  }

  void _formatAttribute(
    String attribute,
    List<SourceSpan> spans,
  ) {
    final backslashParser = BackslashParser(spans);
    markers.addAll(backslashParser.markers);
    var text = backslashParser.text;

    if (attribute == 'destination') {
      // This is an ugly solution for:
      // https://spec.commonmark.org/0.30/#example-502.
      // TODO(Zhiguang): Find a right solution to avoid this double
      // percent-encoding problem.
      try {
        text = Uri.decodeFull(text);
      } catch (_) {}
      text = Uri.encodeFull(decodeHtmlCharacters(text));
      formatted.destination = text;
    } else if (attribute == 'title') {
      text = decodeHtmlCharacters(text);
      text = HtmlEscape(HtmlEscapeMode.attribute).convert(text);
      formatted.title = text;
    }
  }
}

class _FormattedAttributes {
  late String destination;
  String? title;
}
