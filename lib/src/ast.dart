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

  final List<Node> children;
  final Map<String, String> attributes;

  @override
  String get textContent {
    return children.map((child) => child.textContent).join();
  }

  Element(
    this.type, {
    this.markers = const [],
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
        if (children.isNotEmpty || showEmpty)
          'children': children.map((e) => e.toMap()).toList(),
        if (attributes.isNotEmpty || showEmpty) 'attributes': attributes,
      };

  @override
  String toString() => toMap().toPrettyString();
}

/// A plain text element.
class Text extends SourceSpanBase implements Node {
  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  final int? _tabRemaining;

  /// If needs to convert line endings to whitespaces.
  // When it is a code span, line endings are treated like spaces, see
  // https://spec.commonmark.org/0.30/#example-335
  final bool _lineEndingToWhitespace;

  @override
  String get textContent {
    var result = text;
    if (_lineEndingToWhitespace) {
      result = text.replaceAll('\n', ' ');
    }
    if (_tabRemaining != null) {
      result = "${' ' * _tabRemaining!}$text";
    }
    return result;
  }

  @override
  void accept(NodeVisitor visitor) => visitor.visitText(this);

  Text(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
    int? tabRemaining,
    bool lineEndingToWhitespace = false,
  })  : _tabRemaining = tabRemaining,
        _lineEndingToWhitespace = lineEndingToWhitespace,
        super(start, end, text);

  /// Instantiates a [Text] from [span].
  Text.fromSpan(
    SourceSpan span, {
    int? tabRemaining,
    bool lineEndingToWhitespace = false,
  })  : _tabRemaining = tabRemaining,
        _lineEndingToWhitespace = lineEndingToWhitespace,
        super(span.start, span.end, span.text);

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
      textContent.toHtmlText(
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
        if (text != textContent) 'textContent': textContent,
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
