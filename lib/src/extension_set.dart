import 'block_parser.dart';
import 'inline_parser.dart';

class ExtensionSet {
  static final ExtensionSet none = new ExtensionSet._([], []);

  static final ExtensionSet commonMark = new ExtensionSet._(
      [const FencedCodeBlockSyntax()], [new InlineHtmlSyntax()]);

  static final ExtensionSet gitHub = new ExtensionSet._(
      [const FencedCodeBlockSyntax(), const TableSyntax()],
      [new InlineHtmlSyntax()]);

  final List<BlockSyntax> blockSyntaxes;
  final List<InlineSyntax> inlineSyntaxes;

  ExtensionSet._(this.blockSyntaxes, this.inlineSyntaxes);
}
