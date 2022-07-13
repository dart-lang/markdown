import 'package:markdown/markdown.dart';
import 'package:markdown/src/inline_syntaxes/non_breaking_space_syntax.dart';
import 'package:test/test.dart';

void main() {
  test('싱글 달러 인라인 구문 파싱 테스트', () {
    /// MD 다큐먼트 생성
    final document = Document(
      inlineSyntaxes: [
        /// &nbsp 구문 분석기 추가
        NonBreakingSpace(),
      ],
      encodeHtml: false,
    );

    /// 파싱결과
    final result = document.parseInline('안녕&nbsp;하세요');

    expect(result, hasLength(1));
    expect(result.first.textContent, '안녕 하세요');
  });
}
