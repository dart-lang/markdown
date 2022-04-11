import '../ast.dart';
import '../block_parser.dart';
import 'block_html_syntax.dart';

/// A BlockHtmlSyntax that has a specific `endPattern`.
///
/// In practice this means that the syntax dominates; it is allowed to eat
/// many lines, including blank lines, before matching its `endPattern`.
class LongBlockHtmlSyntax extends BlockHtmlSyntax {
  LongBlockHtmlSyntax(String pattern, String endPattern)
      : pattern = RegExp(pattern),
        _endPattern = RegExp(endPattern);

  @override
  final RegExp pattern;
  final RegExp _endPattern;

  @override
  Node parse(BlockParser parser) {
    final childLines = <String>[];
    // Eat until we hit [endPattern].
    while (!parser.isDone) {
      childLines.add(parser.current);
      if (parser.matches(_endPattern)) break;
      parser.advance();
    }

    parser.advance();
    return Text(childLines.join('\n').trimRight());
  }
}
