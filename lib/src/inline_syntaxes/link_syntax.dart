// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(Zhiguang): Optimise link syntaxs and the link parser.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../charcode.dart';
import '../document.dart';
import '../parsers/inline_parser.dart';
import '../parsers/link_parser.dart';
import '../util.dart';
import 'delimiter_syntax.dart';

/// Matches links like `[blah][label]` and `[blah](url)`.
class LinkSyntax extends DelimiterSyntax {
  final Resolver linkResolver;

  LinkSyntax({
    Resolver? linkResolver,
    String pattern = r'\[',
    int startCharacter = $lbracket,
  })  : linkResolver = (linkResolver ?? ((String _, [String? __]) => null)),
        super(pattern, startCharacter: startCharacter);

  @override
  Node? close(
    InlineParser parser,
    int startPosition, {
    required SourceSpan openMarker,
    required SourceSpan closeMarker,
    String? type,
    required List<Node> Function() getChildren,
  }) {
    // The content between openMarker and closeMarker.
    final plainTextChildren = parser.subspan(
      startPosition + openMarker.length,
      parser.position,
    );

    final markers = [openMarker, closeMarker];

    // There are three kinds of reference links: full, collapsed, and shortcut.
    // 1. Full reference link: [text][label], see
    //    https://spec.commonmark.org/0.30/#full-reference-link.
    // 2. Collapsed reference link: [label][], equals to label][label], see
    //    https://spec.commonmark.org/0.30/#collapsed-reference-link.
    // 3. Shortcut reference link: [label], equals to [label][], see
    //    https://spec.commonmark.org/0.30/#shortcut-reference-link.
    var label = plainTextChildren.map((e) => e.text).join();

    // Walk past the closing `]`.
    parser.advance();

    final parserStart = parser.position;

    // Tries to create a reference link node.
    // Returns the link if it was successfully created, `null` otherwise.
    Node? _tryCreateReferenceLink() {
      final link = _resolveReferenceLink(
        label,
        parser.document.linkReferences,
        getChildren: getChildren,
        markers: markers,
        plainTextChildren: plainTextChildren,
      );

      if (link == null) {
        // Retreat the position.
        parser.advanceBy(parserStart - parser.position);
      }
      return link;
    }

    // The `]` is at the end of the document, this may be a valid shortcut
    // reference link.
    if (parser.isDone) {
      return _tryCreateReferenceLink();
    }

    final char = parser.charAt();

    if (char == $lparen) {
      // Maybe an inline link, like `[text](destination)`.
      final spans = parser.subspan(parser.position, parser.length);
      final linkParser = LinkParser(spans)..parseInlineLink();

      if (linkParser.valid) {
        parser.advanceBy(linkParser.position + 1);

        markers.addAll(linkParser.markers);
        return createNode(
          linkParser.formatted.destination,
          linkParser.formatted.title,
          markers: markers,
          plainTextChildren: plainTextChildren,
          getChildren: getChildren,
        );
      }

      // At this point, we've matched `[...](`, but that `(` did not pan out to
      // be an inline link. We must now check if `[...]` is simply a shortcut
      // reference link.

      return _tryCreateReferenceLink();
    }

    // At this point, we've matched `[...][`. Maybe a *full* reference link,
    // like `[text][label]` or a *collapsed* reference link, like `[label][]`.
    if (char == $lbracket) {
      // Maybe a *shortcut* reference link like [label][].
      if (parser.nextChar() == $rbracket) {
        // Add `[` to markers;
        markers.add(parser.spanAt());
        parser.advance();

        // Add `]` to markers;
        markers.add(parser.spanAt());
        parser.advance();
        return _tryCreateReferenceLink();
      }

      // Maybe a *full* reference link, like [text][label].
      final linkParser = LinkParser(parser.subspan(parser.position));
      if (linkParser.parseLabel()) {
        parser.advanceBy(linkParser.position);
        markers
          ..addAll(linkParser.markers)
          ..insertAll(markers.length - 1, linkParser.label);

        label = linkParser.label.map((e) => e.text).join();
        return _tryCreateReferenceLink();
      }

      return null;
    }

    // The link text (inside `[...]`) was not followed with a opening `(` nor
    // an opening `[`. Perhaps just a simple shortcut reference link (`[...]`).
    final node = _tryCreateReferenceLink();
    if (node != null) {
      // As with full reference links, spaces, tabs, or line endings are not
      // allowed between the two sets of brackets, see
      // https://spec.commonmark.org/0.30/#example-555.
      //
      // A space after the link text should be preserved, see
      // https://spec.commonmark.org/0.30/#example-561.
      final spaces = parser.moveThroughWhitespace();
      if (parser.charAt() != $lf) {
        parser.advanceBy(-spaces);
      }
    }
    return node;
  }

  /// Resolve a possible reference link.
  ///
  /// Uses [linkReferences], [linkResolver], and [createNode] to try to
  /// resolve [label] into a [Node]. If [label] is defined in
  /// [linkReferences] or can be resolved by [linkResolver], returns a [Node]
  /// that links to the resolved URL.
  ///
  /// Otherwise, returns `null`.
  ///
  /// [label] does not need to be normalized.
  Node? _resolveReferenceLink(
    String label,
    Map<String, LinkReference> linkReferences, {
    required List<SourceSpan> markers,
    required List<Node> Function() getChildren,
    required List<SourceSpan> plainTextChildren,
  }) {
    final linkReference = linkReferences[normalizeLinkLabel(label)];
    if (linkReference != null) {
      return createNode(
        linkReference.destination,
        linkReference.title,
        getChildren: getChildren,
        plainTextChildren: plainTextChildren,
        markers: markers,
      );
    } else {
      // This link has no reference definition. But we allow users of the
      // library to specify a custom resolver function ([linkResolver]) that
      // may choose to handle this. Otherwise, it's just treated as plain
      // text.

      // Normally, label text does not get parsed as inline Markdown. However,
      // for the benefit of the link resolver, we need to at least escape
      // brackets, so that, e.g. a link resolver can receive `[\[\]]` as `[]`.

      // TODO(Zhiguang): escape helper?
      final resolved = linkResolver(label
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\[', '[')
          .replaceAll(r'\]', ']'));
      if (resolved != null) {
        getChildren();
      }
      return resolved;
    }
  }

  /// Create the node represented by a Markdown link.
  Node createNode(
    String destination,
    String? title, {
    required List<SourceSpan> markers,
    required List<Node> Function() getChildren,
    required List<SourceSpan> plainTextChildren,
  }) {
    final children = getChildren();
    final attributes = {
      'destination': destination,
    };

    if (title != null && title.isNotEmpty) {
      attributes['title'] = title;
    }

    return Element(
      'link',
      children: children,
      attributes: attributes,
      markers: markers,
    );
  }
}
