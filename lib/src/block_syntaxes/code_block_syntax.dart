import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks that are indented four spaces.
class CodeBlockSyntax extends BlockSyntax {
  const CodeBlockSyntax();

  @override
  RegExp get pattern => indentPattern;

  @override
  bool canEndBlock(BlockParser parser) => false;

  @override
  List<String?> parseChildLines(BlockParser parser) {
    final childLines = <String?>[];

    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current);
      if (match != null) {
        childLines.add(match[1]);
        parser.advance();
      } else {
        // If there's a codeblock, then a newline, then a codeblock, keep the
        // code blocks together.
        final nextMatch =
            parser.next != null ? pattern.firstMatch(parser.next!) : null;
        if (parser.current.trim() == '' && nextMatch != null) {
          childLines.add('');
          childLines.add(nextMatch[1]);
          parser.advance();
          parser.advance();
        } else {
          break;
        }
      }
    }
    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // The Markdown tests expect a trailing newline.
    childLines.add('');

    var content = childLines.join('\n');
    if (parser.document.encodeHtml) {
      content = escapeHtml(content);
    }

    return Element('pre', [Element.text('code', content)]);
  }
}
