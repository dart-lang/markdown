import 'dart:async';

import 'ast.dart';
import 'block_parser.dart';
import 'block_syntaxes/block_syntax.dart';
import 'document.dart';
import 'extension_set.dart';
import 'inline_syntaxes/inline_syntax.dart';

class AsyncDocument extends Document {
  /// List of async text node transforms that may be uncompleted.
  final List<Future<String>> asyncTextNodes = [];

  /// Called before final conversion to html so ensure that all
  /// async text nodes have completed.
  Future<List<String>> waitForCompletion() {
    return Future.wait(asyncTextNodes);
  }

  // New super initializer syntax -
  // AsyncDocument({
  //   super.blockSyntaxes,
  //   super.inlineSyntaxes,
  //   super.extensionSet,
  //   super.linkResolver,
  //   super.imageLinkResolver,
  //   super.encodeHtml = true,
  //   super.withDefaultBlockSyntaxes = true,
  //   super.withDefaultInlineSyntaxes = true,
  // });

  // Dart 2.16.2 syntax:
  AsyncDocument(
      {Iterable<BlockSyntax>? blockSyntaxes,
      Iterable<InlineSyntax>? inlineSyntaxes,
      ExtensionSet? extensionSet,
      Resolver? linkResolver,
      Resolver? imageLinkResolver,
      bool encodeHtml = true,
      bool withDefaultBlockSyntaxes = true,
      bool withDefaultInlineSyntaxes = true})
      : super(
            blockSyntaxes: blockSyntaxes,
            inlineSyntaxes: inlineSyntaxes,
            extensionSet: extensionSet,
            linkResolver: linkResolver,
            imageLinkResolver: imageLinkResolver,
            encodeHtml: encodeHtml,
            withDefaultBlockSyntaxes: withDefaultBlockSyntaxes,
            withDefaultInlineSyntaxes: withDefaultInlineSyntaxes);
}

/// An async text element whos value will change once the future completes.
class AsyncText extends Text {
  String? asyncTextVal;

  bool isComplete = false;

  AsyncText(Future<String> theFuture, BlockParser parser,
      {String uncompletedFutureTextValue = 'Uncompleted future.'})
      : super(uncompletedFutureTextValue) {
    final AsyncDocument parentDoc = parser.document as AsyncDocument;

    parentDoc.asyncTextNodes.add(theFuture);

    theFuture.then((val) {
      asyncTextVal = val;
      isComplete = true;
      return val;
    }).onError((error, stackTrace) {
      asyncTextVal = 'Exception $error creating AsyncText node.';
      isComplete = true;
      print(asyncTextVal);
      print(stackTrace);
      return text; // Use original text value on error.
    });
  }

  @override
  String get textContent {
    if (!isComplete || asyncTextVal == null) {
      // Return original text if future not complete or there
      // is no async text value.
      return text;
    }
    return asyncTextVal!;
  }
}
