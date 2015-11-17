## 0.10.0

* BREAKING: Now following the CommonMark spec for fenced code blocks.
  If a language (info string) is provided, it is added as a class to the `code`
  element with a `language-` prefix.

## 0.9.0

* BREAKING: The text `[foo] (bar)` no longer renders as an inline link (#53).
* BREAKING: Change list parsing to allow lists to begin immediately after a
  preceding block element, without a blank line in between.
* Formalize an API for Markdown extensions (#43).
* Introduce ExtensionSets. FencedCodeBlock is considered an extension, but
  existing usage of `markdownToHtml()` and `new Document()` will use the
  default extension set, which is `ExtensionSet.commonMark`, which includes
  FencedCodeBlock.
* Inline HTML syntax support; This is also considered an extension (#18).
* The text `[foo]()` now renders as an inline link.
* Whitespace now allowed between a link's destination and title (#65).
* Header identifier support in the HeaderWithIdSyntax and
  SetextHeaderWithIdSyntax extensions.
* Implement backslash-escaping so that Markdown syntax can be escaped, such as
  `[foo]\(bar) ==> <p>[foo](bar)</p>`.
* Support for hard line breaks with either `\\\n` or <code>  \n</code> (#30,
  #60).
* New public method for BlockParser: `peek(int linesAhead)`, meant for use in
  subclasses.
* New public members for ListSyntax: `blocksInList` and `determineBlockItems()`,
  meant for use in subclasses.
* Improve public docs (better, and more of them).

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
