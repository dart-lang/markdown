// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_parser.dart';
import 'extension_set.dart';
import 'inline_parser.dart';

/// Maintains the context needed to parse a Markdown document.
class Document {
  final Map<String, LinkReference> linkReferences = <String, LinkReference>{};
  final Resolver? linkResolver;
  final Resolver? imageLinkResolver;
  final bool encodeHtml;

  /// Whether to use default block syntaxes.
  final bool withDefaultBlockSyntaxes;

  /// Whether to use default inline syntaxes.
  ///
  /// Need to set both [withDefaultInlineSyntaxes] and [encodeHtml] to
  /// `false` to disable all inline syntaxes including html encoding syntaxes.
  final bool withDefaultInlineSyntaxes;

  final _blockSyntaxes = <BlockSyntax>{};
  final _inlineSyntaxes = <InlineSyntax>{};
  final bool hasCustomInlineSyntaxes;

  Iterable<BlockSyntax> get blockSyntaxes => _blockSyntaxes;

  Iterable<InlineSyntax> get inlineSyntaxes => _inlineSyntaxes;

  Document({
    Iterable<BlockSyntax>? blockSyntaxes,
    Iterable<InlineSyntax>? inlineSyntaxes,
    ExtensionSet? extensionSet,
    this.linkResolver,
    this.imageLinkResolver,
    this.encodeHtml = true,
    this.withDefaultBlockSyntaxes = true,
    this.withDefaultInlineSyntaxes = true,
  }) : hasCustomInlineSyntaxes = (inlineSyntaxes?.isNotEmpty ?? false) ||
            (extensionSet?.inlineSyntaxes.isNotEmpty ?? false) {
    _blockSyntaxes.addAll(blockSyntaxes ?? []);
    _inlineSyntaxes.addAll(inlineSyntaxes ?? []);

    if (extensionSet == null) {
      if (withDefaultBlockSyntaxes) {
        _blockSyntaxes.addAll(ExtensionSet.commonMark.blockSyntaxes);
      }

      if (withDefaultInlineSyntaxes) {
        _inlineSyntaxes.addAll(ExtensionSet.commonMark.inlineSyntaxes);
      }
    } else {
      _blockSyntaxes.addAll(extensionSet.blockSyntaxes);
      _inlineSyntaxes.addAll(extensionSet.inlineSyntaxes);
    }
  }

  /// Parses the given [lines] of Markdown to a series of AST nodes.
  List<Node> parseLines(List<String> lines) {
    final nodes = BlockParser(lines, this).parseLines();
    _parseInlineContent(nodes);
    return nodes;
  }

  /// Parses the given inline Markdown [text] to a series of AST nodes.
  List<Node> parseInline(String text) => InlineParser(text, this).parse();

  void _parseInlineContent(List<Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is UnparsedContent) {
        final inlineNodes = parseInline(node.textContent);
        nodes.removeAt(i);
        nodes.insertAll(i, inlineNodes);
        i += inlineNodes.length - 1;
      } else if (node is Element && node.children != null) {
        _parseInlineContent(node.children!);
      }
    }
  }
}

/// A [link reference
/// definition](http://spec.commonmark.org/0.28/#link-reference-definitions).
class LinkReference {
  /// The [link label](http://spec.commonmark.org/0.28/#link-label).
  ///
  /// Temporarily, this class is also being used to represent the link data for
  /// an inline link (the destination and title), but this should change before
  /// the package is released.
  final String label;

  /// The [link destination](http://spec.commonmark.org/0.28/#link-destination).
  final String destination;

  /// The [link title](http://spec.commonmark.org/0.28/#link-title).
  final String? title;

  /// Construct a new [LinkReference], with all necessary fields.
  ///
  /// If the parsed link reference definition does not include a title, use
  /// `null` for the [title] parameter.
  LinkReference(this.label, this.destination, this.title);
}
