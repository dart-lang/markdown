// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import 'link_syntax.dart';

/// Matches images like `![alternate text](url "optional title")` and
/// `![alternate text][label]`.
class ImageSyntax extends LinkSyntax {
  ImageSyntax({Resolver? linkResolver})
      : super(
          linkResolver: linkResolver,
          pattern: r'!\[',
          startCharacter: $exclamation,
        );

  @override
  Element createNode(
    String destination,
    String? title, {
    required List<Node> Function() getChildren,
  }) {
    final children = getChildren();
    final attributes = {
      'uri': destination,
      'description': children.map((node) => node.textContent).join(),
    };

    if (title != null && title.isNotEmpty) {
      attributes['title'] = title.replaceAll('&', '&amp;');
    }

    return Element.todo('image', attributes: attributes);
  }
}
