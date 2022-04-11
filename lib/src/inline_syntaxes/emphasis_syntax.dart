import 'delimiter_syntax.dart';

class EmphasisSyntax extends DelimiterSyntax {
  /// Parses `__strong__` and `_emphasis_`.
  EmphasisSyntax.underscore()
      : super('_+', requiresDelimiterRun: true, tags: _tags);

  /// Parses `**strong**` and `*emphasis*`.
  EmphasisSyntax.asterisk()
      : super(
          r'\*+',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          tags: _tags,
        );

  static final _tags = [DelimiterTag('em', 1), DelimiterTag('strong', 2)];
}
