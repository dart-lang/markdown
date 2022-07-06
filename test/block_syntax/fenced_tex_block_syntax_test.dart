import 'dart:convert';

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('더블 달러 블락 구문 파싱 테스트', () {
    /// MD 다큐먼트 생성
    final document = Document(
      blockSyntaxes: [
        FencedTexBlockSyntax(),
      ],
      encodeHtml: false,
    );
    final data = r'''
$$
\displaystyle \int\_{a}^{b}f\left( x\right)dx=\left[ F\left( x\right)\right]\_{a}^{b}=F\left( b\right)-F\left( a\right)
$$
$a$
''';

    /// 문장 쪼개기
    final lines = LineSplitter.split(data).toList();

    /// 파싱하기
    final nodes = BlockParser(lines, document).parseLines();

    expect(nodes, hasLength(2));

    expect(
      nodes[0],
      TypeMatcher<Element>()
          .having(
            (e) => e.textContent,
            r'$$ 블락 분석기에 걸러진 문자',
            equals(
                r'\displaystyle \int\_{a}^{b}f\left( x\right)dx=\left[ F\left( x\right)\right]\_{a}^{b}=F\left( b\right)-F\left( a\right)'),
          )
          .having(
            (e) => e.tag,
            '태그',
            'texblock',
          ),
    );

    expect(
      nodes[1],
      TypeMatcher<Element>()
          .having(
            (e) => e.textContent,
            r'$$ 블락 분석기에 걸러지지 않은 문자',
            equals(r'$a$'),
          )
          .having(
            (e) => e.tag,
            '태그',
            'p',
          ),
    );
  });
}
