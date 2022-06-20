import 'package:source_span/source_span.dart';

import '../charcode.dart';

class SourceParser {
  /// The [source] is a list of the segments of Markdown string. A segment does
  /// not mean a line of string, it does not matter if a segment is a single or
  /// multiple lines of string, also multiple segments may belong to the same
  /// line of string.
  final List<SourceSpan> source;

  final String _sourceText;

  int get length => _sourceText.length;

  /// The current read position, the offset against the start of [_sourceText].
  var _position = 0;
  int get position => _position;

  /// The end [_Coordinate]. (which is not actually in the source)
  late final _Coordinate _endCoordinate;

  /// If the source is ending up with a line feed.
  final bool _endsWithLf;

  SourceParser(List<SourceSpan> source)
      : source = List<SourceSpan>.unmodifiable(source),
        _sourceText = source.map((e) => e.text).join(),
        _endsWithLf = source.isNotEmpty &&
            source.last.length > 0 &&
            source.last.text.endsWith('\n') {
    _endCoordinate = _endsWithLf || source.isEmpty
        ? _Coordinate(source.length, 0)
        : _Coordinate(source.length - 1, source.last.length);
  }

  /// Returns a list of spans from [start] (inclusive) to [end] (exclusive).
  List<SourceSpan> subspan(int start, [int? end]) {
    if (end != null && start == end) {
      return [];
    }

    final from = _toCoordinate(start);
    final to = end == null ? _endCoordinate : _toCoordinate(end);

    if (from.index == to.index) {
      return [
        source[from.index].subspan(from.offset, to.offset),
      ];
    }

    final segments = [source[from.index].subspan(from.offset)];

    if (to == _endCoordinate) {
      segments.addAll(source.getRange(
        from.index + 1,
        _endCoordinate.index + (_endsWithLf ? 0 : 1),
      ));
    } else {
      for (var i = from.index + 1; i < to.index; i++) {
        segments.add(source[i]);
      }
      if (to.offset != 0) {
        segments.add(source[to.index].subspan(0, to.offset));
      }
    }

    return segments;
  }

  /// Substrings the [_sourceText] and returns a [String].
  ///
  /// Note that, this string result can not be used to create any AST [Text],
  /// as the [SourceLocation] information is missing.
  String substring(int start, [int? end]) => _sourceText.substring(start, end);

  List<SourceSpan> consumeBy(int length) {
    final spans = subspan(position, position + length);
    advanceBy(length);
    return spans;
  }

  SourceSpan consume() => consumeBy(1).first;

  bool get isDone => _position == length;

  /// Moves the read position for [length] characters. [length] can be negative.
  void advanceBy(int length) {
    _position += length;
  }

  /// Moves the read position one character ahead.
  void advance() => advanceBy(1);

  /// Converts a int type [position] to a [_Coordinate].
  _Coordinate _toCoordinate([int? position]) {
    position ??= _position;

    if (position == length) {
      return _endCoordinate;
    }

    var offset = 0;
    for (var i = 0; i < source.length; i++) {
      final segment = source[i];
      offset += segment.length;
      if (offset == position) {
        return _Coordinate(i + 1, 0);
      } else if (offset > position) {
        return _Coordinate(i, segment.length - (offset - position));
      }
    }

    throw ArgumentError(
      'Postion: $position is not in inclusive range 0..$length.',
    );
  }

  /// Creates an empty SourceSpan from [position]
  SourceSpan emptySpan([int? position]) {
    position ??= _position;
    final location = toSourceLocation(position);
    return SourceSpan(location, location, '');
  }

  /// The [position] can not be the end position which is not actually in the
  /// source.
  int charAt([int? position]) => _sourceText.codeUnitAt(position ?? _position);

  /// The same as [charAt] but returns a string.
  String stringAt([int? position]) => _sourceText[position ?? _position];

  /// Returns a `SourceSpan` at [position].
  SourceSpan spanAt([int? position]) {
    position ??= _position;
    return subspan(position, position + 1).first;
  }

  int? nextChar([int? position]) {
    position = (position ?? _position) + 1;
    if (position == length) {
      return null;
    }
    return charAt(position);
  }

  String? nextString([int? position]) {
    position = (position ?? _position) + 1;
    if (position == length) {
      return null;
    }
    return stringAt(position);
  }

  /// Converts a [position] to [SourceLocation].
  /// If the [coordinate] is the end position which is not actually in the
  /// source, it will return the end location which is not actually in the
  /// source too.
  SourceLocation toSourceLocation([int? position]) {
    final coordinate = _toCoordinate(position);

    if (coordinate == _endCoordinate) {
      return source.last.end;
    }

    final segment = source[coordinate.index];
    final text = segment.text.substring(0, coordinate.offset + 1);
    final lines = text.split(RegExp('(?<=\n)'));

    return SourceLocation(
      segment.start.offset + coordinate.offset,
      line: segment.start.line + lines.length - 1,
      column: lines.length == 1
          ? segment.start.column + lines.first.length - 1
          : lines.last.length - 1,
    );
  }

  Match? matchFromStart(RegExp pattern, [int start = 0]) =>
      pattern.matchAsPrefix(_sourceText, start);

  /// Walk the parser forward through any whitespace.
  ///
  /// Set [multiLine] `true` to support multiline, otherwise it will stop before
  /// the line feed [$lf].
  int moveThroughWhitespace({bool multiLine = false}) {
    var i = 0;
    while (!isDone) {
      final char = charAt();
      if (char != $space &&
          char != $tab &&
          char != $vt &&
          char != $cr &&
          char != $ff &&
          !(multiLine == true && char == $lf)) {
        return i;
      }
      i++;
      advance();
    }
    return i;
  }
}

/// [_Coordinate] indicates a position in a [SourceSpan] list.
/// For example,
/// ```
/// [
///   SourceSpan('abc'),
///   SourceSpan('defg')
/// ]
/// ```
/// the [_Coordinate] of "e" is `_Coordinate(1, 1)`
class _Coordinate {
  /// The index of a [SourceSpan] list
  final int index;

  /// The offset of current [SourceSpan]
  final int offset;

  const _Coordinate(this.index, this.offset);

  /// checks if the current position is at [other].
  @override
  bool operator ==(other) =>
      other is _Coordinate && other.index == index && other.offset == offset;

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  int get hashCode => offset.hashCode + index.hashCode;

  Map<String, int> toMap() => {'index': index, 'offset': offset};
}
