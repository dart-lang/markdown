// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';

/// Base class for any HTML AST item.
///
/// Roughly corresponds to HtmlNode in the DOM. Will be either an HtmlElement
/// or HtmlText.
abstract class HtmlNode {
  void accept(HtmlNodeVisitor visitor);

  String get textContent;
}

/// A named tag that can contain other nodes.
class HtmlElement implements HtmlNode {
  final String tag;
  final List<HtmlNode>? children;
  final Map<String, String> attributes;
  String? generatedId;

  /// Instantiates a [tag] HtmlElement with [children].
  HtmlElement(this.tag, this.children) : attributes = <String, String>{};

  /// Instantiates an empty, self-closing [tag] HtmlElement.
  HtmlElement.empty(this.tag)
      : children = null,
        attributes = {};

  /// Instantiates a [tag] HtmlElement with no [children].
  HtmlElement.withTag(this.tag)
      : children = [],
        attributes = {};

  /// Instantiates a [tag] HtmlElement with a single HtmlText child.
  HtmlElement.text(this.tag, String text)
      : children = [HtmlText(text)],
        attributes = {};

  /// Whether this element is self-closing.
  bool get isEmpty => children == null;

  @override
  void accept(HtmlNodeVisitor visitor) {
    if (visitor.visitElementBefore(this)) {
      if (children != null) {
        for (var child in children!) {
          child.accept(visitor);
        }
      }
      visitor.visitElementAfter(this);
    }
  }

  @override
  String get textContent {
    return (children ?? []).map((child) => child.textContent).join('');
  }
}

/// A plain text element.
class HtmlText implements HtmlNode {
  final String text;

  HtmlText(this.text);

  @override
  void accept(HtmlNodeVisitor visitor) => visitor.visitText(this);

  @override
  String get textContent => text;
}

abstract class HtmlNodeVisitor extends Visitor<HtmlText, HtmlElement> {}
