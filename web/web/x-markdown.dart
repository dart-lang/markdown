import 'package:polymer/polymer.dart';
import 'package:markdown/markdown.dart';

@CustomTag('x-markdown')
class XMarkdown extends PolymerElement {
  String _markdown;
  @published set markdown(String markdown) {
    _markdown = markdown;
    if (markdown == null) return;
    $['markdown'].innerHtml = markdownToHtml(markdown);
  }
  get markdown => _markdown;

  XMarkdown.created():super.created();
}

