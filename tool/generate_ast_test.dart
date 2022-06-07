import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:markdown/src/extensions.dart';
import 'package:path/path.dart' as p;
import 'stats_lib.dart';

void main() {
  const testPrefix = 'common_mark';
  final sections = loadCommonMarkSections(testPrefix);

  for (final entry in sections.entries) {
    final fileName = _generateFileName(entry.key);
    if (fileName != 'atx_headings.json') {
      continue;
    }

    final cases = <Map<String, dynamic>>[];

    for (final e in entry.value) {
      final document = Document();
      final nodes = document.parseLines(e.markdown);
      cases.add({
        "description": "${entry.key} - ${e.example}",
        "input": e.markdown,
        "output": nodes.map((e) => e.toMap()).toList(),
      });
    }

    File(p.join('test', testPrefix, fileName))
      ..createSync(recursive: true)
      ..writeAsStringSync(cases.toPrettyString());
  }
}

String _generateFileName(String key) {
  final sectionNameReplace = RegExp(r'[ \)\(]+');
  var fileName = key.toLowerCase().replaceAll(sectionNameReplace, '_');
  while (fileName.endsWith('_')) {
    fileName = fileName.substring(0, fileName.length - 1);
  }
  return '$fileName.json';
}
