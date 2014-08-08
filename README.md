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

A few Markdown extensions, beyond what was specified in the original
[Perl Markdown][] implementation, are supported. By default, the ones supported
in [CommonMark] are enabled. Any individual extension can be enabled by
specifying an Array of extension syntaxes in the `blockSyntaxes` or
`inlineSyntaxes` argument of `markdownToHtml`.

The currently supported inline extension syntaxes are:

* `new InlineHtmlSyntax()` - approximately CommonMark's
  [definition][commonmark-raw-html] of "Raw HTML".

The currently supported block extension syntaxes are:

* `const FencedCodeBlockSyntax()` - Code blocks familiar to Pandoc and PHP
  Markdown Extra users.
* `const HeaderWithIdSyntax()` - ATX-style headers have generated IDs, for link
  anchors (akin to Pandoc's [`auto_identifiers`][pandoc-auto_identifiers]).
* `const SetextHeaderWithIdSyntax()` - Setext-style headers have generated IDs
  for link anchors (akin to Pandoc's
  [`auto_identifiers`][pandoc-auto_identifiers]).

For example:

```dart
import 'package:markdown/markdown.dart';

void main() {
  print(markdownToHtml('Hello <span class="green">Markdown</span>',
      inlineSyntaxes: [new InlineHtmlSyntax()]));
  //=> <p>Hello <span class="green">Markdown</span></p>
}
```

### Extension Sets

To make extension management easy, you can also just specify an extension set.
Both `markdownToHtml()` and `new Document()` accept an `extensionSet` named
parameter. Right now there are two extension sets:

* `ExtensionSet.none` includes no extensions. With no extensions, Markdown
  documents will be parsed closely to how they might be parsed by the original
  [Perl Markdown][] implementation.
* `ExtensionSet.commonMark` includes two extensions so far, which bring this
  package's Markdown parsing closer to what is found in the [CommonMark] spec:

  * `new InlineHtmlSyntax()`
  * `const FencedCodeBlockSyntax()`

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

[Perl Markdown]: http://daringfireball.net/projects/markdown/
[CommonMark]: http://commonmark.org/
[commonMark-raw-html]: http://spec.commonmark.org/0.22/#raw-html
[pandoc-auto_identifiers]: http://pandoc.org/README.html#extension-auto_identifiers
