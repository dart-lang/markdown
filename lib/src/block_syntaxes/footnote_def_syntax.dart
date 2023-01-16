import '../ast.dart' show Element, Node;
import '../block_parser.dart' show BlockParser;
import '../line.dart';
import '../patterns.dart' show footnotePattern;
import 'block_syntax.dart' show BlockSyntax;
import 'empty_block_syntax.dart';
import 'paragraph_syntax.dart';
import 'setext_header_syntax.dart';

/// Footnote definition could contain multiple line-children and children could
/// be separated by one empty line.
/// Its first child-line would be the remaining part of first line after taking
/// definition leading, combining with other line-children parsed by
/// `parseChildLines`, is feed into `BlockParser`.
class FootnoteDefSyntax extends BlockSyntax {
  const FootnoteDefSyntax();

  @override
  RegExp get pattern => footnotePattern;

  @override
  Node? parse(BlockParser parser) {
    final current = parser.current.content;
    final match = pattern.firstMatch(current)!;
    final label = match[2]!;
    final refs = parser.document.footnoteReferences;
    refs[label] = 0;

    final id = Uri.encodeComponent(label);
    parser.advance();
    final lines = [
      Line(current.substring(match[0]!.length)),
      ...parseChildLines(parser),
    ];
    // Linebreak in secondary paragraph did not match LineBreakSyntax
    // so there is no `<br />`, unlike GitHub.
    final children = BlockParser(lines, parser.document).parseLines();
    return Element('li', children)
      ..attributes['id'] = 'fn-$id'
      ..attributes['_label_'] = label;
  }

  @override
  List<Line> parseChildLines(BlockParser parser) {
    final children = <String>[];
    // As one empty line should not split footnote definition, use this flag.
    var shouldBeBlock = false;
    Iterable<BlockSyntax>? syntaxList;
    Iterable<BlockSyntax> validSyntaxList() {
      return syntaxList ??= parser.blockSyntaxes
          .where((s) => !_invalidSecondaryBlock.contains(s.runtimeType));
    }

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim().isEmpty) {
        children.add(line);
        parser.advance();
        shouldBeBlock = true;
        continue;
      } else if (line.startsWith('    ')) {
        children.add(line.substring(4));
        parser.advance();
        shouldBeBlock = false;
      } else if (shouldBeBlock || _isBlock(validSyntaxList(), line)) {
        break;
      } else {
        children.add(line);
        parser.advance();
      }
    }
    return children.map(Line.new).toList(growable: false);
  }

  static const _invalidSecondaryBlock = <Type>{
    EmptyBlockSyntax,
    ParagraphSyntax,
    SetextHeaderSyntax,
  };

  static bool _isBlock(Iterable<BlockSyntax> syntaxList, String line) {
    return syntaxList.any((s) => s.pattern.hasMatch(line));
  }
}
