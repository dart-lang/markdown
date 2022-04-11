import 'delimiter_syntax.dart';

/// Parses `==mark==` to `<mark>mark</mark>`.
//
// This syntax uses the same spec as the double asterisks(*) form strong
// emphasis: https://spec.commonmark.org/0.30/#emphasis-and-strong-emphasis
class HighlightSyntax extends DelimiterSyntax {
  HighlightSyntax()
      : super(
          '=+',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          tags: [DelimiterTag('mark', 2)],
        );
}
