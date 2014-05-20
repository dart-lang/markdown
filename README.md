markdown
========

This is a portable markdown library written in dart. It can parse markdown into
html on both the client and server.

Usage
-----

[You can find the installation directions here.][installing]

```dart
import 'package:markdown/markdown.dart' show markdownToHtml;

main() {
  print(markdownToHtml('Hello *Markdown*'));
  //=> <p>Hello <em>Markdown</em></p>
}
```

You can create and use your own syntaxes!

```dart
import 'package:markdown/markdown.dart';

main() {
  List<InlineSyntax> syntaxes = [new TextSyntax('nyan', sub: '~=[,,_,,]:3')];
  print(markdownToHtml('nyan', inlineSyntaxes: syntaxes));
  //=> <p>~=[,,_,,]:3</p>
}
```
[You can find the documentation for this library here.][documentation]

[installing]: http://pub.dartlang.org/packages/markdown#installing
[documentation]: http://www.dartdocs.org/documentation/markdown/0.7.0/index.html

