## 0.9.0

* Formalize an API for Markdown extensions (#43).
* Introduce ExtensionSets. FencedCodeBlock is considered an extension, but
  existing usage of `markdownToHtml()` and `new Document()` will use the
  default extension set, which is `ExtensionSet.commonMark`, which includes
  FencedCodeBlock.
* Inline HTML syntax support; This is also considered an extension (#18).
* The text `[foo] (bar)` now parses as an inline link (#53).
* The text `[foo]()` now renders as an inline link.
* Header identifier support in the HeaderWithIdSyntax and
  SetextHeaderWithIdSyntax extensions.
* Implement backslash-escaping so that Markdown syntax can be escaped, such as
  `[foo]\(bar) ==> <p>[foo](bar)</p>`.
* New public method for BlockParser: `peek(int linesAhead)`.

## 0.8.0

* **Breaking:** Remove (probably unused) fields: `LinkSyntax.resolved`,
  `InlineParser.currentSource`.
* Switch tests to use [test][] instead of [unittest][].
* Fix a few bugs in inline code syntax.
* Ignore underscores inside words (#41).

[test]: https://pub.dartlang.org/packages/test
[unittest]: https://pub.dartlang.org/packages/unittest

## 0.7.2

* Allow resolving links that contain inline syntax (#42).

## 0.7.1+3

* Updated homepage.

## 0.7.1+2

* Formatted code.

* Updated readme.
