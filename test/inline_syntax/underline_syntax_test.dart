import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('Underline 인라인 구문 파싱 테스트', () {
    /// MD 다큐먼트 생성
    final document = Document(
      inlineSyntaxes: [
        /// <u></u> 구문 분석기 추가
        UnderlineInlineSyntax(),
      ],
    );

    /// 파싱결과
    final result = document.parseInline('Text<u>Underline</u>');

    expect(result, hasLength(2));

    expect(
      result[0],
      TypeMatcher<Text>().having(
        (e) => e.textContent,
        '<u></u> 구문 분석기에 걸러지지 않은 문자',
        equals('Text'),
      ),
    );

    expect(
      result[1],
      TypeMatcher<Element>()
          .having(
            (e) => e.textContent,
            '<u></u> 구문 분석기에 걸러진 문자',
            equals('Underline'),
          )
          .having(
            (e) => e.tag,
            '태그',
            'u',
          ),
    );
  });
}
