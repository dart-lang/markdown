import 'dart:convert';

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  late final Document document;

  setUpAll(() {
    document = Document(
      blockSyntaxes: [
        FencedLargeBoxBlockSyntax(),
        FencedBoxBlockSyntax(),
      ],
      encodeHtml: false,
    );
  });

  group('박스 블락 구문 파싱', () {
    /// GIVEN: 박스{::::boxed} 블록 속 텍스트{박스 내부} 데이터를 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출 된다
    ///       블록의 태그는 'boxedblock' 이다
    ///       블록의 하위 노드수는 1개 이다
    ///       블록의 하위 노드의 내용은 '박스 내부' 이다.
    test('박스 블락 구문 파싱 테스트', () {
      /// MD 다큐먼트 생성

      final data = '''::::boxed\n박스 내부\n::::''';

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
              'boxedblock',
            )
            .having(
              (e) => e.children,
              '블록 하위 노드 수',
              hasLength(1),
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

    /// GIVEN: 박스{::::boxed} 블록 속 텍스트 데이터{박스 안}를 라벨{라벨}과 함께 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출 된다
    ///       블록의 태그는 'boxedblock'이다
    ///       블록의 라벨은 '라벨'이다
    ///       블록의 하위 노드수는 1개 이다
    ///       블록의 하위 노드의 내용은 '박스 안' 이다.
    test('박스 블락 구문 파싱 테스트 With 라벨', () {
      final data = '''::::boxed[라벨]\n박스 안\n::::''';

      /// 문장 쪼개기
      final lines = LineSplitter.split(data).toList();

      /// 파싱하기
      final nodes = BlockParser(lines, document).parseLines();

      /// ::: 블록 갯수 1개
      expect(nodes, hasLength(1));

      expect(
        nodes.first,
        TypeMatcher<Element>()
            .having((e) => e.tag, '태그', 'boxedblock')
            .having(
              (e) => e.children,
              '블록 하위 노드 수',
              hasLength(1),
            )
            .having(
              (e) => e.attributes,
              'label 속성',
              containsPair('label', '라벨'),
            )
            .having(
              (e) => e.textContent,
              '내용',
              '박스 안',
            ),
      );
    });
  });

  group('체크 블락 구문 파싱', () {
    /// GIVEN: 체크{::::checked} 블록 속 텍스트{박스 내부} 데이터를 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출 된다
    ///       블록의 하위 노드수는 1개 이다
    ///       블록의 태그는 'boxedblock' 이다
    ///       블록의 타입은 'checked' 이다.
    ///       블록의 하위 노드의 내용은 '박스 내부' 이다.
    test('체크 블락 구문 파싱 테스트', () {
      /// MD 다큐먼트 생성

      final data = '''::::checked\n박스 내부\n::::''';

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
              'boxedblock',
            )
            .having(
              (e) => e.attributes,
              '박스타입',
              containsPair(
                'type',
                'checked',
              ),
            )
            .having(
              (e) => e.children,
              '블록 하위 노드 수',
              hasLength(1),
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

    /// GIVEN: 박스{::::checked} 블록 속 텍스트 데이터{박스 안}를 라벨{라벨}과 함께 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출 된다
    ///       블록의 하위 노드수는 1개 이다
    ///       블록의 태그는 'boxedblock'이다
    ///       블록의 타입은 'checked' 이다
    ///       블록의 라벨은 '라벨'이다
    ///       블록의 하위 노드의 내용은 '박스 안' 이다.
    test('체크 블락 구문 파싱 테스트 With 라벨', () {
      final data = '''::::checked[라벨]\n박스 안\n::::''';

      /// 문장 쪼개기
      final lines = LineSplitter.split(data).toList();

      /// 파싱하기
      final nodes = BlockParser(lines, document).parseLines();

      /// ::: 블록 갯수 1개
      expect(nodes, hasLength(1));

      expect(
        nodes.first,
        TypeMatcher<Element>()
            .having((e) => e.tag, '태그', 'boxedblock')
            .having(
              (e) => e.children,
              '블록 하위 노드 수',
              hasLength(1),
            )
            .having(
              (e) => e.attributes,
              'label 속성',
              containsPair('label', '라벨'),
            )
            .having(
              (e) => e.attributes,
              '박스타입',
              containsPair(
                'type',
                'checked',
              ),
            )
            .having(
              (e) => e.textContent,
              '내용',
              '박스 안',
            ),
      );
    });
  });

  group('박스 속 박스', () {
    /// GIVEN: 라벨{Point} 박스{::::boxed} 속 텍스트{박스 속}와 박스{:::boxed}에 텍스트{박스 속 박스} 데이터를 준다
    /// WHEN: 데이터를 분리하기위해 쪼개고 파싱한다
    /// THEN: 블록이 추출된다
    ///       블록의 하위 노드는 2개다
    ///       블록의 태그는 'boxedblock' 이다
    ///       블록의 타입은 'boxed' 이다
    ///       블록의 라벨은 'Point' 이다
    ///       블록의 첫번째 노드는 엘리먼트 다
    ///       첫번째 노드의 태그는 'p' 다
    ///       첫번째 노드의 텍스트는 '박스 속' 이다
    ///       블록의 두번째 노드는 엘리먼트 다
    test('박스 블록 속 박스 블록', () {
      final data = '::::boxed[Point]\n박스 속\n:::boxed\n박스 속 박스\n:::\n::::';

      final lines = LineSplitter.split(data).toList();
      final nodes = BlockParser(lines, document).parseLines();
      expect(nodes.isNotEmpty, true);

      final outerBlock = nodes.first;

      expect(
        outerBlock,
        TypeMatcher<Element>()
            .having(
              (e) => e.children,
              '하위 노드 수',
              hasLength(2),
            )
            .having(
              (e) => e.tag,
              '태그',
              'boxedblock',
            )
            .having(
              (e) => e.attributes,
              '라벨',
              containsPair(
                'type',
                'boxed',
              ),
            )
            .having(
              (e) => e.attributes,
              '라벨',
              containsPair(
                'label',
                'Point',
              ),
            ),
      );

      final outerChildren = (outerBlock as Element).children!;

      final innerText = outerChildren.first;

      expect(
        innerText,
        TypeMatcher<Element>()
            .having(
              (e) => e.tag,
              '태그',
              'p',
            )
            .having(
              (e) => e.textContent,
              '내용',
              '박스 속',
            ),
      );

      final innerBlock = outerChildren[1];

      expect(
        innerBlock,
        TypeMatcher<Element>()
            .having(
              (e) => e.children,
              '하위 노드 수 ',
              hasLength(1),
            )
            .having(
              (e) => e.tag,
              '태그',
              'boxedblock',
            )
            .having(
              (e) => e.attributes,
              '라벨',
              containsPair(
                'type',
                'boxed',
              ),
            ),
      );

      final innerTextInInnerBlock =
          (outerChildren[1] as Element).children?.first;

      expect(
        innerTextInInnerBlock,
        TypeMatcher<Element>()
            .having(
              (e) => e.tag,
              '태그',
              'p',
            )
            .having(
              (e) => e.textContent,
              '내용',
              '박스 속 박스',
            ),
      );
    });
  });
}
