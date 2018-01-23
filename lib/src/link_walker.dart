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
    var leftParenIndex = parser.pos;
    parser.advanceBy(1);
    int char;
    int destinationStart;
    String destination;
    String title;

    // Loop past the opening whitespace.
    while (true) {
      char = parser.charAt(parser.pos);
      if (char != $space && char != $lf && char != $cr && char != $ff) {
        break;
      }
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
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
      destinationStart = parser.pos + 1;
      loop:
      while (true) {
        parser.advanceBy(1);
        if (parser.isDone) return null; // EOF. Not a link.
        char = parser.charAt(parser.pos);
        switch (char) {
          case $backslash:
            parser.advanceBy(1);
            break;
          case $gt:
            destination =
                parser.source.substring(destinationStart, parser.pos);
            parser.advanceBy(1);
            break loop;
          case $space:
          case $lf:
          case $cr:
          case $ff:
            destination =
                parser.source.substring(destinationStart - 1, parser.pos);
            title = _parseTitle(parser);
            if (title == null) {
              // This looked like an inline link, until we found this $space
              // followed by mystery characters; no longer a link.
              parser.pos = leftParenIndex;
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
              destination ??=
                  parser.source.substring(destinationStart - 1, parser.pos);
              break loop;
            } else {
              // Keep going. The parens must be balanced.
            }
        }
      }
    } else {
      destinationStart = parser.pos;
      // The first character was not `<`, so let's back up one and start
      // walking.
      parser.advanceBy(-1);
      loop:
      while (true) {
        parser.advanceBy(1);
        if (parser.isDone) return null; // EOF. Not a link.
        char = parser.charAt(parser.pos);
        switch (char) {
          case $backslash:
            // We do not care about the next character.
            parser.advanceBy(1);
            break;
          case $space:
          case $lf:
          case $cr:
          case $ff:
            destination =
                parser.source.substring(destinationStart, parser.pos);
            title = _parseTitle(parser);
            if (title == null) {
              // This looked like an inline link, until we found this $space
              // followed by mystery characters; no longer a link.
              parser.pos = leftParenIndex;
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
              destination ??=
                  parser.source.substring(destinationStart, parser.pos);
              break loop;
            } else {
              // Keep going. The parens must be balanced.
            }
        }
      }
    }
    return new LinkLike.inline(destination, title);
  }

  /// Parse a reference link at the current position.
  ///
  /// Specifically, [parser.pos] is expected to be pointing at the `]` which
  /// closed the link text.
  ///
  /// Returns the [LinkLike] if it could be parsed, or `null` if not.
  LinkLike parseReferenceLink() {
    // The current character points to the character points to the `[` which
    // opens the link label. Walk past it.
    parser.advanceBy(1);
    if (parser.isDone) return null;

    var labelStart = parser.pos;
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == $backslash) {
        // We don't care about the next character.
        parser.advanceBy(1);
      } else if (char == $rbracket) {
        break;
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
      // TODO(srawlins): only check 999 characters, for performance reasons?
    }

    var label = parser.source.substring(labelStart, parser.pos).toLowerCase();
    return new LinkLike.reference(label);
  }

  // Parse a link title at [parser] position [i]. [i] must be the position at
  // the first space after the link destination (which triggered the idea
  // that we might have a title).
  String _parseTitle(InlineParser parser) {
    int char;
    int delimiter;
    String title;

    // Walk over leading space, looking for a delimiter.
    while (true) {
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
      char = parser.charAt(parser.pos);
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
    var titleStart = parser.pos + 1;
    var closeDelimiter = delimiter == $lparen ? $rparen : delimiter;

    // Now we look for an un-escaped close delimiter.
    while (true) {
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
      char = parser.charAt(parser.pos);
      if (char == $backslash) {
        // Escape the next character.
        parser.advanceBy(1);
        continue;
      }
      if (char == closeDelimiter) {
        title = parser.source.substring(titleStart, parser.pos);
        break;
      }
    }

    // Parse optional whitespace before the required `)`.
    while (true) {
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
      char = parser.charAt(parser.pos);
      switch (char) {
        case $space:
        case $lf:
        case $cr:
        case $ff:
          // Just padding. Move along.
          break;
        case $rparen:
          // Back up to before the `)`; let [parseInlineLink] catch it.
          parser.advanceBy(-1);
          return title;
        default:
          // Not a title!
          return null;
      }
    }
  }
}
