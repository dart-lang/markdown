import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses lines fenced by `>>>` to blockquotes
class FencedBlockquoteSyntax extends BlockSyntax {
  const FencedBlockquoteSyntax();

  @override
  RegExp get pattern => blockquoteFencePattern;

  @override
  List<String> parseChildLines(BlockParser parser) {
    final childLines = <String>[];
    parser.advance();

    while (!parser.isDone) {
      final match = pattern.hasMatch(parser.current);
      if (!match) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    return childLines;
  }

  @override
  Node? parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(childLines, parser.document).parseLines();
    return Element('blockquote', children);
  }
}
