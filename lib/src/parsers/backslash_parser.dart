// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import '../charcode.dart';
import '../patterns.dart';
import 'source_parser.dart';

class BackslashParser extends SourceParser {
  final bool _outputString;

  BackslashParser(List<SourceSpan> source, {bool outputString = true})
      : _outputString = outputString,
        super(source) {
    _parse();
  }

  /// These backslash work as escape markers.
  final markers = <SourceSpan>[];

  /// The a list of [SourceSpan], which has been stripped off `\`.
  List<SourceSpan> get spans {
    assert(_outputString == false);
    return _spans;
  }

  /// The string result.
  String get text {
    assert(_outputString == true);
    return _text;
  }

  final _spans = <SourceSpan>[];

  String _text = '';

  void _parse() {
    var start = 0;
    StringBuffer? buffer;
    if (_outputString) {
      buffer = StringBuffer();
    }

    while (!isDone) {
      if (charAt() == $backslash) {
        final next = nextString();
        if (next != null && asciiPunctuationCharacters.contains(next)) {
          markers.add(spanAt());
          if (buffer == null) {
            _spans.addAll(subspan(start, position));
          }
          advance();
          start = position;
        }
      }
      if (buffer != null) {
        buffer.write(stringAt());
      }
      advance();
    }

    if (buffer != null) {
      _text = buffer.toString();
    } else if (start != position) {
      _spans.addAll(subspan(start, position));
    }
  }

  /// Escape ASCII punctuation characters from [input].
  ///
  /// This `static` method has nothing to do with [SourceSpan], more efficient
  /// but not able to extract [SourceSpan] type [markers].
  static String parseString(String input) {
    final buffer = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      if (input.codeUnitAt(i) == $backslash) {
        final next = i + 1 < input.length ? input[i + 1] : null;
        if (next != null && asciiPunctuationCharacters.contains(next)) {
          i++;
        }
      }
      buffer.write(input[i]);
    }

    return buffer.toString();
  }
}
