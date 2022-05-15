// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(Zhiguang): Add docs

import 'package:source_span/source_span.dart';

import 'util.dart';

typedef Resolver = Node? Function(String name, [String? title]);

/// Base class for Markdown AST item such as [Element] and [Text]
abstract class Node {
  String get textContent;

  void accept(NodeVisitor visitor);

  Map<String, dynamic> toMap();
}

class Element implements Node {
  final String type;
  final List<Token> markers;
  final List<Node> children;
  final SourceLocation start;
  final SourceLocation end;
  final Map<String, String> attributes;

  @override
  String get textContent {
    return children.map((child) => child.textContent).join('');
  }

  Element(
    this.type, {
    this.markers = const [],
    this.children = const [],
    required this.start,
    required this.end,
    this.attributes = const {},
  });

  Element.todo(
    this.type, {
    this.markers = const [],
    this.children = const [],
    this.attributes = const {},
  })  : start = _start(),
        end = _end('0');

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
  Map<String, dynamic> toMap() => {
        'type': type,
        'markers': markers.map((e) => e.toMap()).toList(),
        'children': children.map((e) => e.toMap()).toList(),
        'start': _sourceLocationToMap(start),
        'end': _sourceLocationToMap(end),
        'attributes': attributes,
        'textContent': textContent,
      };

  @override
  String toString() => mapToPrettyString(toMap());
}

class Text extends Token implements Node {
  @override
  String get textContent => text;

  Text(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
  }) : super(text, start: start, end: end);

  @override
  void accept(NodeVisitor visitor) => visitor.visitText(this);

  Text.todo(String text) : super(text, start: _start(), end: _end(text));
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

  UnparsedContent.todo(String text) : super.todo(text);
}

class Token extends SourceSpanBase {
  final Map<String, String> attributes;

  Token(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
    this.attributes = const {},
  }) : super(start, end, text);

  /// Creates a new [Token] from [text] and [context]
  ///
  /// [line] is the the line where [context] start in the Markdown string.
  ///
  /// [offset] is the offset where the [context] start in the Markdown string
  factory Token.create(
    String text, {
    required int line,
    required int offset,
    required String context,
    required int indexStart,
  }) {
    final length = text.length;
    final contentOffset = context.indexOf(text, indexStart);
    final sourceFile = SourceFile.fromString(context);
    final fileSpan = sourceFile.span(contentOffset, contentOffset + length);

    final start = SourceLocation(
      offset + contentOffset,
      column: fileSpan.start.column,
      line: line + fileSpan.start.line,
    );

    final end = SourceLocation(
      start.offset + length,
      column: fileSpan.end.column,
      line: line + fileSpan.end.line,
    );

    return Token(text, start: start, end: end);
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'length': length,
        'start': _sourceLocationToMap(start),
        'end': _sourceLocationToMap(end),
        'attributes': attributes,
      };

  @override
  String toString() => mapToPrettyString(toMap());
}

// TODO(Zhiguang): update docs

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

Map<String, int> _sourceLocationToMap(SourceLocation location) => {
      'line': location.line,
      'column': location.column,
      'offset': location.offset,
    };

// TODO(Zhiguang): Delete the lines below
var _offset = 0;
SourceLocation _start() => SourceLocation(_offset++);
SourceLocation _end(String text) => SourceLocation(text.length + _offset - 1);
