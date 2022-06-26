// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/patterns.dart';
import 'package:source_span/source_span.dart';

/// Converts the given string to AST and renders AST to given string itself.
String markdownToMarkdown(
  String markdown, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
  bool encodeHtml = true,
  bool withDefaultBlockSyntaxes = true,
  bool withDefaultInlineSyntaxes = true,
}) {
  final document = Document(
    blockSyntaxes: blockSyntaxes,
    inlineSyntaxes: inlineSyntaxes,
    extensionSet: extensionSet,
    linkResolver: linkResolver,
    imageLinkResolver: imageLinkResolver,
    withDefaultBlockSyntaxes: withDefaultBlockSyntaxes,
    withDefaultInlineSyntaxes: withDefaultInlineSyntaxes,
  );

  final nodes = inlineOnly
      ? document.parseInline(markdown)
      : document.parseLines(markdown);

  return ReverseRenderer(markdown).render(nodes);
}

class ReverseRenderer implements NodeVisitor {
  String _markdown;

  ReverseRenderer(String markdown)
      : _markdown =
            markdown.replaceAll(RegExp('[^$whitespaceCharacters]'), ' ');

  String render(List<Node> nodes) {
    for (final node in nodes) {
      node.accept(this);
    }
    return _markdown;
  }

  @override
  void visitText(text) {
    _write(text);
  }

  @override
  bool visitElementBefore(element) => true;

  @override
  void visitElementAfter(element) {
    element.markers.forEach(_write);
  }

  void _write(SourceSpan span) {
    _markdown = _markdown.replaceRange(
      span.start.offset,
      span.end.offset,
      span.text,
    );
  }
}
