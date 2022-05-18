// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../util.dart';
import 'html_ast.dart';

class HtmlTransformer implements NodeVisitor {
  final bool encodeHtml;

  final List<_TreeElement> _tree = [];

  HtmlTransformer({
    this.encodeHtml = false,
  });

  List<HtmlNode> transform(List<Node> nodes) {
    _tree
      ..clear()
      ..add(_TreeElement());

    for (final node in nodes) {
      assert(_tree.length == 1);
      node.accept(this);
    }

    return _tree.single.children;
  }

  @override
  bool visitElementBefore(Element element) {
    _tree.add(_TreeElement(element.type));

    return true;
  }

  @override
  void visitElementAfter(Element element) {
    final current = _tree.removeLast();
    final type = element.type;
    final attributes = element.attributes;

    HtmlElement node;

    if (type == 'indentedCodeBlock' || type == 'fencedCodeBlock') {
      final code = HtmlElement('code', current.children);

      if (type == 'fencedCodeBlock' && attributes['infoString'] != null) {
        code.attributes['class'] = 'language-${attributes['infoString']}';
      }

      node = HtmlElement('pre', [code]);
    } else {
      String tag = _htmlTagMap[type] ?? type;

      if (type == 'atxHeading' || type == 'setextHeading') {
        tag = 'h${attributes['level']}';
      }

      if (_isSelfClosing(element)) {
        node = HtmlElement.empty(tag);

        if (type == 'image') {
          _updateLinkAttributes(node, element);
        }
      } else {
        node = HtmlElement(tag, current.children);

        if (type == 'atxHeading' || type == 'setextHeading') {
          node.generatedId = attributes['generatedId'];
        } else if (type == 'orderedList' && attributes['start'] != null) {
          node.attributes['start'] = attributes['start']!;
        } else if ((type == 'tableHeadCell' || type == 'tableBodyCell') &&
            attributes['textAlign'] != null) {
          node.attributes['style'] = 'text-align: ${attributes['textAlign']};';
        } else if (type == 'link') {
          _updateLinkAttributes(node, element);
        } else if ([
          'autolink',
          "emailAutolink",
          'extendedAutolink',
        ].contains(type)) {
          final href = type == 'emailAutolink'
              ? 'mailto:${attributes['emailAddress']}'
              : attributes['uri'];

          if (href != null) {
            node.attributes['href'] = Uri.encodeFull(href);
          }
        }
      }
    }

    _tree.last.children.add(node);
  }

  @override
  void visitText(Text text) {
    final parent = _tree.last;

    String content = text.text;
    if (parent.name == 'codeSpan') {
      content = content.trim().replaceAll('\n', ' ');
      if (encodeHtml) {
        content = escapeHtml(content);
      }
    }

    if (text is! UnparsedContent) {
      parent.children.add(HtmlText(content));
    }
  }

  bool _isSelfClosing(Element element) =>
      [
        'image',
        'thematicBreak',
        'hardLineBreak',
        'tableBodyCell',
      ].contains(element.type) &&
      element.children.isEmpty;

  void _updateLinkAttributes(HtmlElement node, Element element) {
    final isImage = element.type == 'image';
    final attributes = element.attributes;

    if (attributes['uri'] != null) {
      node.attributes[isImage ? 'src' : 'href'] =
          escapeAttribute(attributes['uri']!);
    }

    if (isImage && attributes['description'] != null) {
      node.attributes['alt'] = attributes['description']!;
    }

    if (attributes['title'] != null) {
      node.attributes['title'] = escapeAttribute(attributes['title']!);
    }
  }
}

class _TreeElement {
  final String? name;
  final children = <HtmlNode>[];

  _TreeElement([this.name]);
}

const _htmlTagMap = {
  'paragraph': 'p',
  'orderedList': 'ol',
  'bulletList': 'ul',
  'listItem': 'li',
  'thematicBreak': 'hr',
  'fencedBlockquote': 'blockquote',
  'tableRow': 'tr',
  'tableHead': 'thead',
  'tableBody': 'tbody',
  'tableHeadCell': 'th',
  'tableBodyCell': 'td',
  'codeSpan': 'code',
  'autolink': 'a',
  'emailAutolink': 'a',
  'extendedAutolink': 'a',
  'hardLineBreak': 'br',
  'emphasis': 'em',
  'strongEmphasis': 'strong',
  'strikethrough': 'del',
  'link': 'a',
  'image': 'img',
};
