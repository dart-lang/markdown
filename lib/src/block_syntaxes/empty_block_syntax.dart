import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

class EmptyBlockSyntax extends BlockSyntax {
  const EmptyBlockSyntax();

  @override
  RegExp get pattern => emptyPattern;

  @override
  Node? parse(BlockParser parser) {
    parser.encounteredBlankLine = true;
    parser.advance();

    // Don't actually emit anything.
    return null;
  }
}
