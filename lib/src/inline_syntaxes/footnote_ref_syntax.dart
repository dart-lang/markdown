import '../ast.dart' show Element, Node, Text;
import '../charcode.dart';
import '../inline_parser.dart' show InlineParser;
import 'link_syntax.dart' show LinkContext;

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

  static Iterable<Node>? tryCreateFootnoteLink(
    LinkContext context,
    String text,
    bool secondary,
  ) {
    final parser = context.parser;
    final key = _footnoteLabel(parser, text);
    final refs = parser.document.footnoteReferences;
    // `label` is what footnoteReferences stored, it is case sensitive.
    final label =
        refs.keys.firstWhere((k) => k.toLowerCase() == key, orElse: () => '');
    // `count != null` means footnote was valid
    var count = refs[label];
    // And then check if footnote was matched
    if (key == null || count == null) {
      return null;
    }
    final result = <Node>[];
    // There are 4 cases here: ![^...], [^...], ![...][^...], [...][^...]
    if (context.opener.char == $exclamation) {
      result.add(Text('!'));
    }
    refs[label] = ++count;
    final labels = parser.document.footnoteLabels;
    var pos = labels.indexOf(key);
    if (pos < 0) {
      pos = labels.length;
      labels.add(key);
    }

    // `children` are text segments after '[^' before ']'.
    final children = context.getChildren();
    if (secondary) {
      result.add(Text('['));
      result.addAll(children);
      result.add(Text(']'));
    }
    final id = Uri.encodeComponent(label);
    final suffix = count > 1 ? '-$count' : '';
    final link = Element('a', [Text('${pos + 1}')])
      // Ignore github's attribute: <data-footnote-ref>.
      ..attributes['href'] = '#fn-$id'
      ..attributes['id'] = 'fnref-$id$suffix';
    final sup = Element('sup', [link])..attributes['class'] = 'footnote-ref';
    result.add(sup);
    return result;
  }
}
