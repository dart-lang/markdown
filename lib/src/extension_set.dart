import 'block_parser.dart';
import 'inline_parser.dart';

/// ExtensionSets provide a simple grouping mechanism for common Markdown
/// flavors.
///
/// For example, the [gitHub] set of syntax extensions allows users to output
/// HTML from their Markdown in a similar fashion to GitHub's parsing.
class ExtensionSet {
  /// The [none] extension set renders Markdown similar to [Markdown.pl].
  ///
  /// However, this set does not render _exactly_ the same as Markdown.pl;
  /// rather it is more-or-less the CommonMark standard of Markdown, without
  /// fenced code blocks, or inline HTML.
  ///
  /// [Markdown.pl]: http://daringfireball.net/projects/markdown/syntax
  static final ExtensionSet none = new ExtensionSet([], []);

  /// The [commonMark] extension set is close to compliance with [CommonMark].
  ///
  /// [CommonMark]: http://commonmark.org/
  static final ExtensionSet commonMark = new ExtensionSet(
      [const FencedCodeBlockSyntax()], [new InlineHtmlSyntax()]);

  /// The [gitHubWeb] extension set renders Markdown similarly to GitHub.
  ///
  /// This is different from the [gitHubFlavored] extension set in that GitHub
  /// actually renders HTML different from straight [GitHub flavored Markdown].
  ///
  /// (The only difference currently is that [gitHubWeb] renders headers with
  /// linkable IDs.)
  ///
  /// [GitHub flavored Markdown]: https://github.github.com/gfm/
  static final ExtensionSet gitHubWeb = new ExtensionSet([
    const FencedCodeBlockSyntax(),
    const HeaderWithIdSyntax(),
    const SetextHeaderWithIdSyntax(),
    const TableSyntax()
  ], [
    new InlineHtmlSyntax()
  ]);

  /// The [gitHubFlavored] extension set is close to compliance with the [GitHub
  /// flavored Markdown spec].
  ///
  /// [GitHub flavored Markdown]: https://github.github.com/gfm/
  static final ExtensionSet gitHubFlavored = new ExtensionSet(
      [const FencedCodeBlockSyntax(), const TableSyntax()],
      [new InlineHtmlSyntax()]);

  /// The deprecated name for the [gitHubFlavored] extension set.
  @deprecated
  static final ExtensionSet gitHub = gitHubFlavored;

  final List<BlockSyntax> blockSyntaxes;
  final List<InlineSyntax> inlineSyntaxes;

  ExtensionSet(this.blockSyntaxes, this.inlineSyntaxes);
}
