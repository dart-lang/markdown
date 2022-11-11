// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_syntaxes/block_syntax.dart';
import 'block_syntaxes/blockquote_syntax.dart';
import 'block_syntaxes/code_block_syntax.dart';
import 'block_syntaxes/fenced_blockquote_syntax.dart';
import 'block_syntaxes/fenced_code_block_syntax.dart';
import 'block_syntaxes/header_syntax.dart';
import 'block_syntaxes/header_with_id_syntax.dart';
import 'block_syntaxes/horizontal_rule_syntax.dart';
import 'block_syntaxes/html_block_syntax.dart';
import 'block_syntaxes/ordered_list_syntax.dart';
import 'block_syntaxes/ordered_list_with_checkbox_syntax.dart';
import 'block_syntaxes/paragraph_syntax.dart';
import 'block_syntaxes/setext_header_syntax.dart';
import 'block_syntaxes/setext_header_with_id_syntax.dart';
import 'block_syntaxes/table_syntax.dart';
import 'block_syntaxes/unordered_list_syntax.dart';
import 'block_syntaxes/unordered_list_with_checkbox_syntax.dart';
import 'charcode.dart';
import 'document.dart';
import 'inline_syntaxes/autolink_extension_syntax.dart';
import 'inline_syntaxes/autolink_syntax.dart';
import 'inline_syntaxes/code_syntax.dart';
import 'inline_syntaxes/color_swatch_syntax.dart';
import 'inline_syntaxes/emoji_syntax.dart';
import 'inline_syntaxes/emphasis_syntax.dart';
import 'inline_syntaxes/escape_html_syntax.dart';
import 'inline_syntaxes/escape_syntax.dart';
import 'inline_syntaxes/image_syntax.dart';
import 'inline_syntaxes/inline_html_syntax.dart';
import 'inline_syntaxes/inline_syntax.dart';
import 'inline_syntaxes/line_break_syntax.dart';
import 'inline_syntaxes/link_syntax.dart';
import 'inline_syntaxes/soft_line_break_syntax.dart';
import 'inline_syntaxes/strikethrough_syntax.dart';
import 'inline_syntaxes/text_syntax.dart';
import 'parsers/block_parser.dart';
import 'parsers/inline_parser.dart';
import 'syntax.dart';

class Markdown {
  final _blockSyntaxes = <BlockSyntax>{};
  final _inlineSyntaxes = <InlineSyntax>{};
  final bool hasCustomInlineSyntaxes;
  final bool escapeHtml;

  Iterable<BlockSyntax> get blockSyntaxes => _blockSyntaxes;
  Iterable<InlineSyntax> get inlineSyntaxes => _inlineSyntaxes;

  final linkReferences = <String, LinkReference>{};

  Markdown({
    bool enableAtxHeading = true,
    bool enableHeadingId = false,
    bool enableBlockquote = true,
    bool enableIndentedCodeBlock = true,
    bool enableFencedBlockquote = false,
    bool enableFencedCodeBlock = true,
    bool enableList = true,
    bool enableSetextHeading = true,
    bool enableTable = false,
    bool enableHtmlBlock = true,
    bool enableThematicBreak = true,
    bool enableAutolinkExtension = false,
    bool enableAutolink = true,
    bool enableBackslashEscape = true,
    bool enableCodeSpan = true,
    bool enableEmoji = false,
    bool enableColorSwatch = false,
    bool enableEmphasis = true,
    bool enableHardLineBreak = true,
    bool enableImage = true,
    bool enableLink = true,
    bool enableRawHtml = true,
    bool enableSoftLineBreak = true,
    bool enableStrikethrough = false,
    bool enableTaskList = false,
    Resolver? linkResolver,
    Resolver? imageLinkResolver,
    Iterable<Syntax> extensions = const [],
    this.escapeHtml = true,
  }) : hasCustomInlineSyntaxes = extensions.any((e) => e is InlineSyntax) {
    for (final syntax in extensions) {
      if (syntax is BlockSyntax) {
        _blockSyntaxes.add(syntax);
      } else {
        _inlineSyntaxes.add(syntax as InlineSyntax);
      }
    }

    _blockSyntaxes.addAll([
      if (enableAtxHeading && !enableHeadingId) const HeaderSyntax(),
      if (enableAtxHeading && enableHeadingId) const HeaderWithIdSyntax(),
      if (enableSetextHeading && !enableHeadingId) const SetextHeaderSyntax(),
      if (enableSetextHeading && enableHeadingId)
        const SetextHeaderWithIdSyntax(),
      if (enableThematicBreak) const HorizontalRuleSyntax(),
      if (enableList && !enableTaskList) ...[
        const OrderedListSyntax(),
        const UnorderedListSyntax(),
      ],
      if (enableList && enableTaskList) ...[
        const OrderedListWithCheckboxSyntax(),
        const UnorderedListWithCheckboxSyntax(),
      ],
      if (enableFencedBlockquote) const FencedBlockquoteSyntax(),
      if (enableBlockquote) const BlockquoteSyntax(),
      if (enableIndentedCodeBlock) const CodeBlockSyntax(),
      if (enableFencedCodeBlock) const FencedCodeBlockSyntax(),
      if (enableTable) const TableSyntax(),
      if (enableHtmlBlock) const HtmlBlockSyntax(),
      const ParagraphSyntax(),
    ]);

    _inlineSyntaxes.addAll([
      // This first RegExp matches plain text to accelerate parsing. It's written
      // so that it does not match any prefix of any following syntaxes. Most
      // Markdown is plain text, so it's faster to match one RegExp per 'word'
      // rather than fail to match all the following RegExps at each non-syntax
      // character position.
      if (!hasCustomInlineSyntaxes)
        TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9](?=\s)'),

      // We should be less aggressive in blowing past "words".
      if (hasCustomInlineSyntaxes) TextSyntax(r'[A-Za-z0-9]+(?=\s)'),

      if (enableHardLineBreak) LineBreakSyntax(),
      if (enableSoftLineBreak) SoftLineBreakSyntax(),
      if (enableBackslashEscape) EscapeSyntax(),
      // "*" surrounded by spaces is left alone.
      TextSyntax(r' \* ', startCharacter: $space),

      // "_" surrounded by spaces is left alone.
      TextSyntax(' _ ', startCharacter: $space),
      if (enableEmphasis) ...[
        // Parse "**strong**" and "*emphasis*" tags.
        EmphasisSyntax.asterisk(),

        // Parse "__strong__" and "_emphasis_" tags.
        EmphasisSyntax.underscore()
      ],
      if (enableAutolink) AutolinkSyntax(),
      if (enableAutolinkExtension) AutolinkExtensionSyntax(),
      if (enableCodeSpan) CodeSyntax(),
      if (enableStrikethrough) StrikethroughSyntax(),
      if (enableEmoji) EmojiSyntax(),
      if (enableColorSwatch) ColorSwatchSyntax(),
      if (enableLink) LinkSyntax(linkResolver: linkResolver),
      if (enableImage) ImageSyntax(linkResolver: imageLinkResolver),
      if (enableRawHtml) InlineHtmlSyntax(),
      if (escapeHtml) ...[
        EscapeHtmlSyntax(),
        // Leave already-encoded HTML entities alone. Ensures we don't turn
        // "&amp;" into "&amp;amp;"
        TextSyntax('&[#a-zA-Z0-9]*;', startCharacter: $ampersand),
      ],
    ]);
  }

  /// The [commonMark] extension set is close to compliance with [CommonMark].
  ///
  /// [CommonMark]: http://commonmark.org/
  factory Markdown.commonMark({bool escapeHtml = true}) =>
      Markdown(escapeHtml: escapeHtml);

  /// The [gitHubWeb] extension set renders Markdown similarly to GitHub.
  ///
  /// This is different from the [gitHubFlavored] extension set in that GitHub
  /// actually renders HTML different from straight [GitHub flavored Markdown].
  ///
  /// (The only difference currently is that [gitHubWeb] renders headers with
  /// linkable IDs.)
  ///
  /// [GitHub flavored Markdown]: https://github.github.com/gfm/
  factory Markdown.gitHubWeb({bool escapeHtml = true}) => Markdown(
        enableAutolinkExtension: true,
        enableTable: true,
        enableTaskList: true,
        enableStrikethrough: true,
        enableHeadingId: true,
        enableColorSwatch: true,
        enableEmoji: true,
        escapeHtml: escapeHtml,
      );

  /// The [gitHubFlavored] extension set is close to compliance with the
  /// [GitHub flavored Markdown spec](https://github.github.com/gfm/).
  factory Markdown.gitHubFlavored({bool escapeHtml = true}) => Markdown(
        enableAutolinkExtension: true,
        enableTable: true,
        enableTaskList: true,
        enableStrikethrough: true,
        escapeHtml: escapeHtml,
      );

  /// Parses the given string of Markdown to a series of AST nodes.
  List<Node> parse(String text) {
    // Replace windows line endings with unix line endings, and split.
    final lines = text.replaceAll('\r\n', '\n').split('\n');
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
