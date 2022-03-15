// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parses text in a Markdown-like format building an
/// [AST tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree)
/// that can then be rendered to HTML.
///
/// If you are only interested in rendering Markdown to HTML please refer
/// to the [README](../index.html) which explains the use of [markdownToHtml()].
///
/// The main entrypoint to the library is the [Document] which encapsulates the
/// parsing process converting a Markdown text into a tree of [Node] (`List<Node>`).
///
/// Two main parsing mechanics are used:
///
/// - Blocks, representing top level elements like: headers, paragraphs, blockquotes,
///   code blocks, ... implemented via [BlockSyntax] subclasses.
/// - Inlines, representing chunks of text within a block with special meaning, like:
///   links, emphasis, inlined code, ... implemented via [InlineSyntax] subclasses.
///
/// Looking closely at [Document.new()] a few other concepts merit a mention:
///
/// - [ExtensionSet] that provide configurations for common Markdown flavors
/// - [Resolver] which aid in resolving links and images
///
/// If you are looking at extending the library to support custom formatting
/// what you may want is to:
///
/// - Implement your own [InlineSyntax] subclasses
/// - Implement your own [BlockSyntax] subclasses
/// - Instruct the library to use those by:
///   - Creating a new [ExtensionSet] from one of the existing flavors adding your syntaxes
///   - Passing your syntaxes to [Document] or [markdownToHtml()] as parameters.
library markdown;

import 'src/version.dart';

export 'src/ast.dart';
export 'src/block_parser.dart';
export 'src/document.dart';
export 'src/emojis.dart';
export 'src/extension_set.dart';
export 'src/html_renderer.dart';
export 'src/inline_parser.dart';

const version = packageVersion;
