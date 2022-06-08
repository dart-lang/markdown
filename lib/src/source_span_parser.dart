import 'package:source_span/source_span.dart';

import 'charcode.dart';
import 'util.dart';

class SourceSpanParser {
  /// The [source] is a list of the segments of Markdown string. A segment does
  /// not mean a line of string, it does not matter if a segment is a single or
  /// multiple lines of string, also multiple segments may belong to the same
  /// line of string.
  final List<SourceSpan> source;

  final String _sourceText;

  /// The current read position.
  var _position = SourcePosition(0, 0);
  SourcePosition get position => _position;

  /// The ending position, which is not actually in the source.
  late final SourcePosition _end;

  /// The final char of [source]
  final int? _lastChar;

  SourceSpanParser(this.source)
      : _sourceText = source.map((e) => e.text).join(),
        _lastChar = source.isEmpty || source.last.length == 0
            ? null
            : source.last.text.codeUnitAt(source.last.length - 1) {
    _end = _lastChar == $lf || source.isEmpty
        ? SourcePosition(source.length, 0)
        : SourcePosition(source.length - 1, source.last.length);
  }

  /// Returns a list of spans from [start] (inclusive) to [end] (exclusive).
  List<SourceSpan> subText(SourcePosition start, [SourcePosition? end]) {
    end ??= _end;
    if (start == end) {
      return [];
    }

    if (start.index == end.index) {
      return [
        source[start.index].subspan(start.offset, end.offset),
      ];
    }

    final segments = [source[start.index].subspan(start.offset)];

    if (end == _end) {
      segments.addAll(source.getRange(start.index + 1, _end.index));
    } else {
      for (var i = start.index + 1; i < end.index; i++) {
        segments.add(source[i]);
      }
      if (end.offset != 0) {
        segments.add(source[end.index].subspan(0, end.offset));
      }
    }

    return segments;
  }

  //
  bool get isDone => isEndingPosition(_position);

  bool isEndingPosition(SourcePosition position) {
    _checkValidPosition(position);
    return position == _end;
  }

  void _checkValidPosition(SourcePosition position) {
    if (position == _end) {
      return;
    }

    if (position.index > _end.index) {
      throw ArgumentError(
        'Index of $position must be less than ${_end.index + 1}',
      );
    }

    if (position.offset >= source[position.index].length) {
      throw ArgumentError(
        'Offset of $position must be less than ${source[position.index].length}',
      );
    }
  }

  // TODO(Zhiguang): Add Backslash escapes handler, how about advance 2 times
  // when meet a \?

  /// Moves the read position for [length] characters. [length] can be negative.
  void advanceBy(int length) {
    _position = offsetPosition(_position, length);
  }

  /// Moves the read position one character ahead.
  void advance() => advanceBy(1);

  /// Gets a new [SourcePosition] by the [offset] from [from]
  SourcePosition offsetPosition(SourcePosition from, int offset) {
    final segment = source[from.index];
    var newIndex = from.index;
    var newOffset = from.offset + offset;

    if (newOffset < 0) {
      offset += from.offset;
      while (newIndex-- > 0) {
        offset += source[newIndex].length;
        if (offset >= 0) {
          newOffset = offset.abs();
          break;
        }
      }
    } else if (newOffset >= segment.length) {
      offset -= segment.length - 1 - from.offset;
      while (newIndex++ < source.length) {
        if (newIndex == source.length && offset == 1) {
          if (_lastChar == $lf) {
            newOffset = 0;
          } else {
            newIndex -= 1;
            newOffset = source.last.length;
          }

          break;
        }

        final length = source[newIndex].length;
        if (source.length - newIndex == 1 && offset - length == 1) {
          newOffset = length;
          break;
        }

        offset -= length;
        if (offset <= 0) {
          newOffset = offset + length - 1;
          break;
        }
      }
    }

    return SourcePosition(newIndex, newOffset);
  }

  /// Create an empty SourceSpan from [position]
  SourceSpan emptySpan([SourcePosition? position]) {
    position ??= _position;
    final location = positionToLocation(position);
    return SourceSpan(location, location, '');
  }

  /// The [position] can not be the end position which is not actually in the
  /// source.
  int charAt([SourcePosition? position]) {
    position ??= _position;
    final segment = source[position.index];
    return segment.text.codeUnitAt(position.offset);
  }

  /// The same as [charAt] but returns a string.
  String? stringAt([SourcePosition? position]) =>
      String.fromCharCode(charAt(position));

  /// Returns a `SourceSpan` at [position].
  SourceSpan spanAt([SourcePosition? position]) {
    position ??= _position;
    return subText(position, offsetPosition(position, 1)).first;
  }

  int? nextChar([SourcePosition? position]) {
    if (isDone) {
      return null;
    }
    return charAt(offsetPosition(position ?? _position, 1));
  }

  /// If the [position] is the end position which is not actually in the source,
  /// it will return the end location which is not actually in the source too.
  SourceLocation positionToLocation([SourcePosition? position]) {
    position ??= _position;

    if (isEndingPosition(position)) {
      return source.last.end;
    }

    final segment = source[position.index];
    final text = segment.text.substring(0, position.offset + 1);
    final lines = text.split(RegExp('(?<=\n)'));

    return SourceLocation(
      segment.start.offset + position.offset,
      line: segment.start.line + lines.length - 1,
      column: lines.length == 1
          ? segment.start.column + lines.first.length - 1
          : lines.last.length - 1,
    );
  }

  List<List<SourceSpan>> matchFromStart(
    RegExp pattern, [
    SourcePosition start = const SourcePosition(0, 0),
  ]) {
    final offset = positionToOffset(start);
    final match = pattern.matchAsPrefix(_sourceText, offset);

    if (match == null) {
      return [];
    }

    final result = <List<SourceSpan>>[];
    final groups = toGroupsWithIndex(match);

    for (var i = 0; i < groups.length; i++) {
      final current = groups[i]!;
      result.add(subText(
        offsetPosition(start, current.start - offset),
        offsetPosition(start, current.end - offset),
      ));
    }

    return result;
  }

  /// Converts [position] to an offset which is against the start of [source].
  int positionToOffset(SourcePosition position) {
    var endIndex = position.index;

    if (position != _end || _lastChar != $lf) {
      endIndex += 1;
    }

    var offset = 0;
    for (var i = 0; i < endIndex - 1; i++) {
      offset += source[i].length;
    }
    offset += position.offset;
    return offset;
  }

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

/// [SourcePosition] indicates a location in a [SourceSpan] list.
class SourcePosition {
  /// The index of a [SourceSpan] list
  final int index;

  /// The offset of current [SourceSpan]
  final int offset;

  const SourcePosition(this.index, this.offset);

  /// checks if the current position is at [other].
  @override
  bool operator ==(other) =>
      other is SourcePosition && other.index == index && other.offset == offset;

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  int get hashCode => offset.hashCode + index.hashCode;

  Map<String, int> toMap() => {'index': index, 'offset': offset};
}
