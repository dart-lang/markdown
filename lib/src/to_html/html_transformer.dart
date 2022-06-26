// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../extensions.dart';
import 'html_ast.dart';

class HtmlTransformer implements NodeVisitor {
  final bool encodeHtml;

  final List<_TreeElement> _tree = [];
  String? _lastVisitElement;

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
    if (element.type == 'linkReferenceDefinition') {
      return false;
    }

    if (element.type == 'htmlBlock') {
      var text =
          element.children.map((e) => (e as Text).text).join().trimRight();

      // Hackish. In order to strick for example:
      // https://spec.commonmark.org/0.30/#example-167
      // Maybe we should agree to add a special HTML tag `htmlBlock`, so we can
      // achive the same result in HtmlRenderer.
      text = (_lastVisitElement != null ? '\n' : '') + text;
      if (_lastVisitElement == 'listItem') {
        text += '\n';
      }
      _tree.last.children.add(HtmlText(text));
      return false;
    } else if (element.type == 'rawHtml') {
      _tree.last.children.add(
        HtmlText(element.children.map((e) => (e as Text).text).join()),
      );
      return false;
    } else if (element.type == 'backslashEscape') {
      final text = (element.children.first as Text);
      _tree.last.children.add(
        HtmlText(!encodeHtml ? text.textContent : text.htmlText()),
      );
      return false;
    } else if (element.type == 'emoji') {
      _tree.last.children.add(HtmlText(element.attributes['emoji']!));
      return false;
    }

    _lastVisitElement = element.type;
    _tree.add(_TreeElement(element));
    return true;
  }

  @override
  void visitElementAfter(Element element) {
    final current = _tree.removeLast();
    final type = element.type;
    final attributes = element.attributes;

    HtmlElement node;

    if (_isCodeBlock(type)) {
      final code = HtmlElement('code', current.children);

      if (type == 'fencedCodeBlock' && attributes['infoString'] != null) {
        var infoString = attributes['infoString']!;
        if (encodeHtml) {
          infoString = infoString.toHtmlText();
        }
        code.attributes['class'] = 'language-$infoString';
      }

      node = HtmlElement('pre', [code]);
    } else {
      String tag = _htmlTagMap[type] ?? type;
      final isHeading = _isHeading(type);

      if (isHeading) {
        tag = 'h${attributes['level']}';
      }

      if (_isSelfClosing(element)) {
        node = HtmlElement.empty(tag);

        if (type == 'image') {
          node.attributes.addAll({
            'src': attributes['destination']!,
            if (attributes['description'] != null)
              'alt': attributes['description']!,
            if (attributes['title'] != null) 'title': attributes['title']!,
          });
        }
      } else {
        node = HtmlElement(tag, current.children);

        if (isHeading) {
          node.generatedId = attributes['generatedId'];
        } else if (type == 'orderedList' && attributes['start'] != null) {
          node.attributes['start'] = attributes['start']!;
        } else if (type == 'tableHeadCell' || type == 'tableBodyCell') {
          if (attributes['exception'] == 'exceeded') {
            return;
          }
          if (attributes['textAlign'] != null) {
            node.attributes['align'] = attributes['textAlign']!;
          }
        } else if (_isLink(type)) {
          node.attributes.addAll({
            if (attributes['destination'] != null)
              'href': attributes['destination']!,
            if (attributes['title'] != null) 'title': attributes['title']!,
          });

          if (attributes['text'] != null) {
            node.children!
              ..clear()
              ..add(HtmlText(attributes['text']!));
          }
        }
      }
    }

    _lastVisitElement = type;
    _tree.last.children.add(node);
  }

  @override
  void visitText(Text text) {
    final parent = _tree.last;
    final parentType = parent.element?.type;
    final decodeHtmlCharacter =
        parentType != 'codeSpan' && parentType != 'indentedCodeBlock';

    final content = !encodeHtml
        ? text.textContent
        : text.htmlText(decodeHtmlCharacter: decodeHtmlCharacter);

    if (text is! UnparsedContent) {
      parent.children.add(HtmlText(content));
    }

    _lastVisitElement = null;
  }

  bool _isSelfClosing(Element element) =>
      [
        'image',
        'thematicBreak',
        'hardLineBreak',
      ].contains(element.type) &&
      element.children.isEmpty;

  bool _isCodeBlock(String type) =>
      type == 'indentedCodeBlock' || type == 'fencedCodeBlock';

  bool _isLink(String type) =>
      ['link', 'autolink', 'extendedAutolink'].contains(type);

  bool _isHeading(String type) =>
      type == 'atxHeading' || type == 'setextHeading';
}

class _TreeElement {
  final Element? element;
  final children = <HtmlNode>[];

  _TreeElement([this.element]);
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
