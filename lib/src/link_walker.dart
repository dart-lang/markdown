// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:charcode/charcode.dart';

import 'inline_parser.dart';
import 'link_like.dart';

/// A helper class for parsing the destination/label/title part of a possible
/// link.
///
/// Link destinations and labels are tricky to parse; the parsing can benefit
/// from keeping some state in an object. This class helps to "parse" a link
/// (after the link text's closing `]` has been parsed). It is called a 'walker'
/// because it contains a reference to the InlineParser which is known
/// throughout this file as the `parser`. Synonymous.
class LinkWalker {
  final InlineParser parser;

  String _destination;
  String _title;

  LinkWalker(this.parser);

  /// Parse an inline [LinkLike] at the current position.
  ///
  /// At this point, we have parsed a link's (or image's) opening `[`, and then
  /// a matching closing `]`, and [parser.pos] is pointing at an opening `(`.
  /// This method will then attempt to parse a link destination wrapped in `<>`,
  /// such as `(<http://url>)`, or a bare link destination, such as
  /// `(http://url)`, or a link destination with a title, such as
  /// `(http://url "title")`.
  ///
  /// Returns the [LinkLike] if one was parsed, or `null` if not.
  LinkLike parseInlineLink() {
    // Start walking at the character just after the opening `(`.
    var sourceIndex = parser.pos + 1;
    var char = parser.charAt(sourceIndex);
    int destinationStart;

    // Loop past the opening whitespace.
    while (true) {
      sourceIndex++;
      if (sourceIndex == parser.source.length) return null; // EOF. Not a link.
      char = parser.charAt(sourceIndex);
      if (char != $space && char != $lf && char != $cr && char != $ff) {
        break;
      }
    }

    // According to
    // [CommonMark](http://spec.commonmark.org/0.28/#link-destination):
    //
    // > A link destination consists of [...] a nonempty sequence of
    // > characters [...], and includes parentheses only if (a) they are
    // > backslash-escaped or (b) they are part of a balanced pair of
    // > unescaped parentheses.
    //
    // We need to count the open parens. We start with 1 for the paren that
    // opened the destination.
    var parenCount = 1;

    if (char == $lt) {
      // Maybe a `<...>`-enclosed link destination.
      destinationStart = sourceIndex + 1;
      loop:
      while (true) {
        sourceIndex++;
        if (sourceIndex == parser.source.length)
          return null; // EOF. Not a link.
        char = parser.charAt(sourceIndex);
        switch (char) {
          case $backslash:
            sourceIndex++;
            break;
          case $gt:
            _destination =
                parser.source.substring(destinationStart, sourceIndex);
            sourceIndex++;
            break loop;
          case $space:
          case $lf:
          case $cr:
          case $ff:
            _destination =
                parser.source.substring(destinationStart - 1, sourceIndex);
            sourceIndex = _parseTitle(sourceIndex);
            if (sourceIndex == null) {
              // This looked like an inline link, until we found this $space
              // followed by mystery characters; no longer a link.
              return null;
            }
            break;
          case $lparen:
            parenCount++;
            break;
          case $rparen:
            parenCount--;
            if (parenCount == 0) {
              // End of link.
              _destination ??=
                  parser.source.substring(destinationStart - 1, sourceIndex);
              break loop;
            } else {
              // Keep going. The parens must be balanced.
            }
        }
      }
    } else {
      destinationStart = sourceIndex;
      // The first character was not `<`, so let's back up one and start
      // walking.
      sourceIndex--;
      loop:
      while (true) {
        sourceIndex++;
        if (sourceIndex == parser.source.length)
          return null; // EOF. Not a link.
        char = parser.charAt(sourceIndex);
        switch (char) {
          case $backslash:
            // We do not care about the next character.
            sourceIndex++;
            break;
          case $space:
          case $lf:
          case $cr:
          case $ff:
            _destination =
                parser.source.substring(destinationStart, sourceIndex);
            sourceIndex = _parseTitle(sourceIndex);
            if (sourceIndex == null) {
              // This looked like an inline link, until we found this $space
              // followed by mystery characters; no longer a link.
              return null;
            }
            break;
          case $lparen:
            parenCount++;
            break;
          case $rparen:
            parenCount--;
            if (parenCount == 0) {
              // End of link.
              _destination ??=
                  parser.source.substring(destinationStart, sourceIndex);
              break loop;
            } else {
              // Keep going. The parens must be balanced.
            }
        }
      }
    }
    return new LinkLike(
        destination: _destination, title: _title, endPos: sourceIndex);
  }

  /// Parse a reference link at the current position.
  ///
  /// Specifically, [parser.pos] is expected to be pointing at the opening `[`.
  ///
  /// Returns the [LinkLike] if it could be parsed, or `null` if not.
  LinkLike parseReferenceLink() {
    // Walk past the `[` to the next character.
    var sourceIndex = parser.pos + 2;
    if (sourceIndex >= parser.source.length) {
      return null;
    }
    var char = parser.charAt(sourceIndex);

    var labelIndex = sourceIndex;
    while (true) {
      sourceIndex++;
      if (sourceIndex >= parser.source.length) {
        return null;
      }
      char = parser.charAt(sourceIndex);
      if (char == $backslash) {
        // We don't care about the next character.
        sourceIndex++;
      } else if (char == $rbracket) {
        break;
      }
      // TODO(srawlins): only check 999 characters, for performance reasons?
    }

    var label = parser.source.substring(labelIndex, sourceIndex).toLowerCase();
    return new LinkLike(label: label, endPos: sourceIndex);
  }

  // Parse a link title at [parser] position [i]. [i] must be the position at
  // the first space after the link destination (which triggered the idea
  // that we might have a title).
  int _parseTitle(int i) {
    int char;
    int delimiter;

    // Walk over leading space, looking for a delimiter.
    while (true) {
      i++;
      if (i == parser.source.length) {
        // EOF. Not a link.
        return null;
      }
      char = parser.charAt(i);
      switch (char) {
        case $space:
        case $lf:
        case $cr:
        case $ff:
          // Just padding. Move along.
          continue;
        case $apostrophe:
        case $quote:
        case $lparen:
          delimiter = char;
          break;
        default:
          // Not a title!
          return null;
      }
      break;
    }
    var titleStart = i + 1;
    var closeDelimiter = delimiter == $lparen ? $rparen : delimiter;

    // Now we look for an un-escaped close delimiter.
    while (true) {
      i++;
      if (i >= parser.source.length) {
        // EOF. Not a link.
        return null;
      }
      char = parser.charAt(i);
      if (char == $backslash) {
        // Ignore the next character.
        i++;
        continue;
      }
      if (char == closeDelimiter) {
        _title = parser.source.substring(titleStart, i);
        break;
      }
    }

    // Parse optional whitespace before the required `)`.
    while (true) {
      i++;
      if (i == parser.source.length) {
        // EOF. Not a link.
        return null;
      }
      char = parser.charAt(i);
      switch (char) {
        case $space:
        case $lf:
        case $cr:
        case $ff:
          // Just padding. Move along.
          break;
        case $rparen:
          // Back up to before the `)`.
          i--;
          return i;
        default:
          // Not a title!
          return null;
      }
    }
  }
}
