import 'delimiter_syntax.dart';

@Deprecated('Use DelimiterSyntax instead')
class TagSyntax extends DelimiterSyntax {
  TagSyntax(String pattern, {bool requiresDelimiterRun = false})
      : super(pattern, requiresDelimiterRun: requiresDelimiterRun);
}
