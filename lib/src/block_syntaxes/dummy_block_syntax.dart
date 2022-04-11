import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Walks the parser forward through the lines does not match any [BlockSyntax].
///
/// Returns a [UnparsedContent] with the unmatched lines as `textContent`.
class DummyBlockSyntax extends BlockSyntax {
  const DummyBlockSyntax();

  @override
  RegExp get pattern => dummyPattern;

  @override
  bool canEndBlock(BlockParser parser) => false;

  @override
  bool canParse(BlockParser parser) => true;

  @override
  Node parse(BlockParser parser) {
    final childLines = <String>[];

    while (!BlockSyntax.isAtBlockEnd(parser)) {
      childLines.add(parser.current);
      parser.advance();
    }

    return UnparsedContent(childLines.join('\n'));
  }
}
