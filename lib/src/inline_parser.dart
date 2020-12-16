// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:charcode/charcode.dart';

import 'ast.dart';
import 'document.dart';
import 'emojis.dart';
import 'util.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
class InlineParser {
  static final List<InlineSyntax> _defaultSyntaxes =
      List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    EmailAutolinkSyntax(),
    AutolinkSyntax(),
    LineBreakSyntax(),
    ImageSyntax(),
    // Allow any punctuation to be escaped.
    EscapeSyntax(),
    // "*" surrounded by spaces is left alone.
    TextSyntax(r' \* ', startCharacter: $space),
    // "_" surrounded by spaces is left alone.
    TextSyntax(r' _ ', startCharacter: $space),
    // Parse "**strong**" and "*emphasis*" tags.
    TagSyntax(r'\*+', requiresDelimiterRun: true),
    // Parse "__strong__" and "_emphasis_" tags.
    TagSyntax(r'_+', requiresDelimiterRun: true),
    CodeSyntax(),
    // We will add the LinkSyntax once we know about the specific link resolver.
  ]);

  static final List<InlineSyntax> _htmlSyntaxes =
      List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    // Leave already-encoded HTML entities alone. Ensures we don't turn
    // "&amp;" into "&amp;amp;"
    TextSyntax(r'&[#a-zA-Z0-9]*;', startCharacter: $ampersand),
    // Encode "&".
    TextSyntax(r'&', sub: '&amp;', startCharacter: $ampersand),
    // Encode "<".
    TextSyntax(r'<', sub: '&lt;', startCharacter: $lt),
    // Encode ">".
    TextSyntax(r'>', sub: '&gt;', startCharacter: $gt),
  ]);

  /// The string of Markdown being parsed.
  final String? source;

  /// The Markdown document this parser is parsing.
  final Document document;

  final List<InlineSyntax> syntaxes = <InlineSyntax>[];

  /// The current read position.
  int pos = 0;

  /// Starting position of the last unconsumed text.
  int start = 0;

  /// The delimiter stack tracking possible opening delimiters and closing
  /// delimiters for [TagSyntax] nodes.
  final _delimiterStack = <Delimiter>[];

  /// The tree of parsed HTML nodes.
  final _tree = <Node>[];

  InlineParser(this.source, this.document) {
    // User specified syntaxes are the first syntaxes to be evaluated.
    syntaxes.addAll(document.inlineSyntaxes);

    var hasCustomInlineSyntaxes = document.inlineSyntaxes
        .any((s) => !document.extensionSet.inlineSyntaxes.contains(s));

    // This first RegExp matches plain text to accelerate parsing. It's written
    // so that it does not match any prefix of any following syntaxes. Most
    // Markdown is plain text, so it's faster to match one RegExp per 'word'
    // rather than fail to match all the following RegExps at each non-syntax
    // character position.
    if (hasCustomInlineSyntaxes) {
      // We should be less aggressive in blowing past "words".
      syntaxes.add(TextSyntax(r'[A-Za-z0-9]+(?=\s)'));
    } else {
      syntaxes.add(TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9](?=\s)'));
    }

    // Custom link resolvers go after the generic text syntax.
    syntaxes.addAll([
      LinkSyntax(linkResolver: document.linkResolver),
      ImageSyntax(linkResolver: document.imageLinkResolver)
    ]);

    syntaxes.addAll(_defaultSyntaxes);

    if (_encodeHtml) {
      syntaxes.addAll(_htmlSyntaxes);
    }
  }

  List<Node> parse() {
    while (!isDone) {
      // A right bracket (']') is special. Hitting this character triggers the
      // "look for link or image" procedure.
      // See https://spec.commonmark.org/0.29/#an-algorithm-for-parsing-nested-emphasis-and-links.
      if (charAt(pos) == $rbracket) {
        writeText();
        _linkOrImage();
        continue;
      }

      // See if the current text matches any defined markdown syntax.
      if (syntaxes.any((syntax) => syntax.tryMatch(this))) continue;

      // If we got here, it's just text.
      advanceBy(1);
    }

    // Write any trailing text content to a Text node.
    writeText();
    _processEmphasis(-1);
    _combineAdjacentText(_tree);
    return _tree;
  }

  /// Look back through the delimiter stack to see if we've found a link or
  /// image.
  ///
  /// This is the "look for link or image" routine from the CommonMark spec:
  /// https://spec.commonmark.org/0.29/#-look-for-link-or-image-.
  void _linkOrImage() {
    var index = _delimiterStack
        .lastIndexWhere((d) => d.char == $lbracket || d.char == $exclamation);
    if (index == -1) {
      // Never found a possible open bracket. This is just a literal "]".
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    var delimiter = _delimiterStack[index] as SimpleDelimiter;
    if (!delimiter.isActive) {
      _delimiterStack.removeAt(index);
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    var syntax = delimiter.syntax;
    if (syntax is LinkSyntax) {
      var nodeIndex = _tree.lastIndexWhere((n) => n == delimiter.node);
      var linkNode = syntax.close(this, delimiter, null, getChildren: () {
        _processEmphasis(index);
        // All of the nodes which lie past [index] are children of this
        // link/image.
        var children = _tree.sublist(nodeIndex + 1, _tree.length);
        _tree.removeRange(nodeIndex + 1, _tree.length);
        return children;
      });
      if (linkNode != null) {
        _delimiterStack.removeAt(index);
        if (delimiter.char == $lbracket) {
          for (var d in _delimiterStack.sublist(0, index)) {
            if (d.char == $lbracket) d.isActive = false;
          }
        }
        _tree[nodeIndex] = linkNode;
        advanceBy(1);
        start = pos;
      } else {
        _delimiterStack.removeAt(index);
        pos = start;
        advanceBy(1);
      }
    } else {
      throw StateError('Non-link syntax delimiter found with character '
          '"${delimiter.char}"');
    }
  }

  /// Rules 9 and 10.
  bool _canFormEmphasis(Delimiter opener, Delimiter closer) {
    if ((opener.canOpen && opener.canClose) ||
        (closer.canOpen && closer.canClose)) {
      return (opener.length + closer.length) % 3 != 0 ||
          (opener.length % 3 == 0 && closer.length % 3 == 0);
    } else {
      return true;
    }
  }

  /// Processes emphasis (and other [TagSyntax] delimiters) from [bottomIndex]
  /// and up.
  ///
  /// This is the "process emphasis" routine according to the CommonMark spec:
  /// https://spec.commonmark.org/0.29/#-process-emphasis-.
  void _processEmphasis(int bottomIndex) {
    var currentIndex = bottomIndex + 1;
    // Track the lowest index where we might find an open delimiter given a
    // closing delimiter length modulo 3.
    // Each key in this map is an open delimiter character. Each value is a
    // 3-element list. Each value in the list is the lowest index for the given
    // delimiter length modulo 3 (0, 1, 2).
    var openersBottom = <int, List<int>>{};
    while (currentIndex < _delimiterStack.length) {
      var closer = _delimiterStack[currentIndex];
      if (!closer.canClose) {
        currentIndex++;
        continue;
      }
      if (closer.char == $lbracket || closer.char == $exclamation) {
        currentIndex++;
        continue;
      }
      openersBottom.putIfAbsent(closer.char, () => List.filled(3, bottomIndex));
      var openersBottomPerCloserLength = openersBottom[closer.char]!;
      var openerBottom = openersBottomPerCloserLength[closer.length % 3];
      var openerIndex = _delimiterStack.lastIndexWhere(
          (d) =>
              d.char == closer.char && d.canOpen && _canFormEmphasis(d, closer),
          currentIndex - 1);
      if (openerIndex > bottomIndex && openerIndex > openerBottom) {
        // Found an opener for [closer].
        var opener = _delimiterStack[openerIndex];
        var strong = opener.length >= 2 && closer.length >= 2;
        var openerTextNode = opener.node;
        var openerTextNodeIndex = _tree.indexOf(openerTextNode);
        var closerTextNode = closer.node;
        var closerTextNodeIndex = _tree.indexOf(closerTextNode);
        var node = opener.syntax.close(this, opener, closer,
            getChildren: () =>
                _tree.sublist(openerTextNodeIndex + 1, closerTextNodeIndex));
        // Replace all of the nodes between the opener and the closer (which
        // are now the new emphasis node's children) with the emphasis node.
        _tree.replaceRange(
            openerTextNodeIndex + 1, closerTextNodeIndex, [node!]);
        // Slide [closerTextNodeIndex] back accordingly.
        closerTextNodeIndex = openerTextNodeIndex + 2;

        _delimiterStack.removeRange(openerIndex + 1, currentIndex);
        // Slide [currentIndex] back accordingly.
        currentIndex = openerIndex + 1;

        // Remove delimiter characters, possibly removing nodes from the tree
        // and Delimiters from the delimiter stack.
        if ((strong && openerTextNode.text.length == 2) ||
            (!strong && openerTextNode.text.length == 1)) {
          _tree.removeAt(openerTextNodeIndex);
          _delimiterStack.removeAt(openerIndex);
          // Slide [currentIndex] and [closerTextNodeIndex] back accordingly.
          currentIndex--;
          closerTextNodeIndex--;
        } else {
          var newOpenerTextNode =
              Text(openerTextNode.text.substring(strong ? 2 : 1));
          _tree[openerTextNodeIndex] = newOpenerTextNode;
          opener.node = newOpenerTextNode;
        }

        if ((strong && closerTextNode.text.length == 2) ||
            (!strong && closerTextNode.text.length == 1)) {
          _tree.removeAt(closerTextNodeIndex);
          _delimiterStack.removeAt(currentIndex);
          // [currentIndex] has just moved to point at the next delimiter;
          // leave it.
        } else {
          var newCloserTextNode =
              Text(closerTextNode.text.substring(strong ? 2 : 1));
          _tree[closerTextNodeIndex] = newCloserTextNode;
          closer.node = newCloserTextNode;
          // [currentIndex] needs to be considered again; leave it.
        }
      } else {
        // No opener is found.
        openersBottomPerCloserLength[closer.length % 3] = currentIndex - 1;
        if (!closer.canOpen) {
          _delimiterStack.removeAt(currentIndex);
          // This advances [currentIndex] to the next delimiter.
        } else {
          currentIndex++;
        }
      }
    }

    _delimiterStack.removeRange(bottomIndex + 1, _delimiterStack.length);
  }

  // Combine any remaining adjacent Text nodes. This is important to produce
  // correct output across newlines, where whitespace is sometimes compressed.
  void _combineAdjacentText(List<Node?> nodes) {
    for (var i = 0; i < nodes.length - 1; i++) {
      var node = nodes[i];
      if (node is Element && node.children != null) {
        _combineAdjacentText(node.children!);
        continue;
      }
      if (node is Text && nodes[i + 1] is Text) {
        var buffer =
            StringBuffer('${node.textContent}${nodes[i + 1]!.textContent}');
        var j = i + 2;
        while (j < nodes.length && nodes[j] is Text) {
          buffer.write(nodes[j]!.textContent);
          j++;
        }
        nodes[i] = Text(buffer.toString());
        nodes.removeRange(i + 1, j);
      }
    }
  }

  int charAt(int index) => source!.codeUnitAt(index);

  void writeText() {
    if (pos == start) {
      return;
    }
    var text = source!.substring(start, pos);
    _tree.add(Text(text));
    start = pos;
  }

  /// Add [node] to the last [TagState] on the stack.
  void addNode(Node node) {
    _tree.add(node);
  }

  /// Push [state] onto the stack of [TagState]s.
  void _pushDelimiter(Delimiter delimiter) => _delimiterStack.add(delimiter);

  bool get isDone => pos == source!.length;

  void advanceBy(int length) {
    pos += length;
  }

  void consume(int length) {
    pos += length;
    start = pos;
  }

  bool get _encodeHtml => document.encodeHtml;
}

/// Represents one kind of Markdown tag that can be parsed.
abstract class InlineSyntax {
  final RegExp pattern;

  /// The first character of [pattern], to be used as an efficient first check
  /// that this syntax matches the current parser position.
  final int? _startCharacter;

  /// Create a new [InlineSyntax] which matches text on [pattern].
  ///
  /// If [startCharacter] is passed, it is used as a pre-matching check which
  /// is faster than matching against [pattern].
  InlineSyntax(String pattern, {int? startCharacter})
      : pattern = RegExp(pattern, multiLine: true),
        _startCharacter = startCharacter;

  /// Tries to match at the parser's current position.
  ///
  /// The parser's position can be overriden with [startMatchPos].
  /// Returns whether or not the pattern successfully matched.
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;

    // Before matching with the regular expression [pattern], which can be
    // expensive on some platforms, check if even the first character matches
    // this syntax.
    if (_startCharacter != null &&
        parser.source!.codeUnitAt(startMatchPos) != _startCharacter) {
      return false;
    }

    final startMatch = pattern.matchAsPrefix(parser.source!, startMatchPos);
    if (startMatch == null) return false;

    // Write any existing plain text up to this point.
    parser.writeText();

    if (onMatch(parser, startMatch)) parser.consume(startMatch.match.length);
    return true;
  }

  /// Processes [match], adding nodes to [parser] and possibly advancing
  /// [parser].
  ///
  /// Returns whether the caller should advance [parser] by `match[0].length`.
  bool onMatch(InlineParser parser, Match match);
}

/// Represents a hard line break.
class LineBreakSyntax extends InlineSyntax {
  LineBreakSyntax() : super(r'(?:\\|  +)\n');

  /// Create a void <br> element.
  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(Element.empty('br'));
    return true;
  }
}

/// Matches stuff that should just be passed through as straight text.
class TextSyntax extends InlineSyntax {
  final String substitute;

  /// Create a new [TextSyntax] which matches text on [pattern].
  ///
  /// If [sub] is passed, it is used as a simple replacement for [pattern]. If
  /// [startCharacter] is passed, it is used as a pre-matching check which is
  /// faster than matching against [pattern].
  TextSyntax(String pattern, {String sub = '', int? startCharacter})
      : substitute = sub,
        super(pattern, startCharacter: startCharacter);

  /// Adds a [Text] node to [parser] and returns `true` if there is a
  /// [substitute], as long as the preceding character (if any) is not a `/`.
  ///
  /// Otherwise, the parser is advanced by the length of [match] and `false` is
  /// returned.
  @override
  bool onMatch(InlineParser parser, Match match) {
    if (substitute.isEmpty ||
        (match.start > 0 &&
            match.input.substring(match.start - 1, match.start) == '/')) {
      // Just use the original matched text.
      parser.advanceBy(match.match.length);
      return false;
    }

    // Insert the substitution.
    parser.addNode(Text(substitute));
    return true;
  }
}

/// Escape punctuation preceded by a backslash.
class EscapeSyntax extends InlineSyntax {
  EscapeSyntax() : super(r'''\\[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''');

  @override
  bool onMatch(InlineParser parser, Match match) {
    var chars = match.match;
    var char = chars.codeUnitAt(1);
    // Insert the substitution. Why these three charactes are replaced with
    // their equivalent HTML entity referenced appears to be missing from the
    // CommonMark spec, but is very present in all of the examples.
    // https://talk.commonmark.org/t/entity-ification-of-quotes-and-brackets-missing-from-spec/3207
    if (char == $double_quote) {
      parser.addNode(Text('&quot;'));
    } else if (char == $lt) {
      parser.addNode(Text('&lt;'));
    } else if (char == $gt) {
      parser.addNode(Text('&gt;'));
    } else {
      parser.addNode(Text(chars[1]));
    }
    return true;
  }
}

/// Leave inline HTML tags alone, from
/// [CommonMark 0.28](http://spec.commonmark.org/0.28/#raw-html).
///
/// This is not actually a good definition (nor CommonMark's) of an HTML tag,
/// but it is fast. It will leave text like `<a href='hi">` alone, which is
/// incorrect.
///
/// TODO(srawlins): improve accuracy while ensuring performance, once
/// Markdown benchmarking is more mature.
class InlineHtmlSyntax extends TextSyntax {
  InlineHtmlSyntax()
      : super(r'<[/!?]?[A-Za-z][A-Za-z0-9-]*(?:\s[^>]*)?>',
            startCharacter: $lt);
}

/// Matches autolinks like `<foo@bar.example.com>`.
///
/// See <http://spec.commonmark.org/0.28/#email-address>.
class EmailAutolinkSyntax extends InlineSyntax {
  static final _email =
      r'''[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}'''
      r'''[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*''';

  EmailAutolinkSyntax() : super('<($_email)>', startCharacter: $lt);

  @override
  bool onMatch(InlineParser parser, Match match) {
    var url = match[1]!;
    var text = parser._encodeHtml ? escapeHtml(url) : url;
    var anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull('mailto:$url');
    parser.addNode(anchor);

    return true;
  }
}

/// Matches autolinks like `<http://foo.com>`.
class AutolinkSyntax extends InlineSyntax {
  AutolinkSyntax() : super(r'<(([a-zA-Z][a-zA-Z\-\+\.]+):(?://)?[^\s>]*)>');

  @override
  bool onMatch(InlineParser parser, Match match) {
    var url = match[1]!;
    var text = parser._encodeHtml ? escapeHtml(url) : url;
    var anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull(url);
    parser.addNode(anchor);

    return true;
  }
}

/// Matches autolinks like `http://foo.com`.
class AutolinkExtensionSyntax extends InlineSyntax {
  /// Broken up parts of the autolink regex for reusability and readability

  // Autolinks can only come at the beginning of a line, after whitespace, or
  // any of the delimiting characters *, _, ~, and (.
  static const start = r'(?:^|[\s*_~(>])';

  // An extended url autolink will be recognized when one of the schemes
  // http://, https://, or ftp://, followed by a valid domain
  static const scheme = r'(?:(?:https?|ftp):\/\/|www\.)';

  // A valid domain consists of alphanumeric characters, underscores (_),
  // hyphens (-) and periods (.). There must be at least one period, and no
  // underscores may be present in the last two segments of the domain.
  static const domainPart = r'\w\-';
  static const domain = '[$domainPart][$domainPart.]+';

  // A valid domain consists of alphanumeric characters, underscores (_),
  // hyphens (-) and periods (.).
  static const path = r'[^\s<]*';

  // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will not
  // be considered part of the autolink
  static const truncatingPunctuationPositive = r'[?!.,:*_~]';

  static final regExpTrailingPunc = RegExp('$truncatingPunctuationPositive*\$');
  static final regExpEndsWithColon = RegExp(r'\&[a-zA-Z0-9]+;$');
  static final regExpWhiteSpace = RegExp(r'\s');

  AutolinkExtensionSyntax() : super('$start(($scheme)($domain)($path))');

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    return super.tryMatch(parser, parser.pos > 0 ? parser.pos - 1 : 0);
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    var url = match[1]!;
    var href = url;
    var matchLength = url.length;

    if (url[0] == '>' || url.startsWith(regExpWhiteSpace)) {
      url = url.substring(1, url.length - 1);
      href = href.substring(1, href.length - 1);
      parser.pos++;
      matchLength--;
    }

    // Prevent accidental standard autolink matches
    if (url.endsWith('>') && parser.source![parser.pos - 1] == '<') {
      return false;
    }

    // When an autolink ends in ), we scan the entire autolink for the total
    // number of parentheses. If there is a greater number of closing
    // parentheses than opening ones, we don’t consider the last character
    // part of the autolink, in order to facilitate including an autolink
    // inside a parenthesis:
    // https://github.github.com/gfm/#example-600
    if (url.endsWith(')')) {
      final opening = _countChars(url, '(');
      final closing = _countChars(url, ')');

      if (closing > opening) {
        url = url.substring(0, url.length - 1);
        href = href.substring(0, href.length - 1);
        matchLength--;
      }
    }

    // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will
    // not be considered part of the autolink, though they may be included
    // in the interior of the link:
    // https://github.github.com/gfm/#example-599
    final trailingPunc = regExpTrailingPunc.firstMatch(url);
    if (trailingPunc != null) {
      var trailingLength = trailingPunc.match.length;
      url = url.substring(0, url.length - trailingLength);
      href = href.substring(0, href.length - trailingLength);
      matchLength -= trailingLength;
    }

    // If an autolink ends in a semicolon (;), we check to see if it appears
    // to resemble an
    // [entity reference](https://github.github.com/gfm/#entity-references);
    // if the preceding text is & followed by one or more alphanumeric
    // characters. If so, it is excluded from the autolink:
    // https://github.github.com/gfm/#example-602
    if (url.endsWith(';')) {
      final entityRef = regExpEndsWithColon.firstMatch(url);
      if (entityRef != null) {
        // Strip out HTML entity reference
        var entityRefLength = entityRef.match.length;
        url = url.substring(0, url.length - entityRefLength);
        href = href.substring(0, href.length - entityRefLength);
        matchLength -= entityRefLength;
      }
    }

    // The scheme http will be inserted automatically
    if (!href.startsWith('http://') &&
        !href.startsWith('https://') &&
        !href.startsWith('ftp://')) {
      href = 'http://$href';
    }

    final text = parser._encodeHtml ? escapeHtml(url) : url;
    final anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull(href);
    parser.addNode(anchor);

    parser.consume(matchLength);
    return false;
  }

  int _countChars(String input, String char) {
    var count = 0;

    for (var i = 0; i < input.length; i++) {
      if (input[i] == char) count++;
    }

    return count;
  }
}

/// A delimiter indicating the possible "open" or possible "close" of a tag for
/// a [TagSyntax].
abstract class Delimiter {
  /// The [Text] node representing the plain text representing this delimiter.
  abstract Text node;

  /// The type of delimiter.
  ///
  /// For the two-character image delimiter, `![`, this is `!`.
  int get char;

  /// The number of delimiters.
  int get length;

  /// Whether the delimiter is active.
  ///
  /// Links cannot be nested, so we must "deactivate" any pending ones. For
  /// example, take the following text:
  ///
  ///     Text [link and [more](links)](links).
  ///
  /// Once we have parsed `Text [`, there is one (pending) link in the state
  /// stack.  It is, by default, active. Once we parse the next possible link,
  /// `[more](links)`, as a real link, we must deactive the pending links (just
  /// the one, in this case).
  abstract bool isActive;

  /// Whether this delimiter can open emphasis or strong emphasis.
  bool get canOpen;

  /// Whether this delimiter can close emphasis or strong emphasis.
  bool get canClose;

  /// The syntax which uses this delimiter to parse a tag.
  TagSyntax get syntax;
}

/// A simple delimiter implements the [Delimiter] interface with basic fields,
/// and does not have the concept of "left-flanking" or "right-flanking".
class SimpleDelimiter implements Delimiter {
  @override
  Text node;

  @override
  final int char;

  @override
  final int length;

  @override
  bool isActive;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  @override
  final TagSyntax syntax;

  final int endPos;

  SimpleDelimiter(
      {required this.node,
      required this.char,
      required this.length,
      required this.canOpen,
      required this.canClose,
      required this.syntax,
      required this.endPos})
      : isActive = true;
}

/// An implementation of [Delimiter] which uses concepts of "left-flanking" and
/// "right-flanking" to determine the values of [canOpen] and [canClose].
///
/// This is primarily used when parsing emphasis and strong emphasis, but can
/// also be used by other extensions of [TagSyntax].
class DelimiterRun implements Delimiter {
  /// According to
  /// [CommonMark](https://spec.commonmark.org/0.29/#punctuation-character):
  ///
  /// > A punctuation character is an ASCII punctuation character or anything in
  /// > the general Unicode categories `Pc`, `Pd`, `Pe`, `Pf`, `Pi`, `Po`, or
  /// > `Ps`.
  // This RegExp is inspired by
  // https://github.com/commonmark/commonmark.js/blob/1f7d09099c20d7861a674674a5a88733f55ff729/lib/inlines.js#L39.
  // I don't know if there is any way to simplify it or maintain it.
  static final RegExp punctuation = RegExp(r'['
      r'''!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~'''
      r'\xA1\xA7\xAB\xB6\xB7\xBB\xBF\u037E\u0387\u055A-\u055F\u0589\u058A\u05BE'
      r'\u05C0\u05C3\u05C6\u05F3\u05F4\u0609\u060A\u060C\u060D\u061B\u061E'
      r'\u061F\u066A-\u066D\u06D4\u0700-\u070D\u07F7-\u07F9\u0830-\u083E\u085E'
      r'\u0964\u0965\u0970\u0AF0\u0DF4\u0E4F\u0E5A\u0E5B\u0F04-\u0F12\u0F14'
      r'\u0F3A-\u0F3D\u0F85\u0FD0-\u0FD4\u0FD9\u0FDA\u104A-\u104F\u10FB'
      r'\u1360-\u1368\u1400\u166D\u166E\u169B\u169C\u16EB-\u16ED\u1735\u1736'
      r'\u17D4-\u17D6\u17D8-\u17DA\u1800-\u180A\u1944\u1945\u1A1E\u1A1F'
      r'\u1AA0-\u1AA6\u1AA8-\u1AAD\u1B5A-\u1B60\u1BFC-\u1BFF\u1C3B-\u1C3F\u1C7E'
      r'\u1C7F\u1CC0-\u1CC7\u1CD3\u2010-\u2027\u2030-\u2043\u2045-\u2051'
      r'\u2053-\u205E\u207D\u207E\u208D\u208E\u2308-\u230B\u2329\u232A'
      r'\u2768-\u2775\u27C5\u27C6\u27E6-\u27EF\u2983-\u2998\u29D8-\u29DB\u29FC'
      r'\u29FD\u2CF9-\u2CFC\u2CFE\u2CFF\u2D70\u2E00-\u2E2E\u2E30-\u2E42'
      r'\u3001-\u3003\u3008-\u3011\u3014-\u301F\u3030\u303D\u30A0\u30FB\uA4FE'
      r'\uA4FF\uA60D-\uA60F\uA673\uA67E\uA6F2-\uA6F7\uA874-\uA877\uA8CE\uA8CF'
      r'\uA8F8-\uA8FA\uA8FC\uA92E\uA92F\uA95F\uA9C1-\uA9CD\uA9DE\uA9DF'
      r'\uAA5C-\uAA5F\uAADE\uAADF\uAAF0\uAAF1\uABEB\uFD3E\uFD3F\uFE10-\uFE19'
      r'\uFE30-\uFE52\uFE54-\uFE61\uFE63\uFE68\uFE6A\uFE6B\uFF01-\uFF03'
      r'\uFF05-\uFF0A\uFF0C-\uFF0F\uFF1A\uFF1B\uFF1F\uFF20\uFF3B-\uFF3D\uFF3F'
      r'\uFF5B\uFF5D\uFF5F-\uFF65'
      ']');

  // TODO(srawlins): Unicode whitespace
  static final String whitespace = ' \t\r\n';

  @override
  Text node;

  @override
  final int char;

  @override
  int get length => node.text.length;

  @override
  bool isActive;

  @override
  final TagSyntax syntax;

  final bool allowIntraWord;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  DelimiterRun._({
    required this.node,
    required this.char,
    required this.syntax,
    required bool isLeftFlanking,
    required bool isRightFlanking,
    required bool isPrecededByPunctuation,
    required bool isFollowedByPunctuation,
    required this.allowIntraWord,
  })   : canOpen = isLeftFlanking &&
            (char == $asterisk ||
                !isRightFlanking ||
                allowIntraWord ||
                isPrecededByPunctuation),
        canClose = isRightFlanking &&
            (char == $asterisk ||
                !isLeftFlanking ||
                allowIntraWord ||
                isFollowedByPunctuation),
        isActive = true;

  /// Tries to parse a delimiter run from [runStart] (inclusive) to [runEnd]
  /// (exclusive).
  static DelimiterRun? tryParse(InlineParser parser, int runStart, int runEnd,
      {required TagSyntax syntax,
      required Text node,
      bool allowIntraWord = false}) {
    bool leftFlanking,
        rightFlanking,
        precededByPunctuation,
        followedByPunctuation;
    String preceding, following;
    if (runStart == 0) {
      rightFlanking = false;
      preceding = '\n';
    } else {
      preceding = parser.source!.substring(runStart - 1, runStart);
    }
    precededByPunctuation = punctuation.hasMatch(preceding);

    if (runEnd == parser.source!.length) {
      leftFlanking = false;
      following = '\n';
    } else {
      following = parser.source!.substring(runEnd, runEnd + 1);
    }
    followedByPunctuation = punctuation.hasMatch(following);

    // http://spec.commonmark.org/0.28/#left-flanking-delimiter-run
    if (whitespace.contains(following)) {
      leftFlanking = false;
    } else {
      leftFlanking = !followedByPunctuation ||
          whitespace.contains(preceding) ||
          precededByPunctuation ||
          allowIntraWord;
    }

    // http://spec.commonmark.org/0.28/#right-flanking-delimiter-run
    if (whitespace.contains(preceding)) {
      rightFlanking = false;
    } else {
      rightFlanking = !precededByPunctuation ||
          whitespace.contains(following) ||
          followedByPunctuation ||
          allowIntraWord;
    }

    if (!leftFlanking && !rightFlanking) {
      // Could not parse a delimiter run.
      return null;
    }

    return DelimiterRun._(
      node: node,
      char: parser.charAt(runStart),
      syntax: syntax,
      isLeftFlanking: leftFlanking,
      isRightFlanking: rightFlanking,
      isPrecededByPunctuation: precededByPunctuation,
      isFollowedByPunctuation: followedByPunctuation,
      allowIntraWord: allowIntraWord,
    );
  }

  @override
  String toString() => '<char: $char, length: $length, canOpen: $canOpen, '
      'canClose: $canClose>';
}

/// Matches syntax that has a pair of tags and becomes an element, like `*` for
/// `<em>`. Allows nested tags.
class TagSyntax extends InlineSyntax {
  /// Whether this is parsed according to the same nesting rules as [emphasis
  /// delimiters][].
  ///
  /// [emphasis delimiters]: http://spec.commonmark.org/0.28/#can-open-emphasis
  final bool requiresDelimiterRun;

  /// Whether to allow intra-word delimiter runs. CommonMark emphasis and
  /// strong emphasis does not allow this, but GitHub-Flavored Markdown allows
  /// it on strikethrough.
  final bool allowIntraWord;

  /// Create a new [TagSyntax] which matches text on [pattern].
  ///
  /// If [end] is passed, it is used as the pattern which denotes the end of
  /// matching text. Otherwise, [pattern] is used. If [requiresDelimiterRun] is
  /// passed, this syntax parses according to the same nesting rules as
  /// emphasis delimiters.  If [startCharacter] is passed, it is used as a
  /// pre-matching check which is faster than matching against [pattern].
  TagSyntax(String pattern,
      {this.requiresDelimiterRun = false,
      int? startCharacter,
      this.allowIntraWord = false})
      : super(pattern, startCharacter: startCharacter);

  @override
  bool onMatch(InlineParser parser, Match match) {
    var runLength = match.group(0)!.length;
    var matchStart = parser.pos;
    var matchEnd = parser.pos + runLength;
    var text = Text(parser.source!.substring(matchStart, matchEnd));
    if (!requiresDelimiterRun) {
      parser._pushDelimiter(SimpleDelimiter(
          node: text,
          length: runLength,
          char: parser.source!.codeUnitAt(matchStart),
          canOpen: true,
          canClose: false,
          syntax: this,
          endPos: matchEnd));
      parser.addNode(text);
      return true;
    }

    var delimiterRun = DelimiterRun.tryParse(parser, matchStart, matchEnd,
        syntax: this, node: text, allowIntraWord: allowIntraWord);
    if (delimiterRun != null) {
      parser._pushDelimiter(delimiterRun);
      parser.addNode(text);
      return true;
    } else {
      parser.advanceBy(runLength);
      return false;
    }
  }

  /// Attempts to close this tag at the current position.
  ///
  /// If a tag cannot be closed at the current position (for example, if a link
  /// reference cannot be found for a link tag's label), then `null` is
  /// returned.
  ///
  /// If a tag can be closed at the current position, then this method calls
  /// [getChildren], in which [parser] parses any nested text into child nodes.
  /// The returned [Node] incorpororates these child nodes.
  Node? close(InlineParser parser, Delimiter opener, Delimiter closer,
      {required List<Node> Function() getChildren}) {
    var strong = opener.length >= 2 && closer.length >= 2;
    return Element(strong ? 'strong' : 'em', getChildren());
  }
}

/// Matches strikethrough syntax according to the GFM spec.
class StrikethroughSyntax extends TagSyntax {
  StrikethroughSyntax()
      : super('~+', requiresDelimiterRun: true, allowIntraWord: true);

  @override
  Node close(InlineParser parser, Delimiter opener, Delimiter closer,
      {required List<Node> Function() getChildren}) {
    return Element('del', getChildren());
  }
}

/// Matches links like `[blah][label]` and `[blah](url)`.
class LinkSyntax extends TagSyntax {
  static final _entirelyWhitespacePattern = RegExp(r'^\s*$');

  final Resolver linkResolver;

  LinkSyntax(
      {Resolver? linkResolver,
      String pattern = r'\[',
      int startCharacter = $lbracket})
      : linkResolver = (linkResolver ?? ((String _, [String? __]) => null)),
        super(pattern, startCharacter: startCharacter);

  @override
  Node? close(
      InlineParser parser, covariant SimpleDelimiter opener, Delimiter? closer,
      {required List<Node> Function() getChildren}) {
    var text = parser.source!.substring(opener.endPos, parser.pos);
    // The current character is the `]` that closed the link text. Examine the
    // next character, to determine what type of link we might have (a '('
    // means a possible inline link; otherwise a possible reference link).
    if (parser.pos + 1 >= parser.source!.length) {
      // The `]` is at the end of the document, but this may still be a valid
      // shortcut reference link.
      return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
    }

    // Peek at the next character; don't advance, so as to avoid later stepping
    // backward.
    var char = parser.charAt(parser.pos + 1);

    if (char == $lparen) {
      // Maybe an inline link, like `[text](destination)`.
      parser.advanceBy(1);
      var leftParenIndex = parser.pos;
      var inlineLink = _parseInlineLink(parser);
      if (inlineLink != null) {
        return _tryCreateInlineLink(parser, inlineLink,
            getChildren: getChildren);
      }
      // At this point, we've matched `[...](`, but that `(` did not pan out to
      // be an inline link. We must now check if `[...]` is simply a shortcut
      // reference link.

      // Reset the parser position.
      parser.pos = leftParenIndex;
      parser.advanceBy(-1);
      return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
    }

    if (char == $lbracket) {
      parser.advanceBy(1);
      // At this point, we've matched `[...][`. Maybe a *full* reference link,
      // like `[foo][bar]` or a *collapsed* reference link, like `[foo][]`.
      if (parser.pos + 1 < parser.source!.length &&
          parser.charAt(parser.pos + 1) == $rbracket) {
        // That opening `[` is not actually part of the link. Maybe a
        // *shortcut* reference link (followed by a `[`).
        parser.advanceBy(1);
        return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
      }
      var label = _parseReferenceLinkLabel(parser);
      if (label != null) {
        return _tryCreateReferenceLink(parser, label, getChildren: getChildren);
      }
      return null;
    }

    // The link text (inside `[...]`) was not followed with a opening `(` nor
    // an opening `[`. Perhaps just a simple shortcut reference link (`[...]`).
    return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
  }

  /// Resolve a possible reference link.
  ///
  /// Uses [linkReferences], [linkResolver], and [_createNode] to try to
  /// resolve [label] into a [Node]. If [label] is defined in
  /// [linkReferences] or can be resolved by [linkResolver], returns a [Node]
  /// that links to the resolved URL.
  ///
  /// Otherwise, returns `null`.
  ///
  /// [label] does not need to be normalized.
  Node? _resolveReferenceLink(
      String label, Map<String, LinkReference> linkReferences,
      {List<Node> Function()? getChildren}) {
    var linkReference = linkReferences[normalizeLinkLabel(label)];
    if (linkReference != null) {
      return _createNode(linkReference.destination, linkReference.title,
          getChildren: getChildren!);
    } else {
      // This link has no reference definition. But we allow users of the
      // library to specify a custom resolver function ([linkResolver]) that
      // may choose to handle this. Otherwise, it's just treated as plain
      // text.

      // Normally, label text does not get parsed as inline Markdown. However,
      // for the benefit of the link resolver, we need to at least escape
      // brackets, so that, e.g. a link resolver can receive `[\[\]]` as `[]`.
      var resolved = linkResolver(label
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\[', '[')
          .replaceAll(r'\]', ']'));
      if (resolved != null) {
        getChildren!();
      }
      return resolved;
    }
  }

  /// Create the node represented by a Markdown link.
  Node _createNode(String destination, String? title,
      {required List<Node> Function() getChildren}) {
    var children = getChildren();
    var element = Element('a', children);
    element.attributes['href'] = escapeAttribute(destination);
    if (title != null && title.isNotEmpty) {
      element.attributes['title'] = escapeAttribute(title);
    }
    return element;
  }

  /// Tries to create a reference link node.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  Node? _tryCreateReferenceLink(InlineParser parser, String label,
      {required List<Node> Function() getChildren}) {
    return _resolveReferenceLink(label, parser.document.linkReferences,
        getChildren: getChildren);
  }

  // Tries to create an inline link node.
  //
  /// Returns the link if it was successfully created, `null` otherwise.
  Node _tryCreateInlineLink(InlineParser parser, InlineLink link,
      {required List<Node> Function() getChildren}) {
    return _createNode(link.destination, link.title, getChildren: getChildren);
  }

  /// Parse a reference link label at the current position.
  ///
  /// Specifically, [parser.pos] is expected to be pointing at the `[` which
  /// opens the link label.
  ///
  /// Returns the label if it could be parsed, or `null` if not.
  String? _parseReferenceLinkLabel(InlineParser parser) {
    // Walk past the opening `[`.
    parser.advanceBy(1);
    if (parser.isDone) return null;

    var buffer = StringBuffer();
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        var next = parser.charAt(parser.pos);
        if (next != $backslash && next != $rbracket) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == $rbracket) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
      // TODO(srawlins): only check 999 characters, for performance reasons?
    }

    var label = buffer.toString();

    // A link label must contain at least one non-whitespace character.
    if (_entirelyWhitespacePattern.hasMatch(label)) return null;

    return label;
  }

  /// Parse an inline [InlineLink] at the current position.
  ///
  /// At this point, we have parsed a link's (or image's) opening `[`, and then
  /// a matching closing `]`, and [parser.pos] is pointing at an opening `(`.
  /// This method will then attempt to parse a link destination wrapped in `<>`,
  /// such as `(<http://url>)`, or a bare link destination, such as
  /// `(http://url)`, or a link destination with a title, such as
  /// `(http://url "title")`.
  ///
  /// Returns the [InlineLink] if one was parsed, or `null` if not.
  InlineLink? _parseInlineLink(InlineParser parser) {
    // Start walking to the character just after the opening `(`.
    parser.advanceBy(1);

    _moveThroughWhitespace(parser);
    if (parser.isDone) return null; // EOF. Not a link.

    if (parser.charAt(parser.pos) == $lt) {
      // Maybe a `<...>`-enclosed link destination.
      return _parseInlineBracketedLink(parser);
    } else {
      return _parseInlineBareDestinationLink(parser);
    }
  }

  /// Parse an inline link with a bracketed destination (a destination wrapped
  /// in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  InlineLink? _parseInlineBracketedLink(InlineParser parser) {
    parser.advanceBy(1);

    var buffer = StringBuffer();
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        var next = parser.charAt(parser.pos);
        // TODO: Follow the backslash spec better here.
        // http://spec.commonmark.org/0.29/#backslash-escapes
        if (next != $backslash && next != $gt) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == $lf || char == $cr || char == $ff) {
        // Not a link (no line breaks allowed within `<...>`).
        return null;
      } else if (char == $space) {
        buffer.write('%20');
      } else if (char == $gt) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    var destination = buffer.toString();

    parser.advanceBy(1);
    var char = parser.charAt(parser.pos);
    if (char == $space || char == $lf || char == $cr || char == $ff) {
      var title = _parseTitle(parser);
      if (title == null && parser.charAt(parser.pos) != $rparen) {
        // This looked like an inline link, until we found this $space
        // followed by mystery characters; no longer a link.
        return null;
      }
      return InlineLink(destination, title: title);
    } else if (char == $rparen) {
      return InlineLink(destination);
    } else {
      // We parsed something like `[foo](<url>X`. Not a link.
      return null;
    }
  }

  /// Parse an inline link with a "bare" destination (a destination _not_
  /// wrapped in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  InlineLink? _parseInlineBareDestinationLink(InlineParser parser) {
    // According to
    // [CommonMark](http://spec.commonmark.org/0.28/#link-destination):
    //
    // > A link destination consists of [...] a nonempty sequence of
    // > characters [...], and includes parentheses only if (a) they are
    // > backslash-escaped or (b) they are part of a balanced pair of
    // > unescaped parentheses.
    //
    // We need to count the open parens. We start with 1 for the paren that
    // opened the destination.
    var parenCount = 1;
    var buffer = StringBuffer();

    while (true) {
      var char = parser.charAt(parser.pos);
      switch (char) {
        case $backslash:
          parser.advanceBy(1);
          if (parser.isDone) return null; // EOF. Not a link.
          var next = parser.charAt(parser.pos);
          // Parentheses may be escaped.
          //
          // http://spec.commonmark.org/0.28/#example-467
          if (next != $backslash && next != $lparen && next != $rparen) {
            buffer.writeCharCode(char);
          }
          buffer.writeCharCode(next);
          break;

        case $space:
        case $lf:
        case $cr:
        case $ff:
          var destination = buffer.toString();
          var title = _parseTitle(parser);
          if (title == null &&
              (parser.isDone || parser.charAt(parser.pos) != $rparen)) {
            // This looked like an inline link, until we found this $space
            // followed by mystery characters; no longer a link.
            return null;
          }
          // [_parseTitle] made sure the title was follwed by a closing `)`
          // (but it's up to the code here to examine the balance of
          // parentheses).
          parenCount--;
          if (parenCount == 0) {
            return InlineLink(destination, title: title);
          }
          break;

        case $lparen:
          parenCount++;
          buffer.writeCharCode(char);
          break;

        case $rparen:
          parenCount--;
          if (parenCount == 0) {
            var destination = buffer.toString();
            return InlineLink(destination);
          }
          buffer.writeCharCode(char);
          break;

        default:
          buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
    }
  }

  // Walk the parser forward through any whitespace.
  void _moveThroughWhitespace(InlineParser parser) {
    while (!parser.isDone) {
      var char = parser.charAt(parser.pos);
      if (char != $space &&
          char != $tab &&
          char != $lf &&
          char != $vt &&
          char != $cr &&
          char != $ff) {
        return;
      }
      parser.advanceBy(1);
    }
  }

  /// Parses a link title in [parser] at it's current position. The parser's
  /// current position should be a whitespace character that followed a link
  /// destination.
  ///
  /// Returns the title if it was successfully parsed, `null` otherwise.
  String? _parseTitle(InlineParser parser) {
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;

    // The whitespace should be followed by a title delimiter.
    var delimiter = parser.charAt(parser.pos);
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return null;
    }

    var closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    parser.advanceBy(1);

    // Now we look for an un-escaped closing delimiter.
    var buffer = StringBuffer();
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        var next = parser.charAt(parser.pos);
        if (next != $backslash && next != closeDelimiter) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == closeDelimiter) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    var title = buffer.toString();

    // Advance past the closing delimiter.
    parser.advanceBy(1);
    if (parser.isDone) return null;
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;
    if (parser.charAt(parser.pos) != $rparen) return null;
    return title;
  }
}

/// Matches images like `![alternate text](url "optional title")` and
/// `![alternate text][label]`.
class ImageSyntax extends LinkSyntax {
  ImageSyntax({Resolver? linkResolver})
      : super(
            linkResolver: linkResolver,
            pattern: r'!\[',
            startCharacter: $exclamation);

  @override
  Element _createNode(String destination, String? title,
      {required List<Node> Function() getChildren}) {
    var element = Element.empty('img');
    var children = getChildren();
    element.attributes['src'] = destination;
    element.attributes['alt'] = children.map((node) => node.textContent).join();
    if (title != null && title.isNotEmpty) {
      element.attributes['title'] =
          escapeAttribute(title.replaceAll('&', '&amp;'));
    }
    return element;
  }
}

/// Matches backtick-enclosed inline code blocks.
class CodeSyntax extends InlineSyntax {
  // This pattern matches:
  //
  // * a string of backticks (not followed by any more), followed by
  // * a non-greedy string of anything, including newlines, ending with anything
  //   except a backtick, followed by
  // * a string of backticks the same length as the first, not followed by any
  //   more.
  //
  // This conforms to the delimiters of inline code, both in Markdown.pl, and
  // CommonMark.
  static final String _pattern = r'(`+(?!`))((?:.|\n)*?[^`])\1(?!`)';

  CodeSyntax() : super(_pattern);

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    if (parser.pos > 0 && parser.charAt(parser.pos - 1) == $backquote) {
      // Not really a match! We can't just sneak past one backtick to try the
      // next character. An example of this situation would be:
      //
      //     before ``` and `` after.
      //             ^--parser.pos
      return false;
    }

    var match = pattern.matchAsPrefix(parser.source!, parser.pos);
    if (match == null) {
      return false;
    }
    parser.writeText();
    if (onMatch(parser, match)) parser.consume(match.match.length);
    return true;
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    var code = match[2]!.trim().replaceAll('\n', ' ');
    if (parser._encodeHtml) code = escapeHtml(code);
    parser.addNode(Element.text('code', code));

    return true;
  }
}

/// Matches GitHub Markdown emoji syntax like `:smile:`.
///
/// There is no formal specification of GitHub's support for this colon-based
/// emoji support, so this syntax is based on the results of Markdown-enabled
/// text fields at github.com.
class EmojiSyntax extends InlineSyntax {
  // Emoji "aliases" are mostly limited to lower-case letters, numbers, and
  // underscores, but GitHub also supports `:+1:` and `:-1:`.
  EmojiSyntax() : super(':([a-z0-9_+-]+):');

  @override
  bool onMatch(InlineParser parser, Match match) {
    var alias = match[1]!;
    var emoji = emojis[alias];
    if (emoji == null) {
      parser.advanceBy(1);
      return false;
    }
    parser.addNode(Text(emoji));

    return true;
  }
}

class InlineLink {
  final String destination;
  final String? title;

  InlineLink(this.destination, {this.title});
}
