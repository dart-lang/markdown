// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../document.dart';
import '../extensions.dart';
import '../line.dart';
import '../parsers/block_parser.dart';
import '../parsers/link_parser.dart';
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
      trimLeft: true,
      popLineEnding: true,
    );

    return Element(
      'paragraph',
      children: contents.nodes,
      lineEndings: []..addIfNotNull(contents.lineEnding),
    );
  }

  Node? _parseLinkReferenceDefinition(List<Line> lines, BlockParser parser) {
    final linkParser = LinkParser(lines.toSourceSpans())..parseDefinition();
    if (!linkParser.valid) {
      return null;
    }

    final label = linkParser.label;
    final destination = linkParser.destination;
    final title = linkParser.title;
    // Set the parsing position back to where the link reference definition
    // ends, so other syntax are able to consume the rest.

    // Here might be a performance issue, because the paragraph syntax needs to
    // parse some lines twice if it begins with a possible link reference
    // definition. In the future, maybe we can change the parse to return a Node
    // list in order to return a linkReferenceDefinition and a paragraph at the
    // same time.
    final line = title == null || title.isEmpty
        ? (destination.isNotEmpty
            ? destination.last.end.line
            : label.last.end.line)
        : title.last.end.line;
    parser.setLine(line + 1);

    final labelString = normalizeLinkLabel(label.map((e) => e.text).join());

    parser.document.linkReferences.putIfAbsent(
      labelString,
      () => LinkReference(
        labelString,
        linkParser.formatted.destination,
        linkParser.formatted.title,
      ),
    );

    return Element(
      'linkReferenceDefinition',
      markers: linkParser.markers,
      lineEndings: linkParser.lineEndings,
      children: [
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
      ],
    );
  }
}
