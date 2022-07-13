import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('첨자(StrongCode) 인라인 구문 파싱 테스트', () {
    /// MD 다큐먼트 생성
    final document = Document(
      inlineSyntaxes: [
        /// **``** 구문 분석기 추가
        StrongCodeInlineSyntax(),
      ],
    );

    /// 파싱결과
    final result = document.parseInline('Text**`StrongCode`**');

    expect(result, hasLength(2));

    expect(
      result[0],
      TypeMatcher<Text>().having(
        (e) => e.textContent,
        '**``** 구문 분석기에 걸러지지 않은 문자',
        equals('Text'),
      ),
    );

    expect(
      result[1],
      TypeMatcher<Element>()
          .having(
            (e) => e.textContent,
            '**``** 구문 분석기에 걸러진 문자',
            equals('StrongCode'),
          )
          .having(
            (e) => e.tag,
            '태그',
            'strongcode',
          ),
    );
  });
}
