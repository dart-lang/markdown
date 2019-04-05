## 2.0.3

* Render element attributes in the order they were defined.
  Aligns more closely with the strict spec definition.
* Correctly render `&` within inline image titles.
* Added 68 new GitHub emojis.

## 2.0.2

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 2.0.1

* Require Dart 2.0.0-dev.

## 2.0.0

* **Breaking change:** The `Link` class has been renamed `LinkReference`, and
  the `Document` field, `refLinks`, has been renamed `linkReferences`.
* **Breaking change:** Remove the deprecated `ExtensionSet.gitHub` field.
  Use `ExtensionSet.gitHubFlavored` instead.
* **Breaking change:** Make all of the fields on `Document` read-only.
* Overhaul support for emphasis (`*foo*` and `_foo_`) and strong emphasis
  (`**foo**` and `__foo__`), dramatically improving CommonMark compliance.
* Overhaul support for links and images, again dramatically improving CommonMark
  compliance.
* Improve support for tab characters, and horizontal rules.
* Add support for GitHub Flavored Markdown's Strikethrough extension. See the
  [GFM spec][strikethrough].
* The above fixes raise compliance with the CommonMark specs to 93%, and
  compliance with the GFM specs to 92%.
* Add an `encodeHtml` parameter to `Document`, which defaults to true. When
  false, HTML entities (such as `&copy;` and the `<` character) will not be
  escaped, useful when rendering Markdown in some output format other than HTML.
* Allow the binary script to take a `--extension-set` option.

  A reminder: You can [run `bin/markdown.dart` from anywhere][pub-global] via:

  ```shell
  $ pub global activate markdown
  $ markdown
  ```

[strikethrough]: https://github.github.com/gfm/#strikethrough-extension-
[pub-global]: https://www.dartlang.org/tools/pub/cmd/pub-global#running-a-script-from-your-path

## 1.1.1

* Add support for GitHub's colon-based Emoji syntax. :tada:! This is available
  in the `gitHubWeb` extension set.

## 1.1.0

* Make the constructor for ExtensionSet public, for tools like dartdoc.
* Split the `gitHub` ExtensionSet into two sets: `gitHubFlavored`, which
  represents the GitHub Flavored Markdown spec, and `gitHubWeb`, which
  represents what GitHub actually renders Markdown.

## 1.0.0

* Fix issue where `accept` could cause an exception.
* Remove deprecated `escapeHtml` function.
* Fix compliance with auto-links, including support for email addresses.
* Updated `ExtensionSet.gitHub` to more closely align with GitHub markdown.

## 0.11.4

* Fix bug with lazy blockquote continuations (#162)
* Fix bug with list item continuations (#156)

## 0.11.3

* Deprecate `escapeHtml`. This code exists in `dart:convert`.

## 0.11.2

* Fix reference code links inside blockquotes.
* Add src/util.dart to exports.

## 0.11.1

* Add version information:
  * `dart bin/markdown.dart --version` now shows the package version number.
  * The playground app now shows the version number.
* Improve autolink parsing.
* Add new table syntax: `TableSyntax`.
* Add new ExtensionSet that includes the table syntax: `ExtensionSet.gitHub`.
* For development: added `tool/travis.sh`.
* Support multiline Setext headers.
* Handle loose-vs-strict list items better.
* Support ordered lists that start with a number other than 1.

## 0.11.0+1

* Add playground app at https://dart-lang.github.io/markdown.

## 0.11.0

* Parse HTML blocks more accurately, according to
  [CommonMark](http://spec.commonmark.org/0.24/#html-blocks).
* Support [shortcut reference
  links](http://spec.commonmark.org/0.24/#reference-link).
* Don't allow an indented code block to interrupt a paragraph.
* Change definition of "loose" and "strict" lists (items wrapped in
  paragraph tags vs not) to CommonMark's. The primary difference is that any
  single list item can trigger the entire list to be marked as "loose", rather
  than defining "looseness" on each specific item.
* Fix paragraph continuations in blockquotes and list items.
* Fix silly typing bug with `tool/common_mark_stats.dart`, which resulted in
  a dramatic overestimate of our CommonMark compliance.
* There are now 427/613 (69%) passing CommonMark v0.25 specs.

## 0.10.1

* Parse [hard line breaks](http://spec.commonmark.org/0.24/#hard-line-breaks)
  properly (#86). Thanks @mehaase!
* Fix processing of `[ ... ]` syntax when no resolver is specified (#92).
* There are now 401/613 (65%) passing CommonMark v0.24 specs.
  (_Actually: after 0f64c8f the actual number of passing tests was 352/613
  (57%)._)

## 0.10.0

* BREAKING: Now following the CommonMark spec for fenced code blocks.
  If a language (info string) is provided, it is added as a class to the `code`
  element with a `language-` prefix.
* BREAKING: Now following the CommonMark spec for images. Previously,
  `![text](img.png)` would compile too
  `<a href="img.prg"><img src="img.prg" alt="text"></img></a>`. That same code
  will now compile to `<img src="img.png" alt="text" />`.
* Fix all [strong mode][] errors.

[strong mode]: https://github.com/dart-lang/dev_compiler/blob/master/STRONG_MODE.md

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
