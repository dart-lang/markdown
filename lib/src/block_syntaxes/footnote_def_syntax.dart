import '../ast.dart' show Element, Node;
import '../block_parser.dart' show BlockParser;
import '../patterns.dart' show footnotePattern;
import 'block_syntax.dart' show BlockSyntax;
import 'empty_block_syntax.dart';
import 'paragraph_syntax.dart';
import 'setext_header_syntax.dart';

class FootnoteDefSyntax extends BlockSyntax {
  const FootnoteDefSyntax();

  @override
  RegExp get pattern => footnotePattern;

  @override
  Node? parse(BlockParser parser) {
    final current = parser.current;
    final match = pattern.firstMatch(current)!;
    final label = match[2]!;
    final refs = parser.document.footnoteReferences;
    refs[label] = 0;

    final id = Uri.encodeComponent(label);
    parser.advance();
    final lines = [
      current.substring(match[0]!.length),
      ...parseChildLines(parser),
    ];
    // Linebreak in secondary paragraph did not match LineBreakSyntax
    // so there is no `<br />`, unlike github.
    final children = BlockParser(lines, parser.document).parseLines();
    return Element('li', children)
      ..attributes['id'] = 'fn-$id'
      ..attributes['_label_'] = label;
  }

  @override
  List<String> parseChildLines(BlockParser parser) {
    final children = <String>[];
    var nextIsBlock = false;
    while (!parser.isDone) {
      final line = parser.current;
      if (line.trim().isEmpty) {
        children.add(line);
        parser.advance();
        nextIsBlock = true;
        continue;
      } else if (line.startsWith('    ')) {
        children.add(line.substring(4));
        parser.advance();
        nextIsBlock = false;
      } else if (nextIsBlock || _isBlock(parser, line)) {
        break;
      } else {
        children.add(line);
        parser.advance();
      }
    }
    return children;
  }

  static const _invalidSecondaryBlock = <Type>[
    EmptyBlockSyntax,
    ParagraphSyntax,
    SetextHeaderSyntax,
  ];

  static bool _isBlock(BlockParser parser, String line) {
    final syntaxList = parser.blockSyntaxes
        .takeWhile((s) => !_invalidSecondaryBlock.contains(s.runtimeType));
    return syntaxList.any((s) => s.pattern.hasMatch(line));
  }
}
