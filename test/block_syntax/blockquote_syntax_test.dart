import 'dart:convert';

import 'package:markdown/markdown.dart';
import 'package:markdown/src/document.dart';
import 'package:test/test.dart';

void main() {
  late final Document document;
  late final String data;

  setUpAll(() {
    document = Document(
      encodeHtml: false,
    );
    data = '''
> **[ A ]** 안녕하세요
> 박스 안 인용문 사용 예시입니다.

지문이에요.
''';
  });

  test(
    'asdasda',
    () {
      // void loop(Node node) {
      //   if (node is Element) {
      //     print('element: ${node.tag}');
      //     for (final childNode in node.children ?? <Node>[]) {
      //       if (childNode is Element) {
      //         loop(childNode);
      //       } else {
      //         print('text: ${node.textContent}');
      //       }
      //     }
      //   } else {
      //     print('text: ${node.textContent}');
      //   }
      // }

      final lines = LineSplitter.split(data).toList();

      final nodes = BlockParser(lines, document).parseLines();
      print(nodes);
      // final nodes = document.parseLines(lines);
      // nodes.forEach(loop);
    },
  );
}
