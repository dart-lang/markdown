dartdoc markdown library
========================

This is a standalone version of the [dartdoc][dartdoc] markdown library. It 
parses markdown and converts it to HTML.

Installation
------------

Add this to your `pubspec.yaml` (or create it):
```yaml
dependencies:
  markdown: any
```
Then run the [Pub Package Manager][pub] (comes with the Dart SDK):

    pub install

Usage
-----

```dart
import 'package:markdown/markdown.dart' show markdownToHtml;

main() {
  print(markdownToHtml('Hello *Markdown*'));
}
```

Version 0.4 adds support for GitHub style triple backtick code blocks, with 
built in Dart syntax coloring. Custom classifiers can be added using a callback:

```dart
import 'package:markdown/markdown.dart' show markdownToHtml;

main() {
  print(markdownToHtml("Hello *Markdown*"), (syntax, source) {
    if (syntax == 'mysyntax') return classifySyntax(source);
    return source;
  });
}

String classifySyntax(String source) {
	return '<span class="mysyntax">$source</span>';
}
```

[dartdoc]: https://github.com/d2m/dartdoc
[pub]: http://www.dartlang.org/docs/pub-package-manager/
