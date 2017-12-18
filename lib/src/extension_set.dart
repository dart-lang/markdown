import 'block_parser.dart';
import 'inline_parser.dart';

/// ExtensionSets provide a simple grouping mechanism for common Markdown
/// flavors.
///
/// For example, the [gitHub] set of syntax extensions allows users to output
/// HTML from their Markdown in a similar fashion to GitHub's parsing.
class ExtensionSet {
  static final ExtensionSet none = new ExtensionSet([], []);

  static final ExtensionSet commonMark = new ExtensionSet(
      [const FencedCodeBlockSyntax()], [new InlineHtmlSyntax()]);

  static final ExtensionSet gitHub = new ExtensionSet(
      [const FencedCodeBlockSyntax(), const TableSyntax()],
      [new InlineHtmlSyntax()]);

  final List<BlockSyntax> blockSyntaxes;
  final List<InlineSyntax> inlineSyntaxes;

  ExtensionSet(this.blockSyntaxes, this.inlineSyntaxes);
}
