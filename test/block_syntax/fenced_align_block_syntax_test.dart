import 'dart:convert';

import 'package:markdown/markdown.dart';
import 'package:markdown/src/block_syntaxes/fenced_align_block_syntax.dart';
import 'package:test/test.dart';

void main() {
  late final Document document;

  setUpAll(() {
    document = Document(
      blockSyntaxes: [
        FencedAlignBlockSyntax(),
      ],
      encodeHtml: false,
    );
  });

  group('정렬 블락 구문 파싱', () {
    /// GIVEN: 박스{:::right} 블록 속 텍스트{박스 내부} 데이터를 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출 된다
    ///       블록의 하위 노드수는 1개 이다
    ///       블록의 태그는 'boxedblock' 이다
    ///       블록의 하위 노드의 내용은 '박스 내부' 이다.
    test('박스 블락 구문 파싱 테스트', () {
      /// MD 다큐먼트 생성

      final data = ''':::right\n박스 내부\n:::''';

      /// 문장 쪼개기
      final lines = LineSplitter.split(data).toList();

      /// 파싱하기
      final nodes = BlockParser(lines, document).parseLines();

      /// ::: 블록 갯수 1개
      expect(nodes, hasLength(1));

      /// 블록 엘리먼트 태그, 하위 노드 수 확인
      expect(
        nodes.first,
        TypeMatcher<Element>()
            .having(
              (e) => e.tag,
              '태그',
              'alignment',
            )
            .having(
              (e) => e.children,
              '블록 하위 노드 수',
              hasLength(1),
            )
            .having(
              (e) => e.attributes['align'],
              '정렬',
              'right',
            ),
      );

      /// 하위 노드
      final children = (nodes.first as Element).children;

      /// 첫번째 하위노드 태그 및 텍스트 확인
      expect(
        children?.first,
        TypeMatcher<Element>()
            .having(
              (e) => e.tag,
              '태그',
              'p',
            )
            .having(
              (e) => e.attributes['label'],
              'label 속성',
              null,
            )
            .having(
              (e) => e.textContent,
              '내용',
              '박스 내부',
            ),
      );
    });
  });
}
