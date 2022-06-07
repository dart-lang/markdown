// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../document.dart';
import '../extensions.dart';
import '../link_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';
import 'setext_heading_syntax.dart';

/// Parses paragraphs of regular text.
class ParagraphSyntax extends BlockSyntax {
  @override
  RegExp get pattern => dummyPattern;

  @override
  bool canInterrupt(BlockParser parser) => false;

  const ParagraphSyntax();

  @override
  bool canParse(BlockParser parser) => true;

  @override
  Node? parse(BlockParser parser) {
    parser
      ..linesBuffer.clear()
      ..linesBuffer.add(parser.current)
      ..advance();

    var hitSetextHeading = false;

    // Eat until we hit something that ends a paragraph.
    while (!parser.isDone) {
      final syntax = interruptedBy(parser);
      if (syntax != null) {
        hitSetextHeading = syntax is SetextHeadingSyntax;
        break;
      }
      parser
        ..linesBuffer.add(parser.current)
        ..advance();
    }

    final defNode = _parseLinkReferenceDefinition(parser.linesBuffer, parser);
    if (defNode != null) {
      parser.linesBuffer.clear();
      return defNode;
    }

    // It is not a paragraph, but a setext heading or a link reference
    // definition.
    if (hitSetextHeading || parser.linesBuffer.isEmpty) {
      return null;
    }

    final contents = parser.linesBuffer.toNodes(
      (span) => UnparsedContent.fromSpan(span),
      trimTrailing: true,
      popLineEnding: true,
    );

    return Element(
      'paragraph',
      children: contents.nodes,
      lineEndings: [if (contents.lineEnding != null) contents.lineEnding!],
    );
  }

  Node? _parseLinkReferenceDefinition(List<Line> lines, BlockParser parser) {
    final linkParser = LinkParser(lines.toSourceSpans().concatWhilePossible());

    final label = linkParser.parseLabel();
    if (label == null || linkParser.charAt() != $colon) {
      return null;
    }
    linkParser.advance();

    final destination = linkParser.parseDestination();
    if (destination == null) {
      return null;
    }

    var endingPosition = linkParser.position;
    List<SourceSpan>? title;
    final hadWhitespace = linkParser.moveThroughWhitespace() > 0;

    if (!linkParser.isDone) {
      final multiline = linkParser.charAt() == $lf;
      title = linkParser.parseTitle(hadWhitespace);

      if (title == null && !multiline) {
        return null;
      }

      if (title != null) {
        linkParser.moveThroughWhitespace();
        if (!linkParser.isDone && linkParser.charAt() != $lf) {
          return null;
        }
        endingPosition = linkParser.position;
      }
    }

    // Set the parsing position back to where the link reference definition
    // ends, so other syntax are able to consume the rest.

    // Here might be a performance issue, because the paragraph syntax needs to
    // parse some lines twice if it begins with a possible link reference
    // definition. In the future, maybe we can change the parse to return a Node
    // list in order to return a linkReferenceDefinition and a paragraph at the
    // same time.
    parser.setLine(linkParser.positionToLocation(endingPosition).line + 1);

    final labelString = normalizeLinkLabel(label.map((e) => e.text).join());
    parser.document.linkReferences.putIfAbsent(
      labelString,
      () => LinkReference(
        labelString,
        destination.map((e) => e.text).join(),
        title?.map((e) => e.text).join(),
      ),
    );

    return Element('linkReferenceDefinition', children: [
      Element(
        'linkReferenceDefinitionLabel',
        children: label.map((span) => Text.fromSpan(span)).toList(),
      ),
      Element(
        'linkReferenceDefinitionDestination',
        children: destination.map((span) => Text.fromSpan(span)).toList(),
      ),
      if (title != null)
        Element(
          'linkReferenceDefinitionTitle',
          children: title.map((span) => Text.fromSpan(span)).toList(),
        ),
    ]);
  }
}
