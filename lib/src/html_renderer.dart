// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library markdown.src.html_renderer;

import 'dart:collection';

import 'ast.dart';
import 'block_parser.dart';
import 'document.dart';
import 'extension_set.dart';
import 'inline_parser.dart';

/// Converts the given string of Markdown to HTML.
String markdownToHtml(String markdown,
    {Iterable<BlockSyntax> blockSyntaxes,
    Iterable<InlineSyntax> inlineSyntaxes,
    ExtensionSet extensionSet,
    Resolver linkResolver,
    Resolver imageLinkResolver,
    bool inlineOnly: false}) {
  var document = new Document(
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      extensionSet: extensionSet,
      linkResolver: linkResolver,
      imageLinkResolver: imageLinkResolver);

  if (inlineOnly) return renderToHtml(document.parseInline(markdown));

  // Replace windows line endings with unix line endings, and split.
  var lines = markdown.replaceAll('\r\n', '\n').split('\n');
  document.parseRefLinks(lines);

  return renderToHtml(document.parseLines(lines)) + '\n';
}

/// Renders [nodes] to HTML.
String renderToHtml(List<Node> nodes) => new HtmlRenderer().render(nodes);

/// Translates a parsed AST to HTML.
class HtmlRenderer implements NodeVisitor {
  static final _blockTags = new RegExp('blockquote|h1|h2|h3|h4|h5|h6|hr|p|pre');

  StringBuffer buffer;
  Set<String> uniqueIds;

  HtmlRenderer();

  String render(List<Node> nodes) {
    buffer = new StringBuffer();
    uniqueIds = new LinkedHashSet<String>();

    for (final node in nodes) node.accept(this);

    return buffer.toString();
  }

  void visitText(Text text) {
    buffer.write(text.text);
  }

  bool visitElementBefore(Element element) {
    // Hackish. Separate block-level elements with newlines.
    if (!buffer.isEmpty && _blockTags.firstMatch(element.tag) != null) {
      buffer.write('\n');
    }

    buffer.write('<${element.tag}');

    // Sort the keys so that we generate stable output.
    var attributeNames = element.attributes.keys.toList();
    attributeNames.sort((a, b) => a.compareTo(b));

    for (var name in attributeNames) {
      buffer.write(' $name="${element.attributes[name]}"');
    }

    // attach header anchor ids generated from text
    if (element.generatedId != null) {
      buffer.write(' id="${uniquifyId(element.generatedId)}"');
    }

    if (element.isEmpty) {
      // Empty element like <hr/>.
      buffer.write(' />');
      return false;
    } else {
      buffer.write('>');
      return true;
    }
  }

  void visitElementAfter(Element element) {
    buffer.write('</${element.tag}>');
  }

  /// Uniquifies an id generated from text.
  String uniquifyId(String id) {
    if (!uniqueIds.contains(id)) {
      uniqueIds.add(id);
      return id;
    }

    int suffix = 2;
    String suffixedId = '$id-$suffix';
    while (uniqueIds.contains(suffixedId)) {
      suffixedId = '$id-${suffix++}';
    }
    uniqueIds.add(suffixedId);
    return suffixedId;
  }
}
