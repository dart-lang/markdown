import '../inline_parser.dart';
import '../util.dart';

/// Represents one kind of Markdown tag that can be parsed.
abstract class InlineSyntax {
  /// Create a new [InlineSyntax] which matches text on [pattern].
  ///
  /// If [startCharacter] is passed, it is used as a pre-matching check which
  /// is faster than matching against [pattern].
  InlineSyntax(String pattern, {int? startCharacter})
      : pattern = RegExp(pattern, multiLine: true),
        _startCharacter = startCharacter;

  final RegExp pattern;

  /// The first character of [pattern], to be used as an efficient first check
  /// that this syntax matches the current parser position.
  final int? _startCharacter;

  /// Tries to match at the parser's current position.
  ///
  /// The parser's position can be overriden with [startMatchPos].
  /// Returns whether or not the pattern successfully matched.
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;

    // Before matching with the regular expression [pattern], which can be
    // expensive on some platforms, check if even the first character matches
    // this syntax.
    if (_startCharacter != null &&
        parser.source.codeUnitAt(startMatchPos) != _startCharacter) {
      return false;
    }

    final startMatch = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (startMatch == null) return false;

    // Write any existing plain text up to this point.
    parser.writeText();

    if (onMatch(parser, startMatch)) parser.consume(startMatch.match.length);
    return true;
  }

  /// Processes [match], adding nodes to [parser] and possibly advancing
  /// [parser].
  ///
  /// Returns whether the caller should advance [parser] by `match[0].length`.
  bool onMatch(InlineParser parser, Match match);
}
