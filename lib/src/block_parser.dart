// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library markdown.block_parser;

import 'ast.dart';
import 'document.dart';
import 'util.dart';

/// The line contains only whitespace or is empty.
final _emptyPattern = new RegExp(r'^(?:[ \t]*)$');

/// A series of `=` or `-` (on the next line) define setext-style headers.
final _setextPattern = new RegExp(r'^(=+|-+)$');

/// Leading (and trailing) `#` define atx-style headers.
///
/// Starts with 1-6 unescaped `#` characters which must not be followed by a
/// non-space character. Line may end with any number of `#` characters,.
final _headerPattern = new RegExp(r'^(#{1,6})[ \x09\x0b\x0c](.*?)#*$');

/// The line starts with `>` with one optional space after.
final _blockquotePattern = new RegExp(r'^[ ]{0,3}>[ ]?(.*)$');

/// A line indented four spaces. Used for code blocks and lists.
final _indentPattern = new RegExp(r'^(?:    |\t)(.*)$');

/// Fenced code block.
final _codePattern = new RegExp(r'^[ ]{0,3}(`{3,}|~{3,})(.*)$');

/// Three or more hyphens, asterisks or underscores by themselves. Note that
/// a line like `----` is valid as both HR and SETEXT. In case of a tie,
/// SETEXT should win.
final _hrPattern = new RegExp(r'^ {0,3}([-*_]) *\1 *\1(?:\1| )*$');

/// A line starting with one of these markers: `-`, `*`, `+`. May have up to
/// three leading spaces before the marker and any number of spaces or tabs
/// after.
///
/// Contains a dummy group at [2], so that the groups in [_ulPattern] and
/// [_olPattern] match up; in both, [2] is the length of the number that begins
/// the list marker.
final _ulPattern = new RegExp(r'^([ ]{0,3})()([*+-])(([ \t])([ \t]*)(.*))?$');

/// A line starting with a number like `123.`. May have up to three leading
/// spaces before the marker and any number of spaces or tabs after.
final _olPattern =
    new RegExp(r'^([ ]{0,3})(\d{1,9})([\.)])(([ \t])([ \t]*)(.*))?$');

/// Maintains the internal state needed to parse a series of lines into blocks
/// of Markdown suitable for further inline parsing.
class BlockParser {
  final List<String> lines;

  /// The Markdown document this parser is parsing.
  final Document document;

  /// The enabled block syntaxes.
  ///
  /// To turn a series of lines into blocks, each of these will be tried in
  /// turn. Order matters here.
  final List<BlockSyntax> blockSyntaxes = [];

  /// Index of the current line.
  int _pos = 0;

  /// Whether the parser has encountered a blank line between two block-level
  /// elements.
  bool encounteredBlankLine = false;

  /// The collection of built-in block parsers.
  final List<BlockSyntax> standardBlockSyntaxes = [
    const EmptyBlockSyntax(),
    const BlockTagBlockHtmlSyntax(),
    new LongBlockHtmlSyntax(r'^ {0,3}<pre(?:\s|>|$)', '</pre>'),
    new LongBlockHtmlSyntax(r'^ {0,3}<script(?:\s|>|$)', '</script>'),
    new LongBlockHtmlSyntax(r'^ {0,3}<style(?:\s|>|$)', '</style>'),
    new LongBlockHtmlSyntax('^ {0,3}<!--', '-->'),
    new LongBlockHtmlSyntax('^ {0,3}<\\?', '\\?>'),
    new LongBlockHtmlSyntax('^ {0,3}<![A-Z]', '>'),
    new LongBlockHtmlSyntax('^ {0,3}<!\\[CDATA\\[', '\\]\\]>'),
    const OtherTagBlockHtmlSyntax(),
    const SetextHeaderSyntax(),
    const HeaderSyntax(),
    const CodeBlockSyntax(),
    const BlockquoteSyntax(),
    const HorizontalRuleSyntax(),
    const UnorderedListSyntax(),
    const OrderedListSyntax(),
    const ParagraphSyntax()
  ];

  BlockParser(this.lines, this.document) {
    blockSyntaxes.addAll(document.blockSyntaxes);
    blockSyntaxes.addAll(standardBlockSyntaxes);
  }

  /// Gets the current line.
  String get current => lines[_pos];

  /// Gets the line after the current one or `null` if there is none.
  String get next {
    // Don't read past the end.
    if (_pos >= lines.length - 1) return null;
    return lines[_pos + 1];
  }

  /// Gets the line that is [linesAhead] lines ahead of the current one, or
  /// `null` if there is none.
  ///
  /// `peek(0)` is equivalent to [current].
  ///
  /// `peek(1)` is equivalent to [next].
  String peek(int linesAhead) {
    if (linesAhead < 0)
      throw new ArgumentError('Invalid linesAhead: $linesAhead; must be >= 0.');
    // Don't read past the end.
    if (_pos >= lines.length - linesAhead) return null;
    return lines[_pos + linesAhead];
  }

  void advance() {
    _pos++;
  }

  bool get isDone => _pos >= lines.length;

  /// Gets whether or not the current line matches the given pattern.
  bool matches(RegExp regex) {
    if (isDone) return false;
    return regex.firstMatch(current) != null;
  }

  /// Gets whether or not the next line matches the given pattern.
  bool matchesNext(RegExp regex) {
    if (next == null) return false;
    return regex.firstMatch(next) != null;
  }

  List<Node> parseLines() {
    var blocks = <Node>[];
    while (!isDone) {
      for (var syntax in blockSyntaxes) {
        if (syntax.canParse(this)) {
          var block = syntax.parse(this);
          if (block != null) blocks.add(block);
          break;
        }
      }
    }

    return blocks;
  }
}

abstract class BlockSyntax {
  const BlockSyntax();

  /// Gets the regex used to identify the beginning of this block, if any.
  RegExp get pattern => null;

  bool get canEndBlock => true;

  bool canParse(BlockParser parser) {
    return pattern.firstMatch(parser.current) != null;
  }

  Node parse(BlockParser parser);

  List<String> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the block element.
    var childLines = <String>[];

    while (!parser.isDone) {
      var match = pattern.firstMatch(parser.current);
      if (match == null) break;
      childLines.add(match[1]);
      parser.advance();
    }

    return childLines;
  }

  /// Gets whether or not [parser]'s current line should end the previous block.
  static bool isAtBlockEnd(BlockParser parser) {
    if (parser.isDone) return true;
    return parser.blockSyntaxes.any((s) => s.canParse(parser) && s.canEndBlock);
  }

  /// Generates a valid HTML anchor from the inner text of [element].
  static String generateAnchorHash(Element element) =>
      _concatenatedText(element)
          .toLowerCase()
          .trim()
          .replaceFirst(new RegExp(r'^[^a-z]+'), '')
          .replaceAll(new RegExp(r'[^a-z0-9 _-]'), '')
          .replaceAll(new RegExp(r'\s'), '-');

  /// Concatenates the text found in all the children of [element].
  static String _concatenatedText(Element element) => element.children
      .map((child) => (child is Text) ? child.text : _concatenatedText(child))
      .join('');
}

class EmptyBlockSyntax extends BlockSyntax {
  RegExp get pattern => _emptyPattern;

  const EmptyBlockSyntax();

  Node parse(BlockParser parser) {
    parser.encounteredBlankLine = true;
    parser.advance();

    // Don't actually emit anything.
    return null;
  }
}

/// Parses setext-style headers.
class SetextHeaderSyntax extends BlockSyntax {
  const SetextHeaderSyntax();

  bool canParse(BlockParser parser) {
    // Note: matches *next* line, not the current one. We're looking for the
    // underlining after this line.
    return parser.matchesNext(_setextPattern) &&
        // The current line must look like a paragraph.
        !(parser.matches(_codePattern) ||
            parser.matches(_headerPattern) ||
            parser.matches(_blockquotePattern) ||
            parser.matches(_hrPattern) ||
            parser.matches(_ulPattern) ||
            parser.matches(_olPattern));
  }

  Node parse(BlockParser parser) {
    var match = _setextPattern.firstMatch(parser.next);

    var tag = (match[1][0] == '=') ? 'h1' : 'h2';
    var contents = parser.document.parseInline(parser.current);
    parser.advance();
    parser.advance();

    return new Element(tag, contents);
  }
}

/// Parses setext-style headers, and adds generated IDs to the generated
/// elements.
class SetextHeaderWithIdSyntax extends SetextHeaderSyntax {
  const SetextHeaderWithIdSyntax();

  Node parse(BlockParser parser) {
    var element = super.parse(parser) as Element;
    element.generatedId = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  RegExp get pattern => _headerPattern;

  const HeaderSyntax();

  Node parse(BlockParser parser) {
    var match = pattern.firstMatch(parser.current);
    parser.advance();
    var level = match[1].length;
    var contents = parser.document.parseInline(match[2].trim());
    return new Element('h$level', contents);
  }
}

/// Parses atx-style headers, and adds generated IDs to the generated elements.
class HeaderWithIdSyntax extends HeaderSyntax {
  const HeaderWithIdSyntax();

  Node parse(BlockParser parser) {
    var element = super.parse(parser) as Element;
    element.generatedId = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}

/// Parses email-style blockquotes: `> quote`.
class BlockquoteSyntax extends BlockSyntax {
  RegExp get pattern => _blockquotePattern;

  const BlockquoteSyntax();

  List<String> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the blockquote, stripping off the ">".
    var childLines = <String>[];

    while (!parser.isDone) {
      var match = pattern.firstMatch(parser.current);
      if (match != null) {
        childLines.add(match[1]);
        parser.advance();
        continue;
      }

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      if (parser.blockSyntaxes.firstWhere((s) => s.canParse(parser))
          is ParagraphSyntax) {
        var continuedLine = childLines.last + parser.current;
        childLines
          ..removeLast()
          ..add(continuedLine);
        parser.advance();
      } else {
        break;
      }
    }

    return childLines;
  }

  Node parse(BlockParser parser) {
    var childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    var children = parser.document.parseLines(childLines);

    return new Element('blockquote', children);
  }
}

/// Parses preformatted code blocks that are indented four spaces.
class CodeBlockSyntax extends BlockSyntax {
  RegExp get pattern => _indentPattern;

  bool get canEndBlock => false;

  const CodeBlockSyntax();

  List<String> parseChildLines(BlockParser parser) {
    var childLines = <String>[];

    while (!parser.isDone) {
      var match = pattern.firstMatch(parser.current);
      if (match != null) {
        childLines.add(match[1]);
        parser.advance();
      } else {
        // If there's a codeblock, then a newline, then a codeblock, keep the
        // code blocks together.
        var nextMatch =
            parser.next != null ? pattern.firstMatch(parser.next) : null;
        if (parser.current.trim() == '' && nextMatch != null) {
          childLines.add('');
          childLines.add(nextMatch[1]);
          parser.advance();
          parser.advance();
        } else {
          break;
        }
      }
    }
    return childLines;
  }

  Node parse(BlockParser parser) {
    var childLines = parseChildLines(parser);

    // The Markdown tests expect a trailing newline.
    childLines.add('');

    // Escape the code.
    var escaped = escapeHtml(childLines.join('\n'));

    return new Element('pre', [new Element.text('code', escaped)]);
  }
}

/// Parses preformatted code blocks between two ~~~ or ``` sequences.
///
/// See [Pandoc's documentation](http://pandoc.org/README.html#fenced-code-blocks).
class FencedCodeBlockSyntax extends BlockSyntax {
  RegExp get pattern => _codePattern;

  const FencedCodeBlockSyntax();

  List<String> parseChildLines(BlockParser parser, [String endBlock]) {
    if (endBlock == null) endBlock = '';

    var childLines = <String>[];
    parser.advance();

    while (!parser.isDone) {
      var match = pattern.firstMatch(parser.current);
      if (match == null || !match[1].startsWith(endBlock)) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    return childLines;
  }

  Node parse(BlockParser parser) {
    // Get the syntax identifier, if there is one.
    var match = pattern.firstMatch(parser.current);
    var endBlock = match.group(1);
    var infoString = match.group(2);

    var childLines = parseChildLines(parser, endBlock);

    // The Markdown tests expect a trailing newline.
    childLines.add('');

    // Escape the code.
    var escaped = escapeHtml(childLines.join('\n'));

    var code = new Element.text('code', escaped);

    // the info-string should be trimmed
    // http://spec.commonmark.org/0.22/#example-100
    infoString = infoString.trim();
    if (infoString.isNotEmpty) {
      // only use the first word in the syntax
      // http://spec.commonmark.org/0.22/#example-100
      infoString = infoString.split(' ').first;
      code.attributes['class'] = "language-$infoString";
    }

    var element = new Element('pre', [code]);

    return element;
  }
}

/// Parses horizontal rules like `---`, `_ _ _`, `*  *  *`, etc.
class HorizontalRuleSyntax extends BlockSyntax {
  RegExp get pattern => _hrPattern;

  const HorizontalRuleSyntax();

  Node parse(BlockParser parser) {
    parser.advance();
    return new Element.empty('hr');
  }
}

/// Parses inline HTML at the block level. This differs from other Markdown
/// implementations in several ways:
///
/// 1.  This one is way way WAY simpler.
/// 2.  Essentially no HTML parsing or validation is done. We're a Markdown
///     parser, not an HTML parser!
abstract class BlockHtmlSyntax extends BlockSyntax {
  bool get canEndBlock => true;

  const BlockHtmlSyntax();
}

class BlockTagBlockHtmlSyntax extends BlockHtmlSyntax {
  RegExp get pattern => new RegExp(
      r'^ {0,3}</?(?:address|article|aside|base|basefont|blockquote|body|'
      r'caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|'
      r'figcaption|figure|footer|form|frame|frameset|h1|head|header|hr|html|'
      r'iframe|legend|li|link|main|menu|menuitem|meta|nav|noframes|ol|optgroup|'
      r'option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|'
      'title|tr|track|ul)'
      r'(?:\s|>|/>|$)');

  const BlockTagBlockHtmlSyntax();

  Node parse(BlockParser parser) {
    var childLines = <String>[];

    // Eat until we hit a blank line.
    while (!parser.isDone && !parser.matches(_emptyPattern)) {
      childLines.add(parser.current);
      parser.advance();
    }

    return new Text(childLines.join('\n'));
  }
}

class OtherTagBlockHtmlSyntax extends BlockTagBlockHtmlSyntax {
  bool get canEndBlock => false;

  // Really hacky way to detect "other" HTML. This matches:
  //
  // * any opening spaces
  // * open bracket and maybe a slash ("<" or "</")
  // * some word characters
  // * either:
  //   * a close bracket, or
  //   * whitespace followed by not-brackets follwed by a close bracket
  // * possible whitespace and the end of the line.
  RegExp get pattern => new RegExp(r'^ {0,3}</?\w+(?:>|\s+[^>]*>)\s*$');

  const OtherTagBlockHtmlSyntax();
}

/// A BlockHtmlSyntax that has a specific [endPattern].
///
/// In practice this means that the syntax dominates; it is allowed to eat
/// many lines, including blank lines, before matching its [endPattern].
class LongBlockHtmlSyntax extends BlockHtmlSyntax {
  RegExp _pattern;
  RegExp _endPattern;

  LongBlockHtmlSyntax(pattern, endPattern) {
    _pattern = new RegExp(pattern);
    _endPattern = new RegExp(endPattern);
  }

  RegExp get pattern => _pattern;

  Node parse(BlockParser parser) {
    var childLines = <String>[];
    // Eat until we hit [endPattern].
    while (!parser.isDone) {
      childLines.add(parser.current);
      if (parser.matches(_endPattern)) break;
      parser.advance();
    }

    parser.advance();
    return new Text(childLines.join('\n'));
  }
}

class ListItem {
  bool forceBlock = false;
  final List<String> lines;

  ListItem(this.lines);
}

/// Base class for both ordered and unordered lists.
abstract class ListSyntax extends BlockSyntax {
  bool get canEndBlock => true;

  String get listTag;

  const ListSyntax();

  /// A list of patterns that can start a valid block within a list item.
  static final blocksInList = [
    _blockquotePattern,
    _headerPattern,
    _hrPattern,
    _indentPattern,
    _ulPattern,
    _olPattern
  ];

  Node parse(BlockParser parser) {
    var items = <ListItem>[];
    var childLines = <String>[];

    endItem() {
      if (childLines.length > 0) {
        items.add(new ListItem(childLines));
        childLines = <String>[];
      }
    }

    var match;
    tryMatch(RegExp pattern) {
      match = pattern.firstMatch(parser.current);
      return match != null;
    }

    var listMarker = null;
    var indent;

    while (!parser.isDone) {
      if (tryMatch(_emptyPattern)) {
        if (_emptyPattern.firstMatch(parser.next ?? '') != null) {
          // Two blank lines ends a list.
          break;
        }
        // Add a blank line to the current list item.
        childLines.add('');
      } else if (indent != null && parser.current.startsWith(indent)) {
        // Strip off indent and add to current item.
        var line = parser.current.replaceFirst(indent, '');
        childLines.add(line);
      } else if (tryMatch(_ulPattern) || tryMatch(_olPattern)) {
        var precedingWhitespace = match[1];
        var digits = match[2] ?? '';
        var marker = match[3];
        var isBlank = match[4] == null;
        var firstWhitespace = match[5] ?? '';
        var restWhitespace = match[6] ?? '';
        var content = match[7] ?? '';
        if (listMarker != null && listMarker != marker) {
          // Changing the bullet or ordered list delimiter starts a new list.
          break;
        }
        listMarker = marker;
        var markerAsSpaces = ' ' * (digits.length + marker.length);
        if (isBlank) {
          // See http://spec.commonmark.org/0.25/#list-items under "3. Item
          // starting with a blank line."
          //
          // If the list item starts with a blank line, the final piece of the
          // indentation is just a single space.
          indent = precedingWhitespace + markerAsSpaces + ' ';
        } else if (match[5].length >= 4) {
          // See http://spec.commonmark.org/0.25/#list-items under "2. Item
          // starting with indented code."
          //
          // If the list item starts with indented code, we need to _not_ count
          // any indentation past the required whitespace character.
          indent = precedingWhitespace + markerAsSpaces + firstWhitespace;
        } else {
          indent = precedingWhitespace +
              markerAsSpaces +
              firstWhitespace +
              restWhitespace;
        }
        // End the current list item and start a new one.
        endItem();
        childLines.add(restWhitespace + content);
      } else if (BlockSyntax.isAtBlockEnd(parser)) {
        // Done with the list.
        break;
      } else {
        // If the previous item is a blank line, this means we're done with the
        // list and are starting a new top-level paragraph.
        if ((childLines.isNotEmpty) && (childLines.last == '')) break;

        // Anything else is paragraph continuation text.
        var continuedLine = childLines.last + parser.current;
        childLines
          ..removeLast()
          ..add(continuedLine);
      }
      parser.advance();
    }

    endItem();
    var itemNodes = <Element>[];

    var anyEmptyLines = removeTrailingEmptyLines(items);
    var anyEmptyLinesBetweenBlocks = false;

    for (var item in items) {
      var itemParser = new BlockParser(item.lines, parser.document);
      var children = itemParser.parseLines();
      itemNodes.add(new Element('li', children));
      anyEmptyLinesBetweenBlocks =
          anyEmptyLinesBetweenBlocks || itemParser.encounteredBlankLine;
    }

    // Must strip paragraph tags if the list is "tight".
    // http://spec.commonmark.org/0.25/#lists
    var listIsTight = !anyEmptyLines && !anyEmptyLinesBetweenBlocks;

    if (listIsTight) {
      // We must post-process the list items, converting any top-level paragraph
      // elements to just text elements.
      for (var item in itemNodes) {
        for (var i = 0; i < item.children.length; i++) {
          var child = item.children[i];
          if (child is Element && child.tag == 'p') {
            item.children.removeAt(i);
            item.children.insertAll(i, child.children);
          }
        }
      }
    }

    return new Element(listTag, itemNodes);
  }

  /// Removes any trailing empty lines and notes whether any items are separated
  /// by such lines.
  bool removeTrailingEmptyLines(List items) {
    var anyEmpty = false;
    for (var i = 0; i < items.length; i++) {
      while (items[i].lines.isNotEmpty &&
          _emptyPattern.hasMatch(items[i].lines.last)) {
        if (i < items.length - 1) {
          anyEmpty = true;
        }
        items[i].lines.removeLast();
      }
    }
    return anyEmpty;
  }
}

/// Parses unordered lists.
class UnorderedListSyntax extends ListSyntax {
  RegExp get pattern => _ulPattern;
  String get listTag => 'ul';

  const UnorderedListSyntax();
}

/// Parses ordered lists.
class OrderedListSyntax extends ListSyntax {
  RegExp get pattern => _olPattern;
  String get listTag => 'ol';

  const OrderedListSyntax();
}

/// Parses paragraphs of regular text.
class ParagraphSyntax extends BlockSyntax {
  bool get canEndBlock => false;

  const ParagraphSyntax();

  bool canParse(BlockParser parser) => true;

  Node parse(BlockParser parser) {
    var childLines = <String>[];

    // Eat until we hit something that ends a paragraph.
    while (!BlockSyntax.isAtBlockEnd(parser)) {
      childLines.add(parser.current);
      parser.advance();
    }

    var contents = parser.document.parseInline(childLines.join('\n'));
    return new Element('p', contents);
  }
}
