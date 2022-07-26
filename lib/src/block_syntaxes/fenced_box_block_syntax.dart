import 'package:markdown/markdown.dart';
import 'package:markdown/src/patterns.dart';

class FencedBoxBlockSyntax extends BlockSyntax {
  FencedBoxBlockSyntax();

  @override
  RegExp get pattern => boxFencePattern;
  final _boxTypePattern = RegExp('(boxed|voca|checked)(.*)');
  final fencePattern = RegExp(r'^(\:{3,3})(.*)$');

  @override
  List<String?> parseChildLines(BlockParser parser, [String? endBlock]) {
    endBlock ??= '';

    /// 블록 하위 문장 리스트
    final childLines = <String>[];

    /// 포지션을 다음 라인으로 이동시키기
    parser.advance();

    /// 파싱이 끝날때까지
    while (!parser.isDone) {
      /// 현재 라인에 같은 패턴이 존재하는 확인
      final match = fencePattern.firstMatch(parser.current);

      /// 같은 패턴이 존재하지 않거나 :::으로 시작하지 않는다
      if (match == null || !match[1]!.startsWith(endBlock)) {
        /// 하위 문장리스트에 삽입
        childLines.add(parser.current);

        /// 다음 라인으로 이동
        parser.advance();
      } else {
        /// 다음 라인으로 이동
        parser.advance();
        break;
      }
    }

    /// 블록 하위 문장리스트 리턴
    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final element = Element('boxedblock', []);

    /// canParse 조건을 만족한 라인 매치 결과
    final match = pattern.firstMatch(parser.current)!;

    /// 박스 블록 끝 문자열 :::
    final endBlock = match.group(1);

    /// 박스 정보 문자열
    final boxInfo = match.group(2) ?? '';

    /// 박스 정보 매치
    final boxInfoMatch = _boxTypePattern.firstMatch(boxInfo);

    /// 박스 타입 boxed | checked | voca
    final boxType = boxInfoMatch?.group(1) ?? '';

    /// 박스 라벨 [label]
    final label = (boxInfoMatch?.group(2)?.isEmpty ?? true)
        ? null
        : boxInfoMatch!.group(2);

    final parsedChildlines = parseChildLines(parser, endBlock);

    final childrenLines = parsedChildlines
        .where((element) => element != null)
        .cast<String>()
        .toList();

    final nodes = BlockParser(childrenLines, parser.document).parseLines();

    if (boxType == 'checked') {
      /// 첫번재 h1 인덱스
      final titleH1Index = nodes
          .indexWhere((element) => element is Element && element.tag == 'h1');

      /// 첫번째 h1이 존재한다면
      if (titleH1Index != -1) {
        final titleH1 = nodes[titleH1Index];

        /// nodes에서 삭제가 성공하면
        if (nodes.remove(titleH1)) {
          /// checked 블록의 타이틀을 첫번재 h1의 text로 설정
          element.attributes['title'] = titleH1.textContent;
        }
      }
    }

    /// 라벨에서 '[' ']' 제거
    if (label != null) {
      element.attributes['label'] =
          label.replaceAll('[', '').replaceAll(']', "");
    }

    return element
      ..children?.addAll(nodes)
      ..attributes['type'] = boxType;
  }
}
