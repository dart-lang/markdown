import 'package:markdown/src/inline_parser.dart';
import 'package:markdown/src/inline_syntaxes/inline_syntax.dart';

import '../ast.dart';

class NonBreakingSpace extends InlineSyntax {
  NonBreakingSpace() : super('(&nbsp;|&ensp;|&emsp;)');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final hasMatch = match.groupCount > 0;

    if (hasMatch) {
      final matchedString = match.group(1);
      if (matchedString!.contains('ensp')) {
        parser.addNode(
          Text('  '),
        );
      } else if (matchedString.contains('emsp')) {
        parser.addNode(
          Text('   '),
        );
      } else {
        parser.addNode(
          Text(' '),
        );
      }
    }

    return hasMatch;
  }
}
