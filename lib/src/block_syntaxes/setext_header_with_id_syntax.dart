import '../ast.dart';
import '../block_parser.dart';
import 'block_syntax.dart';
import 'setext_header_syntax.dart';

/// Parses setext-style headers, and adds generated IDs to the generated
/// elements.
class SetextHeaderWithIdSyntax extends SetextHeaderSyntax {
  const SetextHeaderWithIdSyntax();

  @override
  Node parse(BlockParser parser) {
    final element = super.parse(parser) as Element;
    element.generatedId = BlockSyntax.generateAnchorHash(element);
    return element;
  }
}
