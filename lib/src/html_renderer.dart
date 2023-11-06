// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'ast.dart';
import 'block_syntaxes/block_syntax.dart';
import 'document.dart';
import 'extension_set.dart';
import 'inline_syntaxes/inline_syntax.dart';

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
  bool enableTagfilter = false,
  bool withDefaultBlockSyntaxes = true,
  bool withDefaultInlineSyntaxes = true,
  bool checkable = false,
}) {
  final document = Document(
    blockSyntaxes: blockSyntaxes,
    inlineSyntaxes: inlineSyntaxes,
    extensionSet: extensionSet,
    linkResolver: linkResolver,
    imageLinkResolver: imageLinkResolver,
    encodeHtml: encodeHtml,
    withDefaultBlockSyntaxes: withDefaultBlockSyntaxes,
    withDefaultInlineSyntaxes: withDefaultInlineSyntaxes,
    checkable: checkable,
  );

  if (inlineOnly) return renderToHtml(document.parseInline(markdown));

  final nodes = document.parse(markdown);

  return '${renderToHtml(nodes, enableTagfilter: enableTagfilter)}\n';
}

/// Renders [nodes] to HTML.
String renderToHtml(List<Node> nodes, {bool enableTagfilter = false}) =>
    HtmlRenderer(
      enableTagfilter: enableTagfilter,
    ).render(nodes);

const _blockTags = {
  'blockquote',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'p',
  'pre',
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
},
  _listTags = {
  'li',
  'ol',
  'ul',
};

/// Translates a parsed AST to HTML.
///
/// Unlike [HtmlRenderer], it doesn't generate linefeeds among `ul`, `li`,
/// and `ul` tags. Thus, the caller can apply `white-space: pre-wrap`
/// and similar styles safely.
class CondensedHtmlRenderer implements NodeVisitor {
  late StringBuffer buffer;
  late Set<String> uniqueIds;

  final _elementStack = <Element>[];
  String? _lastVisitedTag;
  final bool _tagfilterEnabled;

  CondensedHtmlRenderer({
    bool enableTagfilter = false,
  }) : _tagfilterEnabled = enableTagfilter;

  String render(List<Node> nodes) {
    buffer = StringBuffer();
    uniqueIds = <String>{};

    for (final node in nodes) {
      node.accept(this);
    }

    return buffer.toString();
  }

  @override
  void visitText(Text text) {
    var content = text.textContent;

    if (_tagfilterEnabled) {
      content = _filterTags(content);
    }
    if (const {'br', 'p', 'li'}.contains(_lastVisitedTag)) {
      final lines = LineSplitter.split(content);
      content = !_trimLeft || content.contains('<pre>')
          ? lines.join('\n')
          : lines.map((line) => line.trimLeft()).join('\n');
      if (text.textContent.endsWith('\n')) {
        content = '$content\n';
      }
    }
    buffer.write(content);

    _lastVisitedTag = null;
  }

  @override
  bool visitElementBefore(Element element) {
    // Hackish. Separate block-level elements with newlines.
    if (buffer.isNotEmpty && _shallBreakBefore(element.tag)) {
      buffer.writeln();
    }

    _writeOpenTagStart(element);
    _lastVisitedTag = element.tag;

    if (element.isEmpty) {
      // Empty element like <hr/>.
      _writeOpenTagEnd(element);
      return false;
    } else {
      _elementStack.add(element);
      _writeOpenTagEnd(element);
      return true;
    }
  }

  /// Whether to trim left if it is contained in `p` or `li`
  bool get _trimLeft => true;

  void _writeOpenTagStart(Element element) {
    buffer.write('<${element.tag}');

    for (final entry in element.attributes.entries) {
      buffer.write(' ${entry.key}="${entry.value}"');
    }

    final generatedId = element.generatedId;

    // attach header anchor ids generated from text
    if (generatedId != null) {
      buffer.write(' id="${uniquifyId(generatedId)}"');
    }
  }

  void _writeOpenTagEnd(Element element) {
    if (element.isEmpty) {
      buffer.write(' />');

      if (element.tag == 'br') {
        buffer.writeln();
      }
    } else {
      buffer.write('>');
    }
  }

  void _writeCloseTag(Element element) {
    buffer.write('</${element.tag}>');
  }

  @override
  void visitElementAfter(Element element) {
    assert(identical(_elementStack.last, element));

    if (element.children != null &&
        element.children!.isNotEmpty &&
        _isBlockTag(_lastVisitedTag) &&
        _isBlockTag(element.tag)) {
      buffer.writeln();
    } else if (element.tag == 'blockquote') {
      buffer.writeln();
    }
    _writeCloseTag(element);

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

  /// Filters some particular tags, see:
  /// https://github.github.com/gfm/#disallowed-raw-html-extension-
  // As said in the specification, this process should happen when rendering
  // HTML output, so there should not be a dedicated syntax for this extension.
  String _filterTags(String content) => content.replaceAll(
      RegExp(
        '<(?=(?:'
        'title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext'
        ')>)',
        caseSensitive: false,
        multiLine: true,
      ),
      '&lt;');

  bool _isBlockTag(String? tag) => _blockTags.contains(tag);
  /// Whether there shall be line-break before rendering [tag]
  /// Default: we don't break between 'li' and other tags.
  bool _shallBreakBefore(String tag)
  => _isBlockTag(tag) && _lastVisitedTag != 'li';
}

/// Translates a parsed AST to HTML.
class HtmlRenderer extends CondensedHtmlRenderer {
  HtmlRenderer({super.enableTagfilter = false});

  @override
  bool _isBlockTag(String? tag)
  => _blockTags.contains(tag) || _listTags.contains(tag);
  @override
  bool _shallBreakBefore(String tag) => _isBlockTag(tag);
}

/// Translates a parsed AST to plain text.
/// It is used to generate a text version of markdown.
///
/// For better, you can use just [EmptyBlockSyntax] and [ParagraphSyntax].
class TextRenderer extends HtmlRenderer {
  @override
  bool get _trimLeft => false; //preserve the spaces
  @override
  void _writeOpenTagStart(Element element) {
    if (_lastVisitedTag == 'p' && buffer.isNotEmpty) buffer.writeln();
  }
  @override
  void _writeOpenTagEnd(Element element) {
  }
  @override
  void _writeCloseTag(Element element) {
  }
}
