import 'dart:async';
import 'dart:html';
import 'package:markdown/markdown.dart' as md;

final markdownInput = querySelector('#markdown') as TextAreaElement;
final htmlDiv = querySelector('#html') as DivElement;
final versionSpan = querySelector('.version') as SpanElement;
final nullSanitizer = new NullTreeSanitizer();
const typing = const Duration(milliseconds: 150);
final introText = r'''Markdown is the **best**!

* It has lists.
* It has [links](http://dartlang.org).
* It has _so much more_...''';

void main() {
  versionSpan.text = 'v${md.version}';
  markdownInput.onKeyUp.listen(_renderMarkdown);

  String savedMarkdown = window.localStorage['markdown'];

  if (savedMarkdown != null &&
      savedMarkdown.isNotEmpty &&
      savedMarkdown != introText) {
    markdownInput.value = savedMarkdown;
    _renderMarkdown();
  } else {
    _typeItOut(introText, 82);
  }
}

void _renderMarkdown([Event event]) {
  var markdown = markdownInput.value;
  htmlDiv.setInnerHtml(md.markdownToHtml(markdown),
      treeSanitizer: nullSanitizer);
  if (event != null) {
    // Not simulated typing. Store it.
    window.localStorage['markdown'] = markdown;
  }
}

void _typeItOut(String msg, int pos) {
  addCharacter() {
    if (pos > msg.length) {
      return;
    }
    markdownInput.value = msg.substring(0, pos);
    markdownInput.focus();
    _renderMarkdown();
    pos++;
    new Timer(typing, addCharacter);
  }

  new Timer(typing, addCharacter);
}

class NullTreeSanitizer implements NodeTreeSanitizer {
  void sanitizeTree(Node node) {}
}
