import 'dart:convert';
import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  late Document document;
  setUp(() {
    document = Document(
      blockSyntaxes: [
        HeaderSyntax(),
      ],
      encodeHtml: false,
    );
  });

  group('코드 인라인 구문', () {
    /// GVIEN: 데이터{`①` $f(x)$ 의 값이 한없이 커지는 경우}가 주어졌다
    /// WHEN: 구문 분석을 통해 코드 구문을 파싱하려고한다
    /// THEN: 추출된 AST 노드가 2개 이다
    ///       태그가 'code'인 노드는 1개 이다
    ///       태그가 'code'인 노드는 엘리먼트이며 텍스트는 '①' 이다
    test('일반적인 데이터 파싱', () {
      final data = r'`①` $f(x)$ 의 값이 한없이 커지는 경우';

      /// 파싱결과
      final result = document.parseInline(data);

      expect(result, hasLength(2));

      final codeElements = result
          .where((element) => element is Element && element.tag == 'code')
          .toList();

      expect(codeElements, hasLength(1));

      expect(
        codeElements.first,
        TypeMatcher<Element>().having(
          (e) => e.textContent,
          '텍스트',
          '①',
        ),
      );
    });

    /// GVIEN: 데이터{### **1.** `OXXX`}가 주어졌다
    /// WHEN: 구문 분석을 통해 코드 구문을 파싱하려고한다
    /// THEN: 추출된 최상위 노드가 1개 이다
    ///       최상위 노드는 엘리먼트이며 태그는 'h3' 이다
    ///       태그가 'code'인 노드는 1개 이다
    ///       태그가 'code'인 노드는 엘리먼트이며 텍스트는 '●○○○' 이다
    test('난이도와 함께 주어진 데이터 파싱', () {
      final data = '### **1.** `OXXX`';

      final lines = LineSplitter().convert(data).toList();

      /// 파싱결과
      final nodes = document.parseLines(lines);

      expect(nodes, hasLength(1));

      final topNode = nodes.first;

      expect(
        topNode,
        TypeMatcher<Element>().having(
          (e) => e.tag,
          '태그',
          'h3',
        ),
      );

      final codeElements = (topNode as Element)
          .children
          ?.where((element) => element is Element && element.tag == 'code')
          .toList();

      expect(codeElements, hasLength(1));

      expect(
        codeElements?.first,
        TypeMatcher<Element>().having(
          (e) => e.textContent,
          '텍스트',
          '●○○○',
        ),
      );
    });
  });
}
