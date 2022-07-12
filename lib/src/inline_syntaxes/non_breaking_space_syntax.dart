import 'package:markdown/src/inline_parser.dart';
import 'package:markdown/src/inline_syntaxes/inline_syntax.dart';

import '../ast.dart';

class NonBreakingSpace extends InlineSyntax {
  NonBreakingSpace() : super('(&nbsp;)');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final hasMatch = match.groupCount > 0;

    if (hasMatch) {
      parser.addNode(
        Text(' '),
      );
    }

    return hasMatch;
  }
}
