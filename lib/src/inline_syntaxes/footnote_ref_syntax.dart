import '../ast.dart' show Element, Node, Text;
import '../charcode.dart';
import '../inline_parser.dart' show InlineParser;
import 'link_syntax.dart' show RefLinkCase;

// Footnotes syntax share the same heading '[' with Reference Link, this makes
// a lot of mass, if extends `LinkSyntax`, it will have to override
// `_tryCreateReferenceLink`, and also need other context info, so just a
// separated class is enough.
class FootnoteRefSyntax {
  static String? _footnoteLabel(InlineParser parser, String key) {
    if (key.isEmpty || key.codeUnitAt(0) != $caret) {
      return null;
    }
    key = key.substring(1).trim().toLowerCase();
    if (key.isEmpty) {
      return null;
    }
    return key;
  }

  /// Some cases of github consider footnote's priority is higher than
  /// reference link, so wrap `_resolveReferenceLink` as a callback.
  static Node? tryCreateFootnoteLink(
      InlineParser parser,
      String text,
      List<Node> Function() getChildren,
      RefLinkCase refCase,
      Node? Function() makeLink) {
    final key = _footnoteLabel(parser, text);
    final refs = parser.document.footnoteReferences;
    // `label` is what footnoteReferences stored, it is case sensitive.
    final label =
        refs.keys.firstWhere((k) => k.toLowerCase() == key, orElse: () => '');
    // `count != null` means footnote was valid
    var count = refs[label];
    // For `[$text][^label]`, check if label could match a footnote.
    // In this case, footnote's priority is higher.
    if (refCase == RefLinkCase.pairCaret && count != null) {
      parser.reparse = true;
      return null;
    }

    // In most cases, link's priority is higher.
    final linkNode = makeLink();
    if (linkNode != null) {
      return linkNode;
    }

    // And then check if footnote was matched
    if (key == null || count == null) {
      return null;
    }
    // There are 4 cases here: ![^...], [^...], ![...][^...], [...][^...]
    // If make footnote here, after LinkSyntax's `close()` parser could not
    // distinguish which type of link node it is, e.g. (`![^...]` or `[^...]`)
    // and if then '!' text would be lost
    if (_reparseCases.contains(refCase)) {
      parser.reparse = true;
      return null;
    }
    refs[label] = ++count;
    final labels = parser.document.footnoteLabels;
    int pos = labels.indexOf(key);
    if (pos < 0) {
      pos = labels.length;
      labels.add(key);
    }

    // `children` are text segments after '[^' before ']',
    // now useless but we need clear _delimiterStack.
    getChildren();
    final id = Uri.encodeComponent(label);
    final suffix = count > 1 ? '-$count' : '';
    final link = Element('a', [Text('${pos + 1}')])
      // Ignore github's attribute: <data-footnote-ref>.
      ..attributes['href'] = '#fn-$id'
      ..attributes['id'] = 'fnref-$id$suffix';
    return Element('sup', [link])..attributes['class'] = 'footnote-ref';
  }

  static const _reparseCases = [
    RefLinkCase.exclamationPair,
    RefLinkCase.exclamationPairParen,
    RefLinkCase.exclamationPairBracket,
  ];
}
