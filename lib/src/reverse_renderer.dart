// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/extensions.dart';
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

  if (inlineOnly) {
    return renderToMarkdown(
      document.parseInline(markdown),
      encodeHtml: encodeHtml,
    );
  }

  final nodes = document.parseLines(markdown);
  return renderToMarkdown(nodes, encodeHtml: encodeHtml);
}

/// Renders [nodes] to Markdown string.
String renderToMarkdown(
  List<Node> nodes, {
  bool encodeHtml = true,
}) =>
    ReverseRenderer().render(nodes);

/// Translates a parsed AST to Markdown string.
class ReverseRenderer implements NodeVisitor {
  final _SourceSpanBuffer _buffer;
  ReverseRenderer() : _buffer = _SourceSpanBuffer();

  String render(List<Node> nodes) {
    for (final node in nodes) {
      node.accept(this);
    }
    return _buffer.text;
  }

  @override
  void visitText(text) {
    _buffer.write(text);
  }

  @override
  bool visitElementBefore(element) => true;

  @override
  void visitElementAfter(element) {
    element
      ..lineEndings.forEach(_buffer.write)
      ..markers.forEach(_buffer.write);
  }
}

class _SourceSpanBuffer {
  var _buffer = '';

  String get text => _buffer;

  void write(SourceSpan span) {
    final textStart = span.start.offset;
    final textEnd = span.end.offset;
    if (textStart == textEnd) {
      return;
    }

    final overflow = textEnd - _buffer.length;

    if (overflow > 0) {
      _buffer += ' ' * overflow;
    }

    // TODO(Zhiguang): Check if there is duplicated data.
    // final spaces = _buffer.substring(textStart, textEnd);
    // if (!RegExp(r'^ +$').hasMatch(spaces)) {}

    _buffer = _buffer.replaceRange(
      textStart,
      textEnd,
      span.isLineEndingWhitespace ? '\n' : span.text,
    );
  }
}
