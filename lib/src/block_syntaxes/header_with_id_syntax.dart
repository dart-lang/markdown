import '../ast.dart';
import '../block_parser.dart';
import 'block_syntax.dart';
import 'header_syntax.dart';

/// Parses atx-style headers, and adds generated IDs to the generated elements.
class HeaderWithIdSyntax extends HeaderSyntax {
  const HeaderWithIdSyntax();

  @override
  Node parse(BlockParser parser) {
    final element = super.parse(parser) as Element;
    element.generatedId = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}
