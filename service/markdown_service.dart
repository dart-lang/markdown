import 'package:markdown/markdown.dart' as md;

void markdownToHtml(req, res) {
  var text = req.query.text;
  res.set('Content-Type', 'application/json');
  res.send({
    'name': 'Dart markdown',
    'version': md.version,
    'html': md.markdownToHtml(text, extensionSet: md.ExtensionSet.commonMark)
  }.toString());
}
