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
import "package:markdown/markdown.dart" show markdownToHtml;

main() {
  print(markdownToHtml("Hello *Markdown*"));
}
```

[dartdoc]: https://github.com/d2m/dartdoc
[pub]: http://www.dartlang.org/docs/pub-package-manager/
