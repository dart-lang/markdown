import 'package:charcode/charcode.dart';

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `<foo@bar.example.com>`.
///
/// See <http://spec.commonmark.org/0.28/#email-address>.
class EmailAutolinkSyntax extends InlineSyntax {
  EmailAutolinkSyntax() : super('<($_email)>', startCharacter: $lt);

  static final _email =
      r'''[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}'''
      r'''[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*''';

  @override
  bool onMatch(InlineParser parser, Match match) {
    final url = match[1]!;
    final text = parser.encodeHtml ? escapeHtml(url) : url;
    final anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull('mailto:$url');
    parser.addNode(anchor);

    return true;
  }
}
