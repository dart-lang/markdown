import 'delimiter_syntax.dart';

/// Matches strikethrough syntax according to the GFM spec.
class StrikethroughSyntax extends DelimiterSyntax {
  StrikethroughSyntax()
      : super(
          '~+',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          tags: [DelimiterTag('del', 2)],
        );
}
