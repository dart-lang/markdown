import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const HeaderSyntax();

  @override
  Node parse(BlockParser parser) {
    final match = pattern.firstMatch(parser.current)!;
    parser.advance();
    final level = match[1]!.length;
    final contents = UnparsedContent(match[2]!.trim());
    return Element('h$level', [contents]);
  }
}
