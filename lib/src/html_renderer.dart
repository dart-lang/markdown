// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library markdown.html_renderer;

import 'ast.dart';
import 'document.dart';
import 'inline_parser.dart';

/// Converts the given string of markdown to HTML.
String markdownToHtml(String markdown, {List<InlineSyntax> inlineSyntaxes,
  Resolver linkResolver, Resolver imageLinkResolver, bool inlineOnly: false}) {
  var document = new Document(inlineSyntaxes: inlineSyntaxes,
    imageLinkResolver: imageLinkResolver, linkResolver: linkResolver);

  if (inlineOnly) {
    return renderToHtml(document.parseInline(markdown));
  } else {
    // Replace windows line endings with unix line endings, and split.
    var lines = markdown.replaceAll('\r\n','\n').split('\n');
    document.parseRefLinks(lines);
    var blocks = document.parseLines(lines);
    return renderToHtml(blocks);
  }
}

String renderToHtml(List<Node> nodes) => new HtmlRenderer().render(nodes);

/// Translates a parsed AST to HTML.
class HtmlRenderer implements NodeVisitor {
  static final _BLOCK_TAGS = new RegExp(
      'blockquote|h[1-6r]|p(re)?|[ou]l|li');

  static final _SPACE_TAGS = new RegExp(
      '[ou]l');

  static final _VOID_TAGS = new RegExp(
      'img');

  StringBuffer buffer;

  HtmlRenderer();

  String render(List<Node> nodes) {
    buffer = new StringBuffer();

    for (final node in nodes) node.accept(this);

    return buffer.toString();
  }

  void visitText(Text text) {
    buffer.write(text.text);
  }

  bool visitElementBefore(Element element) {
    // TODO: fix this disgraceful hack!
    String bufferString = buffer.toString();
    if (_BLOCK_TAGS.hasMatch(element.tag) && !buffer.isEmpty && !bufferString.endsWith('\n')) {
      buffer.write('\n');
    }
    buffer.write('<${element.tag}');

    // Sort the keys so that we generate stable output.
    // TODO(rnystrom): This assumes keys returns a fresh mutable
    // collection.
    final attributeNames = element.attributes.keys.toList();
    attributeNames.sort((a, b) => a.compareTo(b));
    for (final name in attributeNames) {
      buffer.write(' $name="${element.attributes[name]}"');
    }

    if (element.isEmpty) {
      // Empty element like <hr/>.
      buffer.writeln(' />');
      return false;
    } else {
      buffer.write('>');
      if (_SPACE_TAGS.hasMatch(element.tag))
        buffer.write('\n');

      if (_VOID_TAGS.hasMatch(element.tag))
        return false;

      return true;
    }
  }

  void visitElementAfter(Element element) {
    buffer.write('</${element.tag}>');
    if (_BLOCK_TAGS.hasMatch(element.tag))
      buffer.write('\n');
  }
}
