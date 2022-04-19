import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

class EmptyBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => emptyPattern;

  const EmptyBlockSyntax();

  @override
  Node? parse(BlockParser parser) {
    parser.encounteredBlankLine = true;
    parser.advance();

    // Don't actually emit anything.
    return null;
  }
}
