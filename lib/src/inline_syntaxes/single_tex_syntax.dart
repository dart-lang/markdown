import '../ast.dart';
import '../inline_parser.dart';
import 'inline_syntax.dart';

/// 텍스 인라인 구문 분석기
class SingleTexInlineSyntex extends InlineSyntax {
  /// 텍스 인라인 구문 분석기 초기화
  SingleTexInlineSyntex() : super(r'\$(.*?)\$');

  /// 구문 분석기의 조건에 만족할 때 처리 함수
  @override
  bool onMatch(InlineParser parser, Match match) {
    final hasMatch = match.groupCount > 0;

    if (hasMatch) {
      /// 매칭 문자열
      final matchedString = match.group(1)!;

      /// Element tex 태그 부착
      parser.addNode(
        Element.text(
          'tex',
          matchedString,
        ),
      );
    }
    return hasMatch;
  }
}
