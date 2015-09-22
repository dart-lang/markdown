A portable Markdown library written in Dart. It can parse Markdown into
HTML on both the client and server.

Usage
-----

```dart
import 'package:markdown/markdown.dart';

void main() {
  print(markdownToHtml('Hello *Markdown*'));
  //=> <p>Hello <em>Markdown</em></p>
}
```

Syntax extensions
-----------------

A few Markdown extensions are supported. They are all disabled by default, and
can be enabled by specifying an Array of extension syntaxes in the `blockSyntaxes` or `inlineSyntaxes`
argument of `markdownToHtml`.

The currently supported inline extension syntaxes are:

* `new InlineHtmlSyntax()` - approximately CommonMark's
  [definition](http://spec.commonmark.org/0.22/#raw-html) of "Raw HTML".

The currently supported block extension syntaxes are:

* `const FencedCodeBlockSyntax()` - Code blocks familiar to Pandoc and PHP
  Markdown Extra users.

For example:

```dart
import 'package:markdown/markdown.dart';

void main() {
  print(markdownToHtml('Hello <span class="green">Markdown</span>',
      inlineSyntaxes: [new InlineHtmlSyntax()]));
  //=> <p>Hello <span class="green">Markdown</span></p>
}
```

### Custom syntax extensions

You can create and use your own syntaxes.

```dart
import 'package:markdown/markdown.dart';

void main() {
  var syntaxes = [new TextSyntax('nyan', sub: '~=[,,_,,]:3')];
  print(markdownToHtml('nyan', inlineSyntaxes: syntaxes));
  //=> <p>~=[,,_,,]:3</p>
}
```
