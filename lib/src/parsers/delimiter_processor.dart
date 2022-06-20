// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_syntaxes/delimiter_syntax.dart';
import '../inline_syntaxes/link_syntax.dart';
import 'inline_parser.dart';

class DelimiterProcessor {
  final InlineParser _parser;

  /// The tree of parsed HTML nodes.
  final List<Node> _tree;

  /// The delimiter stack tracking possible opening delimiters and closing
  /// delimiters for [DelimiterSyntax] nodes.
  final _delimiterStack = <Delimiter>[];

  DelimiterProcessor(InlineParser parser, List<Node> tree)
      : _parser = parser,
        _tree = tree;

  /// Push [delimiter] onto the stack of [Delimiter]s.
  void pushDelimiter(Delimiter delimiter) => _delimiterStack.add(delimiter);

  /// Look back through the delimiter stack to see if we've found a link or
  /// image.
  ///
  /// This is the "look for link or image" routine from the CommonMark spec:
  /// https://spec.commonmark.org/0.29/#-look-for-link-or-image-.
  bool buildLinkOrImage() {
    final index = _delimiterStack
        .lastIndexWhere((d) => d.char == $lbracket || d.char == $exclamation);
    if (index == -1) {
      // Never found a possible open bracket. This is just a literal "]".
      _parser.advance();
      return false;
    }
    final delimiter = _delimiterStack[index] as SimpleDelimiter;
    if (!delimiter.isActive) {
      _delimiterStack.removeAt(index);
      _parser.advance();
      return false;
    }
    final syntax = delimiter.syntax;
    if (syntax is LinkSyntax) {
      final nodeIndex = _tree.lastIndexWhere((n) => n == delimiter.node);

      final linkNode = syntax.close(
        _parser,
        delimiter.startPosition,
        openMarker: delimiter.node,
        closeMarker: _parser.spanAt(),
        getChildren: () {
          processDelimiterRun(index);
          // All of the nodes which lie past [index] are children of this
          // link/image.
          final children = _tree.sublist(nodeIndex + 1, _tree.length);
          _tree.removeRange(nodeIndex + 1, _tree.length);
          return children;
        },
      );
      if (linkNode != null) {
        _delimiterStack.removeAt(index);
        if (delimiter.char == $lbracket) {
          for (final d in _delimiterStack.sublist(0, index)) {
            if (d.char == $lbracket) d.isActive = false;
          }
        }
        _tree[nodeIndex] = linkNode;
        return true;
      } else {
        _delimiterStack.removeAt(index);
        return false;
      }
    } else {
      throw StateError('Non-link syntax delimiter found with character '
          '"${delimiter.char}"');
    }
  }

  int _findOpenerIndex(Delimiter closer, int indicatorSum, int start) {
    return _delimiterStack.lastIndexWhere((delimiter) {
      if (delimiter is! DelimiterRun ||
          delimiter.char != closer.char ||
          !delimiter.canOpen) {
        return false;
      }

      // Rules 9 and 10.
      if (!(delimiter.canOpen && delimiter.canClose) &&
          !(closer.canOpen && closer.canClose)) {
        return true;
      }

      return (delimiter.length + closer.length) % indicatorSum != 0 ||
          (delimiter.length % indicatorSum == 0 &&
              closer.length % indicatorSum == 0);
    }, start);
  }

  /// Processes [DelimiterRun] type delimiters from [stackBottom] and up.
  // The strategy of processing emphasis, see
  // https://spec.commonmark.org/0.30/#process-emphasis.
  // Here we have enhanced it to support not only _emphasis_ and
  // _strong emphasis_, but all the syntaxes with [DelimiterRun].
  void processDelimiterRun(int stackBottom) {
    var stackPosition = stackBottom + 1;
    // If _N_ is the total indicators of a `DelimiterSyntax` instance (For
    // example the emphasis with delimitor `*`, there are two tags:
    // `DelimiterTag('emphasis', 1)` and `DelimiterTag('strongEmphasis', 2)`,
    // So the _N_ is `1 + 2 = 3`).
    // Track the lowest index where we might find an open delimiter given a
    // closing delimiter length modulo _N_.
    // Each key in this map is an open delimiter character. Each value is a
    // element list of _N_ length. Each value in the list is the lowest index
    // for the given delimiter length modulo _N_(1, 2, 3, ..., N).
    final openersBottom = <int, List<int>>{};
    while (stackPosition < _delimiterStack.length) {
      final closer = _delimiterStack[stackPosition];
      if (!closer.canClose || closer is! DelimiterRun) {
        stackPosition++;
        continue;
      }

      final indicatorSum = closer.tags
          .map<int>((m) => m.indicatorLength)
          .reduce((a, b) => a + b);

      final openerIndex =
          _findOpenerIndex(closer, indicatorSum, stackPosition - 1);

      if (openerIndex == -1) {
        stackPosition++;
        continue;
      }

      openersBottom.putIfAbsent(
        closer.char,
        () => List.filled(indicatorSum, stackBottom),
      );
      final openerBottoms = openersBottom[closer.char]!;
      final openerBottom = openerBottoms[closer.length % indicatorSum];

      if (openerIndex > stackBottom && openerIndex > openerBottom) {
        // Found an opener for [closer].
        final opener = _delimiterStack[openerIndex] as DelimiterRun;
        final matchedTagIndex = opener.tags.lastIndexWhere((e) =>
            opener.length >= e.indicatorLength &&
            closer.length >= e.indicatorLength);

        if (matchedTagIndex == -1) {
          stackPosition++;
          continue;
        }

        final matchedTag = opener.tags[matchedTagIndex];
        final indicatorLength = matchedTag.indicatorLength;
        final openerTextNode = opener.node;
        final closerTextNode = closer.node;
        var openerTreeIndex = _tree.indexOf(openerTextNode);
        var closerTreeIndex = _tree.indexOf(closerTextNode);
        var openMarker = openerTextNode;
        var closeMarker = openerTextNode;

        _delimiterStack.removeRange(openerIndex + 1, stackPosition);
        // Slide [stackPosition] back accordingly.
        stackPosition = openerIndex + 1;

        // Remove delimiter characters, possibly removing nodes from the tree
        // and Delimiters from the delimiter stack.
        if (opener.length == indicatorLength) {
          _tree.removeAt(openerTreeIndex);
          _delimiterStack.removeAt(openerIndex);
          // Slide [stackPosition] and [closerTreeIndex] back accordingly.
          stackPosition--;
          closerTreeIndex--;
          openerTreeIndex--;
        } else {
          final exceeded = openerTextNode.length - indicatorLength;
          final newOpenerTextNode = openerTextNode.subText(0, exceeded);
          _tree[openerTreeIndex] = newOpenerTextNode;
          opener.node = newOpenerTextNode;
          openMarker = openerTextNode.subText(exceeded);
        }

        if (closer.length == indicatorLength) {
          _tree.removeAt(closerTreeIndex);
          _delimiterStack.removeAt(stackPosition);
          // [stackPosition] has just moved to point at the next delimiter;
          // leave it.
        } else {
          final newCloserTextNode = closerTextNode.subText(indicatorLength);
          _tree[closerTreeIndex] = newCloserTextNode;
          closer.node = newCloserTextNode;
          closeMarker = openerTextNode.subText(0, indicatorLength);
        }

        final node = opener.syntax.close(
          _parser,
          opener.startPosition,
          type: matchedTag.type,
          openMarker: openMarker,
          closeMarker: closeMarker,
          getChildren: () => _tree.sublist(
            openerTreeIndex + 1,
            closerTreeIndex,
          ),
        )!;

        // Replace all of the nodes between the opener and the closer (which
        // are now the new emphasis node's children) with the emphasis node.
        _tree.replaceRange(openerTreeIndex + 1, closerTreeIndex, [node]);
      } else {
        // No opener is found.
        openerBottoms[closer.length % indicatorSum] = stackPosition - 1;
        if (!closer.canOpen) {
          _delimiterStack.removeAt(stackPosition);
          // This advances [stackPosition] to the next delimiter.
        } else {
          stackPosition++;
        }
      }
    }

    _delimiterStack.removeRange(stackBottom + 1, _delimiterStack.length);
  }
}
