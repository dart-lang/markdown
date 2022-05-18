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

  AsyncText(this.parser,
      {String initialPendingTextMessage = 'uncompleted future'})
      : super(initialPendingTextMessage) {
    parentDoc = parser.document as AsyncDocument;
  }

//KLUDGE just here to shut up warning of not using _asyncFutureText
  Future<String> get asyncFutureText {
    return _asyncFutureText!;
  }
  
  set asyncFutureText(Future<String> theFuture) {
    _asyncFutureText = theFuture;
    parentDoc.asyncTransformManager.asyncTextNodes.add(theFuture);
    parentDoc.asyncTransformManager.nodesWithUncompletedAsyncTransforms
        .add(this);

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
  // By default wait a maximum of 60 seconds for all transforms to complete.
  static const int defaultTimeoutInSeconds = 60;
  bool uncompletedAsyncTransforms = false;

  final List<Future<String>> asyncTextNodes = [];
  final List<Node> nodesWithUncompletedAsyncTransforms = [];

  bool get waitingOnUncompletedNodes =>
      nodesWithUncompletedAsyncTransforms.isNotEmpty;

  void trackNodeWaitingOnAsyncTransform(Node nodeWaitingOnTransform) {
    if (!nodesWithUncompletedAsyncTransforms.contains(nodeWaitingOnTransform)) {
      nodesWithUncompletedAsyncTransforms.add(nodeWaitingOnTransform);
    }
  }

  void nodeCompleted(Node completedNode) {
    nodesWithUncompletedAsyncTransforms.remove(completedNode);
  }

  Future<List<String>> waitForCompletion(
      /*uration? maximumTimeToWaitForCompletion*/) {
    return Future.wait(asyncTextNodes);

    // bool timeHasRunnout = false;

    // Timer(maximumTimeToWaitForCompletion ?? Duration(seconds:defaultTimeoutInSeconds),
    //  () => timeHasRunnout=true );

    // while(!timeHasRunnout) {
    //   Timer.sleep(Duration(milliseconds:100));
    // }

    // checkOnCompletion() {
    // print('Checking bookmarks');
    // if(checkAllBookmarks()) {
    //   print('Done -fixing up');
    //   bookmarkedHtml = DumpBookmarks(bookmarkedHtml);
    //   htmlDiv.setInnerHtml(
    //     bookmarkedHtml,
    //     treeSanitizer: nullSanitizer,
    //   );
    // } else {
    //   Timer(Duration(milliseconds:250),CheckAndFileBookmarks);
    // }
  }
}
