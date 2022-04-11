import '../ast.dart';
import '../inline_parser.dart';
import 'tag_syntax.dart';

/// Matches strikethrough syntax according to the GFM spec.
class StrikethroughSyntax extends TagSyntax {
  StrikethroughSyntax()
      : super('~+', requiresDelimiterRun: true, allowIntraWord: true);

  @override
  Node close(
    InlineParser parser,
    Delimiter opener,
    Delimiter closer, {
    required List<Node> Function() getChildren,
  }) {
    return Element('del', getChildren());
  }
}
