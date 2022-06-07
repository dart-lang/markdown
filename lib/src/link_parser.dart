// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'charcode.dart';
import 'extensions.dart';
import 'source_span_parser.dart';

// TODO(Zhiguang): Enhance this LinkParser when working on LinkSyntax.
class LinkParser extends SourceSpanParser {
  LinkParser(List<SourceSpan> source) : super(source);

  List<SourceSpan>? parseLabel() {
    moveThroughWhitespace(multiLine: true);
    if (isDone) {
      return null;
    }

    if (charAt() != $lbracket) {
      return null;
    }

    // Advance past the opening `[`.
    advance();
    final start = position;

    while (true) {
      final char = charAt(position);
      if (char == $backslash) {
        advance();
      } else if (char == $lbracket) {
        return null;
      } else if (char == $rbracket) {
        break;
      }
      advance();
      if (isDone) {
        return null;
      }
    }

    final text = subText(start, position);
    if (text.isEmpty || text.isEmptyContent()) {
      return null;
    }
    text.first.trimLeft();
    text.last.trimLeft();
    // Advance past the closing `]`.
    advance();
    return text;
  }

  List<SourceSpan>? parseDestination() {
    moveThroughWhitespace(multiLine: true);
    if (isDone) {
      return null;
    }

    if (charAt() == $lt) {
      return _parseInlineBracketedLink();
    } else {
      return _parseInlineBareDestinationLink();
    }
  }

  List<SourceSpan>? _parseInlineBracketedLink() {
    advance();
    final start = position;
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == $lf || char == $cr || char == $ff) {
        return null;
      } else if (char == $gt) {
        break;
      }
      advance();
      if (isDone) {
        return null;
      }
    }

    final text = subText(start, position);
    // Advance past the closing `>`.
    advance();
    return text;
  }

  // NOTE: Need to strip the outer () when parsing link [link](target)
  List<SourceSpan>? _parseInlineBareDestinationLink() {
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
        if (parenCount < 0) {
          return null;
        }
      }
      advance();

      // There is no ending delimiter, so `isDone` also means it is at the end
      // of a link destination.
      if (isDone) {
        break;
      }
    }

    if (parenCount != 0) {
      return null;
    }

    return subText(start, position);
  }

  // TODO(Zhiguang): Combine parseDestination and parseTitle into one method.
  List<SourceSpan>? parseTitle(bool hadWhitespace) {
    if (moveThroughWhitespace(multiLine: true) < 1 && !hadWhitespace) {
      return null;
    }

    if (isDone) {
      return null;
    }

    // See: https://spec.commonmark.org/0.30/#link-title
    // The whitespace should be followed by a title delimiter.
    final delimiter = charAt();
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return null;
    }

    final closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    advance();
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
        return null;
      }
    }

    if (isDone) {
      return null;
    }

    final text = subText(start, position);
    // Advance past the closing delimiter.
    advance();
    return text;
  }
}
