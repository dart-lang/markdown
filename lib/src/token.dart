import 'package:source_span/source_span.dart';

import 'util.dart';

class Token extends SourceSpanBase {
  final Map<String, String> attributes;

  Token(
    String text, {
    required SourceLocation start,
    required SourceLocation end,
    this.attributes = const {},
  }) : super(start, end, text);

  /// Instantiates a [Token] from [span].
  Token.fromSpan(
    SourceSpan span, {
    this.attributes = const {},
  }) : super(span.start, span.end, span.text);

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

  Token _subspanFromString(String string) {
    final index = text.indexOf(string);
    final span = subspan(index, index + string.length);
    return Token(string, start: span.start, end: span.end);
  }

  /// Trims [text] and update [start] and [end].
  Token trim() => _subspanFromString(text.trim());

  /// As [trim], but only removes leading whitespace.
  Token trimLeft() => _subspanFromString(text.trimLeft());

  /// As [trim], but only removes trailing whitespace.
  Token trimRight() => _subspanFromString(text.trimRight());

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

Map<String, int> _sourceLocationToMap(SourceLocation location) => {
      'line': location.line,
      'column': location.column,
      'offset': location.offset,
    };

/// [offset] is the starting offset of the string being parsed.
List<Token> parseTokensFromMatch(
  Match match, {
  required int offset,
  required int line,
  String? text,
}) {
  final groupCount = match.groupCount;
  final List<String> keys = [];
  text ??= match.match;

  if (groupCount == 1) {
    keys.add(text);
  } else {
    for (var i = 0; i < groupCount; i++) {
      keys.add(match[i + 1]!);
    }
  }

  final List<Token> tokens = [];
  for (final key in keys) {
    var indexStart = 0;
    final lastToken = tokens.isEmpty ? null : tokens.last;
    if (lastToken != null) {
      indexStart = lastToken.end.offset - offset;
    }

    tokens.add(Token.create(
      key,
      line: line,
      offset: offset,
      context: text,
      indexStart: indexStart,
    ));
  }

  return tokens;
}
