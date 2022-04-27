// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_syntaxes/block_syntax.dart';
import 'document.dart';
import 'extension_set.dart';
import 'inline_syntaxes/inline_syntax.dart';
import 'util.dart';

/// Converts the given string to AST and render AST to given string itself
String markdownToMarkdown(
  String markdown, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
  bool withDefaultBlockSyntaxes = true,
  bool withDefaultInlineSyntaxes = true,
}) {
  final document = Document(
    blockSyntaxes: blockSyntaxes,
    inlineSyntaxes: inlineSyntaxes,
    extensionSet: extensionSet,
    linkResolver: linkResolver,
    imageLinkResolver: imageLinkResolver,
    encodeHtml: false,
    withDefaultBlockSyntaxes: withDefaultBlockSyntaxes,
    withDefaultInlineSyntaxes: withDefaultInlineSyntaxes,
  );

  if (inlineOnly) return renderToMarkdown(document.parseInline(markdown));

  final lines = splitLines(markdown);
  return renderToMarkdown(document.parseLines(lines));
}

/// Renders [nodes] to Markdown string.
String renderToMarkdown(List<Node> nodes) => ReverseRenderer().render(nodes);

/// Translates a parsed AST to Markdown string.
class ReverseRenderer implements NodeVisitor {
  ReverseRenderer() : buffer = StringBuffer();

  final StringBuffer buffer;

  String render(List<Node> nodes) {
    for (final node in nodes) {
      node.accept(this);
    }
    return buffer.toString();
  }

  @override
  void visitText(text) {
    buffer.write(text.text);
  }

  @override
  void visitHelper(helper) {
    buffer.write(helper.textContent);
  }

  @override
  bool visitElementBefore(element) => true;

  @override
  void visitElementAfter(element) {}
}
