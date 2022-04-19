import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses horizontal rules like `---`, `_ _ _`, `*  *  *`, etc.
class HorizontalRuleSyntax extends BlockSyntax {
  @override
  RegExp get pattern => hrPattern;

  const HorizontalRuleSyntax();

  @override
  Node parse(BlockParser parser) {
    parser.advance();
    return Element.empty('hr');
  }
}
