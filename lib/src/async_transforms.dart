import 'dart:async';

import 'ast.dart';
import 'block_parser.dart';
import 'document.dart';

class AsyncDocument extends Document {
  /// Manages any async node transforms that may be uncompleted
  final AsyncTranformManager asyncTransformManager = AsyncTranformManager();

  AsyncDocument({
    super.blockSyntaxes,
    super.inlineSyntaxes,
    super.extensionSet,
    super.linkResolver,
    super.imageLinkResolver,
    super.encodeHtml = true,
    super.withDefaultBlockSyntaxes = true,
    super.withDefaultInlineSyntaxes = true,
  });
}

/// A plain text element.
class AsyncText extends Text {
  late AsyncDocument parentDoc;
  final BlockParser parser;
  Future<String>? _asyncFutureText;
  String? asyncTextVal;

  bool isComplete = false;

  AsyncText(Future<String> theFuture, this.parser,
      {String uncompletedFutureTextValue = 'uncompleted future'})
      : super(uncompletedFutureTextValue) {
    parentDoc = parser.document as AsyncDocument;
    asyncFutureText = theFuture;
  }

//KLUDGE just here to shut up warning of not using _asyncFutureText
  Future<String> get asyncFutureText {
    return _asyncFutureText!;
  }
  
  set asyncFutureText(Future<String> theFuture) {
    _asyncFutureText = theFuture;
    parentDoc.asyncTransformManager.asyncTextNodes.add(theFuture);


    theFuture.then((val) {
      asyncTextVal = val;
      isComplete = true;
      print('INNTER THEN Setting to returnsvg = ${val.substring(0, 20)}');
      return val;
    }).onError((error, stackTrace) {
      asyncTextVal = 'Exception $error creating INNER ASYNC';
      isComplete = true;
      print(asyncTextVal);
      print(stackTrace);
      return asyncTextVal!;
    });
  }

  @override
  String get textContent {
    if (!isComplete || asyncTextVal == null) {
      return text;
    }
    return asyncTextVal!;
  }
}

class AsyncTranformManager {
  final List<Future<String>> asyncTextNodes = [];

  Future<List<String>> waitForCompletion() {
    print('Here in waitForCompletion() about to WAIT asyncTextNodes.length=${asyncTextNodes.length}');
    return Future.wait(asyncTextNodes);
  }
}
