import 'package:markdown/src/ast.dart';
import 'package:markdown/src/inline_parser.dart';
import 'package:markdown/src/inline_syntaxes/inline_syntax.dart';

class SubInlineSyntax extends InlineSyntax {
  SubInlineSyntax() : super('<sub>(.*?)</sub>');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final hasMatch = match.groupCount > 0;
    if (hasMatch) {
      /// 매칭 문자열
      final matchedString = match.group(1)!;

      /// Element tex 태그 부착
      parser.addNode(
        Element.text(
          'sub',
          matchedString,
        ),
      );
    }
    return hasMatch;
  }
}
