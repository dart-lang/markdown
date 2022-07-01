// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../patterns.dart';
import 'block_syntax.dart';

class FencedTexBlockSyntax extends BlockSyntax {
  const FencedTexBlockSyntax();
  @override
  bool canParse(BlockParser parser) {
    final match = pattern.firstMatch(parser.current);
    if (match == null) return false;
    final codeFence = match.group(1)!;
    final infoString = match.group(2);
    // From the CommonMark spec:
    //
    // > Ifthe info string comes after a backtick fence, it may not contain
    // > any backtick characters.
    return (codeFence.codeUnitAt(0) != $backquote ||
        !infoString!.codeUnits.contains($backquote));
  }

  /// 블록 하위 문장 파싱
  @override
  List<String> parseChildLines(BlockParser parser, [String? endBlock]) {
    endBlock ??= '';

    /// 블록 하위 문장 리스트
    final childLines = <String>[];

    /// 포지션을 다음 라인으로 이동시키기
    parser.advance();

    /// 파싱이 끝날때까지
    while (!parser.isDone) {
      /// 현재 라인에 같은 패턴이 존재하는 확인
      final match = pattern.firstMatch(parser.current);

      /// 같은 패턴이 존재하지 않거나 $$으로 시작하지 않는다
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

    /// 캡처그룹 1번 ($$)
    final endBlock = match.group(1);

    /// 블록 하위 문장리스트
    final childLines = parseChildLines(parser, endBlock)..add('');

    /// 하나의 문장으로 합침
    final text = childLines.join('\n');

    /// tex 엘리먼트
    final tex = Element.text('tex', text);

    /// tex 엘리먼트를 포함한 블록 엘리먼트
    final element = Element('texblock', [tex]);

    return element;
  }

  @override
  RegExp get pattern => texFencePattern;
}
