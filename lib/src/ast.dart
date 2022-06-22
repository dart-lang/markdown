// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import 'extensions.dart';

typedef Resolver = Node? Function(String name, [String? title]);

/// Base class for Markdown AST item such as [Element] and [Text].
abstract class Node {
  String get textContent;

  void accept(NodeVisitor visitor);

  Map<String, dynamic> toMap();
}

/// An AST node that can contain other nodes.
class Element implements Node {
  /// Such as `atxHeading`
  final String type;

  final List<SourceSpan> markers;

  /// The line endings should be saved in [lineEndings] include:
  /// 1. A line ending of a marker.
  /// 2. Any other line endings should not be saved in AST [Node].
  ///
  /// The way of handling the ones not saved in [lineEndings], for example in a
  /// paragraph:
  /// 1. Concat with other [Text] node when it is possible.
  /// 2. Otherwise save it as a [Text] node along with other [children].
  final List<SourceSpan> lineEndings;
  final List<Node> children;
  final Map<String, String> attributes;

  @override
  String get textContent {
    return children.map((child) => child.textContent).join('');
  }

  Element(
    this.type, {
    this.markers = const [],
    this.lineEndings = const [],
    this.children = const [],
    this.attributes = const {},
  });

  @override
  void accept(NodeVisitor visitor) {
    if (visitor.visitElementBefore(this)) {
      if (children.isNotEmpty) {
        for (final child in children) {
          child.accept(visitor);
        }
      }
      visitor.visitElementAfter(this);
    }
  }

  @override
  Map<String, dynamic> toMap({
    bool showNull = false,
    bool showEmpty = false,
    bool showRuntimeType = false,
  }) =>
      {
        if (showRuntimeType) 'runtimeType': runtimeType,
        'type': type,
        if (markers.isNotEmpty || showEmpty)
          'markers': markers.map((e) => e.toMap()).toList(),
        if (lineEndings.isNotEmpty || showEmpty)
          'lineEndings': lineEndings.map((e) => e.toMap()).toList(),
        if (children.isNotEmpty || showEmpty)
          'children': children.map((e) => e.toMap()).toList(),
        if (attributes.isNotEmpty || showEmpty) 'attributes': attributes,
        'textContent': textContent,
      };

  @override
  String toString() => toMap().toPrettyString();
}

/// A plain text element.
class Text extends SourceSpanBase implements Node {
  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  final int? tabRemaining;

  @override
  String get textContent => text;

  @override
  void accept(NodeVisitor visitor) => visitor.visitText(this);

  Text(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
    this.tabRemaining,
  }) : super(start, end, text);

  /// Instantiates a [Text] from [span].
  Text.fromSpan(
    SourceSpan span, {
    this.tabRemaining,
  }) : super(span.start, span.end, span.text);

  /// Converts [text] to the result which meets the CommonMark specification,
  /// includinug:
  ///
  /// 1. Escapes the characters (`<`), (`>`) and (`&`).
  /// 2. Set [escapesDoubleQuotes] to `true` to escape double quotes (`"`).
  /// 3. Set [decodeHtmlCharacter] to `true` to decode HTML entity and numeric
  ///    character references, for example decode `&#35` to `#`.
  String htmlText({
    bool escapesDoubleQuotes = true,
    bool decodeHtmlCharacter = true,
  }) =>
      text.toHtmlText(
        escapesDoubleQuotes: escapesDoubleQuotes,
        decodeHtmlCharacter: decodeHtmlCharacter,
      );

  Text subText(int start, [int? end]) => Text.fromSpan(subspan(start, end));

  /// Combines `this` and the adjacent [other].
  Text concat(SourceSpan other) =>
      Text('$text${other.text}', start: start, end: other.end);

  @override
  Map<String, dynamic> toMap() => {
        'text': text,
        'start': start.toMap(),
        'end': end.toMap(),
      };

  @override
  String toString() => toMap().toPrettyString();
}

/// Inline content that has not been parsed into inline nodes (strong, links,
/// etc).
///
/// These placeholder nodes should only remain in place while the block nodes
/// of a document are still being parsed, in order to gather all reference link
/// definitions.
class UnparsedContent extends Text {
  UnparsedContent(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
  }) : super(text, start: start, end: end);

  /// Instantiates a [UnparsedContent] from [span].
  UnparsedContent.fromSpan(SourceSpan span) : super.fromSpan(span);
}

/// Visitor pattern for the AST.
///
/// Renderers or other AST transformers should implement this.
abstract class Visitor<T, E> {
  /// Called when an Element has been reached, before its children have been
  /// visited.
  ///
  /// Returns `false` to skip its children.
  bool visitElementBefore(E element);

  /// Called when an Element has been reached, after its children have been
  /// visited.
  ///
  /// Will not be called if [visitElementBefore] returns `false`.
  void visitElementAfter(E element);

  /// Called when a Text node has been reached.
  void visitText(T text);
}

abstract class NodeVisitor extends Visitor<Text, Element> {}
