import 'package:markdown/markdown.dart';
import 'package:markdown/src/patterns.dart';

class FencedAlignBlockSyntax extends BlockSyntax {
  FencedAlignBlockSyntax();

  @override
  RegExp get pattern => alignFencePattern;
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
    /// canParse 조건을 만족한 라인 매치 결과
    final match = pattern.firstMatch(parser.current)!;

    /// 블록 끝 문자열 :::
    final endBlock = match.group(1);

    /// 정렬 정보
    final alignInfo = match.group(2) ?? 'left';

    final element = Element('alignment', [])..attributes['align'] = alignInfo;

    final parsedChildlines = parseChildLines(parser, endBlock);

    final childrenLines = parsedChildlines
        .where((element) => element != null)
        .cast<String>()
        .toList();

    final nodes = BlockParser(childrenLines, parser.document).parseLines();

    print(nodes);

    return element..children?.addAll(nodes);
  }
}
