// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../charcode.dart';
import '../extensions.dart';
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
    required List<SourceSpan> markers,
    required List<SourceSpan> lineEndings,
    required List<SourceSpan> plainTextChildren,
    required List<Node> Function() getChildren,
  }) {
    markers.insertAll(1, plainTextChildren);
    final description = getChildren().map((node) {
      // See https://spec.commonmark.org/0.30/#image-description.
      // An image description may contain links. Fetch text from the description
      // attribute if this nested link is an image.
      if (node is Element && node.type == 'image') {
        return node.attributes['description'];
      }
      return node.textContent;
    }).join();

    final attributes = {
      'destination': destination,
      'description': description,
    };

    if (title != null && title.isNotEmpty) {
      attributes['title'] = title.toHtmlText();
    }

    return Element(
      'image',
      attributes: attributes,
      markers: markers,
      lineEndings: lineEndings,
    );
  }
}
