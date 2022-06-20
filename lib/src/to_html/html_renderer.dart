// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import '../ast.dart';
import '../block_syntaxes/block_syntax.dart';
import '../document.dart';
import '../extension_set.dart';
import '../inline_syntaxes/inline_syntax.dart';
import 'html_ast.dart';
import 'html_transformer.dart';

/// Converts the given string of Markdown to HTML.
String markdownToHtml(
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
    return renderToHtml(
      document.parseInline(markdown),
      encodeHtml: encodeHtml,
    );
  }

  final nodes = document.parseLines(markdown);

  return renderToHtml(nodes, encodeHtml: encodeHtml);
}

/// Renders [nodes] to HTML.
String renderToHtml(
  List<Node> nodes, {
  bool encodeHtml = true,
}) {
  final htmlNodes = HtmlTransformer(encodeHtml: encodeHtml).transform(nodes);
  return HtmlRenderer().render(htmlNodes);
}

const _blockTags = [
  'blockquote',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'li',
  'ol',
  'p',
  'pre',
  'ul',
  'address',
  'article',
  'aside',
  'details',
  'dd',
  'div',
  'dl',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'header',
  'hgroup',
  'main',
  'nav',
  'section',
  'table',
  'thead',
  'tbody',
  'th',
  'tr',
  'td',
];

/// Translates a parsed AST to HTML.
class HtmlRenderer implements HtmlNodeVisitor {
  late StringBuffer buffer;
  late Set<String> uniqueIds;

  final _elementStack = <HtmlElement>[];
  String? _lastVisitedTag;

  HtmlRenderer();

  String render(List<HtmlNode> nodes) {
    buffer = StringBuffer();
    uniqueIds = <String>{};

    for (final node in nodes) {
      node.accept(this);
    }

    return buffer.toString();
  }

  @override
  void visitText(HtmlText text) {
    var content = text.text;
    if (const ['br', 'p', 'li'].contains(_lastVisitedTag)) {
      final lines = LineSplitter.split(content);
      content = content.contains('<pre>') ? lines.join('\n') : lines.join('\n');
      if (text.text.endsWith('\n')) {
        content = '$content\n';
      }
    }

    // See https://spec.commonmark.org/0.30/#example-300
    if (_elementStack.isNotEmpty &&
        _elementStack.last.tag == 'li' &&
        ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(_lastVisitedTag)) {
      buffer.writeln();
    }
    buffer.write(content);

    _lastVisitedTag = null;
  }

  @override
  bool visitElementBefore(HtmlElement element) {
    // Hackish. Separate block-level elements with newlines.
    if (buffer.isNotEmpty && _blockTags.contains(element.tag)) {
      buffer.writeln();
    }

    buffer.write('<${element.tag}');

    for (final entry in element.attributes.entries) {
      buffer.write(' ${entry.key}="${entry.value}"');
    }

    final generatedId = element.generatedId;

    // attach header anchor ids generated from text
    if (generatedId != null) {
      buffer.write(' id="${uniquifyId(generatedId)}"');
    }

    _lastVisitedTag = element.tag;

    if (element.isEmpty) {
      // Empty element like <hr/>.
      buffer.write(' />');

      if (element.tag == 'br') {
        buffer.write('\n');
      }

      return false;
    } else {
      _elementStack.add(element);
      buffer.write('>');
      return true;
    }
  }

  @override
  void visitElementAfter(HtmlElement element) {
    assert(identical(_elementStack.last, element));

    if (element.children != null &&
        element.children!.isNotEmpty &&
        _blockTags.contains(_lastVisitedTag) &&
        _blockTags.contains(element.tag)) {
      buffer.writeln();
    } else if (element.tag == 'blockquote') {
      buffer.writeln();
    }
    buffer.write('</${element.tag}>');

    _lastVisitedTag = _elementStack.removeLast().tag;
  }

  /// Uniquifies an id generated from text.
  String uniquifyId(String id) {
    if (!uniqueIds.contains(id)) {
      uniqueIds.add(id);
      return id;
    }

    var suffix = 2;
    var suffixedId = '$id-$suffix';
    while (uniqueIds.contains(suffixedId)) {
      suffixedId = '$id-${suffix++}';
    }
    uniqueIds.add(suffixedId);
    return suffixedId;
  }
}
