import 'package:markdown/markdown.dart';

class UnderlineInlineSyntax extends InlineSyntax {
  UnderlineInlineSyntax() : super('<u>(.*?)</u>');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final hasMatch = match.groupCount > 0;
    if (hasMatch) {
      /// 매칭 문자열
      final matchedString = match.group(1)!;

      /// Element tex 태그 부착
      parser.addNode(
        Element.text(
          'u',
          matchedString,
        ),
      );
    }
    return hasMatch;
  }
}
