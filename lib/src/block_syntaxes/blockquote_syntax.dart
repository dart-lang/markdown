import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'code_block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses email-style blockquotes: `> quote`.
class BlockquoteSyntax extends BlockSyntax {
  const BlockquoteSyntax();

  @override
  RegExp get pattern => blockquotePattern;

  @override
  List<String> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the blockquote, stripping off the ">".
    final childLines = <String>[];

    bool encounteredCodeBlock = false;
    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current);
      if (match != null) {
        final line = match[1]!;
        childLines.add(line);
        encounteredCodeBlock = indentPattern.hasMatch(line);
        parser.advance();
        continue;
      }

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      // Because indented code blocks cannot interrupt paragraphs, a line
      // matched CodeBlockSyntax is also paragraph continuation text.
      final otherMatched =
          parser.blockSyntaxes.firstWhere((s) => s.canParse(parser));
      if (otherMatched is ParagraphSyntax ||
          (!encounteredCodeBlock && otherMatched is CodeBlockSyntax)) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        break;
      }
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(childLines, parser.document).parseLines();

    return Element('blockquote', children);
  }
}
