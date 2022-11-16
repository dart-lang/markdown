// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_syntaxes/block_syntax.dart';
import 'block_syntaxes/blockquote_syntax.dart';
import 'block_syntaxes/code_block_syntax.dart';
import 'block_syntaxes/dummy_block_syntax.dart';
import 'block_syntaxes/empty_block_syntax.dart';
import 'block_syntaxes/header_syntax.dart';
import 'block_syntaxes/horizontal_rule_syntax.dart';
import 'block_syntaxes/html_block_syntax.dart';
import 'block_syntaxes/ordered_list_syntax.dart';
import 'block_syntaxes/paragraph_syntax.dart';
import 'block_syntaxes/setext_header_syntax.dart';
import 'block_syntaxes/unordered_list_syntax.dart';
import 'document.dart';
import 'line.dart';

/// Maintains the internal state needed to parse a series of lines into blocks
/// of Markdown suitable for further inline parsing.
class BlockParser {
  final List<Line> lines;

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
    const HtmlBlockSyntax(),
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

    if (document.withDefaultBlockSyntaxes) {
      blockSyntaxes.addAll(standardBlockSyntaxes);
    } else {
      blockSyntaxes.add(const DummyBlockSyntax());
    }
  }

  /// Gets the current line.
  Line get current => lines[_pos];

  /// Gets the line after the current one or `null` if there is none.
  Line? get next {
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
  Line? peek(int linesAhead) {
    if (linesAhead < 0) {
      throw ArgumentError('Invalid linesAhead: $linesAhead; must be >= 0.');
    }
    // Don't read past the end.
    if (_pos >= lines.length - linesAhead) return null;
    return lines[_pos + linesAhead];
  }

  void advance() {
    _pos++;
  }

  void retreat() {
    _pos--;
  }

  bool get isDone => _pos >= lines.length;

  /// Gets whether or not the current line matches the given pattern.
  bool matches(RegExp regex) {
    if (isDone) return false;
    return regex.hasMatch(current.content);
  }

  /// Gets whether or not the next line matches the given pattern.
  bool matchesNext(RegExp regex) {
    if (next == null) return false;
    return regex.hasMatch(next!.content);
  }

  List<Node> parseLines() {
    final blocks = <Node>[];

    // If the `_pos` does not change before and after `parse()`, never try to
    // parse the line at `_pos` with the same syntax again.
    // For example the `TableSyntax` might not advance the `_pos` in `parse`
    // method, beause of the header row does not match the delimiter row in the
    // number of cells, which makes a table like structure not be recognized.
    BlockSyntax? neverMatch;

    while (!isDone) {
      for (final syntax in blockSyntaxes) {
        if (neverMatch == syntax) {
          continue;
        }

        if (syntax.canParse(this)) {
          final positionBefore = _pos;
          final block = syntax.parse(this);
          if (block != null) {
            blocks.add(block);
          }
          neverMatch = _pos != positionBefore ? null : syntax;

          break;
        }
      }
    }

    return blocks;
  }
}
