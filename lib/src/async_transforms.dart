import 'dart:async';

import 'ast.dart';
import 'block_parser.dart';
import 'block_syntaxes/block_syntax.dart';
import 'document.dart';
import 'extension_set.dart';
import 'inline_syntaxes/inline_syntax.dart';

class AsyncDocument extends Document {
  /// Manages any async node transforms that may be uncompleted
  //final AsyncTranformManager asyncTransformManager = AsyncTranformManager();
  final List<Future<String>> asyncTextNodes = [];

  Future<List<String>> waitForCompletion() {
    return Future.wait(asyncTextNodes);
  }

  // New super initializer syntax
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

/// A plain text element.
class AsyncText extends Text {
  String? asyncTextVal;

  bool isComplete = false;

  AsyncText(Future<String> theFuture, BlockParser parser,
      {String uncompletedFutureTextValue = 'uncompleted future'})
      : super(uncompletedFutureTextValue) {
    final AsyncDocument parentDoc = parser.document as AsyncDocument;

    parentDoc.asyncTextNodes.add(theFuture);

    theFuture.then((val) {
      asyncTextVal = val;
      isComplete = true;
      //print('INNTER THEN Setting to returnsvg = ${val.substring(0, 20)}');
      return val;
    }).onError((error, stackTrace) {
      asyncTextVal = 'Exception $error creating AsyncText node.';
      isComplete = true;
      print(asyncTextVal);
      print(stackTrace);
      return asyncTextVal!;
    });
  }

// //KLUDGE just here to shut up warning of not using _asyncFutureText
//   Future<String> get asyncFutureText {
//     return _asyncFutureText!;
//   }

//   set asyncFutureText(Future<String> theFuture) {
//     _asyncFutureText = theFuture;
//     parentDoc.asyncTransformManager.asyncTextNodes.add(theFuture);

//     theFuture.then((val) {
//       asyncTextVal = val;
//       isComplete = true;
//       print('INNTER THEN Setting to returnsvg = ${val.substring(0, 20)}');
//       return val;
//     }).onError((error, stackTrace) {
//       asyncTextVal = 'Exception $error creating INNER ASYNC';
//       isComplete = true;
//       print(asyncTextVal);
//       print(stackTrace);
//       return asyncTextVal!;
//     });
//   }

  @override
  String get textContent {
    if (!isComplete || asyncTextVal == null) {
      return text;
    }
    return asyncTextVal!;
  }
}

// class AsyncTranformManager {
//   final List<Future<String>> asyncTextNodes = [];

//   Future<List<String>> waitForCompletion() {
//     print('Here in waitForCompletion() about to WAIT asyncTextNodes.length=${asyncTextNodes.length}');
//     return Future.wait(asyncTextNodes);
//   }
// }
