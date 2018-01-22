// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:charcode/charcode.dart';

import 'ast.dart';
import 'document.dart';
import 'emojis.dart';
import 'link_like.dart';
import 'link_walker.dart';
import 'util.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
class InlineParser {
  static final List<InlineSyntax> _defaultSyntaxes =
      new List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    new EmailAutolinkSyntax(),
    new AutolinkSyntax(),
    new LineBreakSyntax(),
    new LinkSyntax(),
    new ImageSyntax(),
    // Allow any punctuation to be escaped.
    new EscapeSyntax(),
    // "*" surrounded by spaces is left alone.
    new TextSyntax(r' \* '),
    // "_" surrounded by spaces is left alone.
    new TextSyntax(r' _ '),
    // Leave already-encoded HTML entities alone. Ensures we don't turn
    // "&amp;" into "&amp;amp;"
    new TextSyntax(r'&[#a-zA-Z0-9]*;'),
    // Encode "&".
    new TextSyntax(r'&', sub: '&amp;'),
    // Encode "<". (Why not encode ">" too? Gruber is toying with us.)
    new TextSyntax(r'<', sub: '&lt;'),
    // Parse "**strong**" and "*emphasis*" tags.
    new TagSyntax(r'\*+', requiresDelimiterRun: true),
    // Parse "__strong__" and "_emphasis_" tags.
    new TagSyntax(r'_+', requiresDelimiterRun: true),
    new CodeSyntax(),
    // We will add the LinkSyntax once we know about the specific link resolver.
  ]);

  /// The string of Markdown being parsed.
  final String source;

  /// The Markdown document this parser is parsing.
  final Document document;

  final List<InlineSyntax> syntaxes = <InlineSyntax>[];

  /// The current read position.
  int pos = 0;

  /// Starting position of the last unconsumed text.
  int start = 0;

  final List<TagState> _stack;

  InlineParser(this.source, this.document) : _stack = <TagState>[] {
    // User specified syntaxes are the first syntaxes to be evaluated.
    syntaxes.addAll(document.inlineSyntaxes);

    var documentHasCustomInlineSyntaxes = document.inlineSyntaxes
        .any((s) => !document.extensionSet.inlineSyntaxes.contains(s));

    // This first RegExp matches plain text to accelerate parsing. It's written
    // so that it does not match any prefix of any following syntaxes. Most
    // Markdown is plain text, so it's faster to match one RegExp per 'word'
    // rather than fail to match all the following RegExps at each non-syntax
    // character position.
    if (documentHasCustomInlineSyntaxes) {
      // We should be less aggressive in blowing past "words".
      syntaxes.add(new TextSyntax(r'[A-Za-z0-9]+\b'));
    } else {
      syntaxes.add(new TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9]'));
    }

    syntaxes.addAll(_defaultSyntaxes);

    // Custom link resolvers go after the generic text syntax.
    syntaxes.insertAll(1, [
      new LinkSyntax(linkResolver: document.linkResolver),
      new ImageSyntax(linkResolver: document.imageLinkResolver)
    ]);
  }

  List<Node> parse() {
    // Make a fake top tag to hold the results.
    _stack.add(new TagState(0, 0, null, null));

    loopOverSource:
    while (!isDone) {
      // See if any of the current tags on the stack match.  This takes
      // priority over other possible matches.
      for (var i = _stack.length - 1; i > 0; i--) {
        if (_stack[i].tryMatch(this)) {
          continue loopOverSource;
        }
      }

      // See if the current text matches any defined markdown syntax.
      for (var syntax in syntaxes) {
        if (syntax.tryMatch(this)) {
          continue loopOverSource;
        }
      }

      // If we got here, it's just text.
      advanceBy(1);
    }

    // Unwind any unmatched tags and get the results.
    return _stack[0].close(this, null);
  }

  int charAt(int index) => source.codeUnitAt(index);

  void writeText() {
    writeTextRange(start, pos);
    start = pos;
  }

  void writeTextRange(int start, int end) {
    if (end <= start) return;

    var text = source.substring(start, end);
    var nodes = _stack.last.children;

    // If the previous node is text too, just append.
    if (nodes.length > 0 && nodes.last is Text) {
      var textNode = nodes.last as Text;
      nodes[nodes.length - 1] = new Text('${textNode.text}$text');
    } else {
      nodes.add(new Text(text));
    }
  }

  void addNode(Node node) {
    _stack.last.children.add(node);
  }

  bool get isDone => pos == source.length;

  void advanceBy(int length) {
    pos += length;
  }

  void consume(int length) {
    pos += length;
    start = pos;
  }
}

/// Represents one kind of Markdown tag that can be parsed.
abstract class InlineSyntax {
  final RegExp pattern;

  InlineSyntax(String pattern) : pattern = new RegExp(pattern, multiLine: true);

  /// Tries to match at the parser's current position.
  ///
  /// Returns whether or not the pattern successfully matched.
  bool tryMatch(InlineParser parser) {
    var startMatch = pattern.matchAsPrefix(parser.source, parser.pos);
    if (startMatch != null) {
      // Write any existing plain text up to this point.
      parser.writeText();

      if (onMatch(parser, startMatch)) parser.consume(startMatch[0].length);
      return true;
    }

    return false;
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
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(new Element.empty('br'));
    return true;
  }
}

/// Matches stuff that should just be passed through as straight text.
class TextSyntax extends InlineSyntax {
  final String substitute;

  TextSyntax(String pattern, {String sub})
      : substitute = sub,
        super(pattern);

  bool onMatch(InlineParser parser, Match match) {
    if (substitute == null) {
      // Just use the original matched text.
      parser.advanceBy(match[0].length);
      return false;
    }

    // Insert the substitution.
    parser.addNode(new Text(substitute));
    return true;
  }
}

/// Escape punctuation preceded by a backslash.
class EscapeSyntax extends InlineSyntax {
  EscapeSyntax() : super(r'''\\[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''');

  bool onMatch(InlineParser parser, Match match) {
    // Insert the substitution.
    parser.addNode(new Text(match[0][1]));
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
  InlineHtmlSyntax() : super(r'<[/!?]?[A-Za-z][A-Za-z0-9-]*(?:\s[^>]*)?>');
}

/// Matches autolinks like `<foo@bar.example.com>`.
///
/// See <http://spec.commonmark.org/0.28/#email-address>.
class EmailAutolinkSyntax extends InlineSyntax {
  static final _email =
      r'''[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}'''
      r'''[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*''';

  EmailAutolinkSyntax() : super('<($_email)>');

  bool onMatch(InlineParser parser, Match match) {
    var url = match[1];
    var anchor = new Element.text('a', escapeHtml(url));
    anchor.attributes['href'] = Uri.encodeFull('mailto:$url');
    parser.addNode(anchor);

    return true;
  }
}

/// Matches autolinks like `<http://foo.com>`.
class AutolinkSyntax extends InlineSyntax {
  AutolinkSyntax() : super(r'<(([a-zA-Z][a-zA-Z\-\+\.]+):(?://)?[^\s>]*)>');

  bool onMatch(InlineParser parser, Match match) {
    var url = match[1];
    var anchor = new Element.text('a', escapeHtml(url));
    anchor.attributes['href'] = Uri.encodeFull(url);
    parser.addNode(anchor);

    return true;
  }
}

class _DelimiterRun {
  static final String punctuation = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';
  // TODO(srawlins): Unicode whitespace
  static final String whitespace = ' \t\r\n';

  final int char;
  final int length;
  final bool isLeftFlanking;
  final bool isRightFlanking;
  final bool isPrecededByPunctuation;
  final bool isFollowedByPunctuation;

  _DelimiterRun._(
      {this.char,
      this.length,
      this.isLeftFlanking,
      this.isRightFlanking,
      this.isPrecededByPunctuation,
      this.isFollowedByPunctuation});

  static _DelimiterRun tryParse(InlineParser parser, int runStart, int runEnd) {
    bool leftFlanking,
        rightFlanking,
        precededByPunctuation,
        followedByPunctuation;
    String preceding, following;
    if (runStart == 0) {
      rightFlanking = false;
      preceding = '\n';
    } else {
      preceding = parser.source.substring(runStart - 1, runStart);
    }
    precededByPunctuation = punctuation.contains(preceding);

    if (runEnd == parser.source.length - 1) {
      leftFlanking = false;
      following = '\n';
    } else {
      following = parser.source.substring(runEnd + 1, runEnd + 2);
    }
    followedByPunctuation = punctuation.contains(following);

    // http://spec.commonmark.org/0.28/#left-flanking-delimiter-run
    if (whitespace.contains(following)) {
      leftFlanking = false;
    } else {
      leftFlanking = !followedByPunctuation ||
          whitespace.contains(preceding) ||
          precededByPunctuation;
    }

    // http://spec.commonmark.org/0.28/#right-flanking-delimiter-run
    if (whitespace.contains(preceding)) {
      rightFlanking = false;
    } else {
      rightFlanking = !precededByPunctuation ||
          whitespace.contains(following) ||
          followedByPunctuation;
    }

    if (!leftFlanking && !rightFlanking) {
      // Could not parse a delimiter run.
      return null;
    }

    return new _DelimiterRun._(
        char: parser.charAt(runStart),
        length: runEnd - runStart + 1,
        isLeftFlanking: leftFlanking,
        isRightFlanking: rightFlanking,
        isPrecededByPunctuation: precededByPunctuation,
        isFollowedByPunctuation: followedByPunctuation);
  }

  String toString() =>
      '<char: $char, length: $length, isLeftFlanking: $isLeftFlanking, '
      'isRightFlanking: $isRightFlanking>';

  // Whether a delimiter in this run can open emphasis or strong emphasis.
  bool get canOpen =>
      isLeftFlanking &&
      (char == $asterisk || !isRightFlanking || isPrecededByPunctuation);

  // Whether a delimiter in this run can close emphasis or strong emphasis.
  bool get canClose =>
      isRightFlanking &&
      (char == $asterisk || !isLeftFlanking || isFollowedByPunctuation);
}

/// Matches syntax that has a pair of tags and becomes an element, like `*` for
/// `<em>`. Allows nested tags.
class TagSyntax extends InlineSyntax {
  final RegExp endPattern;
  final bool requiresDelimiterRun;

  TagSyntax(String pattern, {String end, this.requiresDelimiterRun: false})
      : endPattern = new RegExp((end != null) ? end : pattern, multiLine: true),
        super(pattern);

  bool onMatch(InlineParser parser, Match match) {
    var runLength = match.group(0).length;
    var matchStart = parser.pos;
    var matchEnd = parser.pos + runLength - 1;
    if (!requiresDelimiterRun) {
      parser._stack.add(new TagState(parser.pos, matchEnd + 1, this, null));
      return true;
    }

    var delimiterRun = _DelimiterRun.tryParse(parser, matchStart, matchEnd);
    if (delimiterRun != null && delimiterRun.canOpen) {
      parser._stack
          .add(new TagState(parser.pos, matchEnd + 1, this, delimiterRun));
      return true;
    } else {
      parser.advanceBy(runLength);
      return false;
    }
  }

  bool onMatchEnd(InlineParser parser, Match match, TagState state) {
    var runLength = match.group(0).length;
    var matchStart = parser.pos;
    var matchEnd = parser.pos + runLength - 1;
    var openingRunLength = state.endPos - state.startPos;
    var delimiterRun = _DelimiterRun.tryParse(parser, matchStart, matchEnd);

    if (openingRunLength == 1 && runLength == 1) {
      parser.addNode(new Element('em', state.children));
    } else if (openingRunLength == 1 && runLength > 1) {
      parser.addNode(new Element('em', state.children));
      parser.pos = parser.pos - (runLength - 1);
      parser.start = parser.pos;
    } else if (openingRunLength > 1 && runLength == 1) {
      parser._stack.add(
          new TagState(state.startPos, state.endPos - 1, this, delimiterRun));
      parser.addNode(new Element('em', state.children));
    } else if (openingRunLength == 2 && runLength == 2) {
      parser.addNode(new Element('strong', state.children));
    } else if (openingRunLength == 2 && runLength > 2) {
      parser.addNode(new Element('strong', state.children));
      parser.pos = parser.pos - (runLength - 2);
      parser.start = parser.pos;
    } else if (openingRunLength > 2 && runLength == 2) {
      parser._stack.add(
          new TagState(state.startPos, state.endPos - 2, this, delimiterRun));
      parser.addNode(new Element('strong', state.children));
    } else if (openingRunLength > 2 && runLength > 2) {
      parser._stack.add(
          new TagState(state.startPos, state.endPos - 2, this, delimiterRun));
      parser.addNode(new Element('strong', state.children));
      parser.pos = parser.pos - (runLength - 2);
      parser.start = parser.pos;
    }

    return true;
  }
}

/// Matches strikethrough syntax according to the GFM spec.
class StrikethroughSyntax extends TagSyntax {
  StrikethroughSyntax() : super('~+', requiresDelimiterRun: true);

  @override
  bool onMatchEnd(InlineParser parser, Match match, TagState state) {
    var runLength = match.group(0).length;
    var matchStart = parser.pos;
    var matchEnd = parser.pos + runLength - 1;
    var delimiterRun = _DelimiterRun.tryParse(parser, matchStart, matchEnd);
    if (!delimiterRun.isRightFlanking) {
      return false;
    }

    parser.addNode(new Element('del', state.children));
    return true;
  }
}

/// Matches links like `[blah][label]` and `[blah](url)`.
class LinkSyntax extends TagSyntax {
  final Resolver linkResolver;

  LinkSyntax({this.linkResolver, String pattern: r'\['})
      : super(pattern, end: r'\]');

  // Pending [TagState]s are "active" or "inactive" based on whether a
  // link-like element has just been parsed. Links cannot be nested, so we must
  // "deactivate" any pending ones.
  bool _pendingStatesAreActive = true;

  @override
  bool onMatch(InlineParser parser, Match match) {
    var matched = super.onMatch(parser, match);
    if (!matched) return false;

    _pendingStatesAreActive = true;

    return true;
  }

  bool onMatchEnd(InlineParser parser, Match match, TagState state) {
    if (!_pendingStatesAreActive) return false;

    var i = parser.pos;
      var text =
          parser.source.substring(state.endPos, parser.pos).toLowerCase();
    var linkWalker = new LinkWalker(parser);
    // The current character is the `]` that closed the link text.
    i++;
    if (i == parser.source.length) {
      // In this case, the Markdown document may have ended with a shortcut
      // reference link.
      var linkLike = new LinkLike.reference(text, i - 1);
      if (linkLike != null) {
        return _addNode(parser, state, linkLike);
      } else {
        return false;
      }
    }
    var char = parser.charAt(i);

    // Maybe an inline link.
    if (char == $lparen) {
      var linkLike = linkWalker.parseInlineLink();
      if (linkLike != null) {
        return _addNode(parser, state, linkLike);
      }

      // At this point, we've matched `[...](`, but that `(` did not pan out to
      // be an inline link. We must now check if `[...]` is simply a shortcut
      // reference link.
      linkLike = new LinkLike.reference(text, i - 1);
      if (linkLike != null) {
        return _addNode(parser, state, linkLike);
      } else {
        return false;
      }
    }

    // Maybe a reference link.
    if (char == $lbracket) {
      if (i + 1 < parser.source.length && parser.charAt(i + 1) == $rbracket) {
        // Maybe a shortcut reference link.
        var linkLike = new LinkLike.reference(text, i + 1);
        if (linkLike != null) {
          return _addNode(parser, state, linkLike);
        } else {
          return false;
        }
      }
      var linkLike = linkWalker.parseReferenceLink();
      if (linkLike != null) {
        return _addNode(parser, state, linkLike);
      } else {
        return false;
      }
    }

    // The link text (inside `[...]`) was not followed with a opening `(` nor
    // an opening `[`. Perhaps just a simple shortcut reference link (`[...]`).
    var linkLike = new LinkLike.reference(text, i - 1);
    if (linkLike != null) {
      return _addNode(parser, state, linkLike);
    } else {
      return false;
    }
  }

  Node _resolve(LinkLike linkLike,
      {String text,
      Map<String, LinkReference> linkReferences,
      Resolver resolver}) {
    if (linkLike.isReference) {
      var linkReference = linkReferences[linkLike.label];
      if (linkReference != null) {
        return resolver(linkReference.destination, linkReference.title);
      } else {
        // This link has no reference definition. But we allow users of the
        // library to specify a custom resolver function ([customResolver]) that
        // may choose to handle this. Otherwise, it's just treated as plain
        // text.
        if (linkResolver == null) {
          return null;
        }

        return linkResolver(text);
      }
    } else {
      // Inline link.
      return resolver(linkLike.destination, linkLike.title);
    }
  }

  // Add a link node to [parser]'s AST.
  //
  // If [label] is present, the potential link is treated as a reference link.
  // Otherwise, it is treated as an inline link.
  //
  // Returns whether the link-like was added successfully.
  bool _addNode(InlineParser parser, TagState state, LinkLike linkLike) {
    var text = parser.source.substring(state.endPos, parser.pos);
    var element = _resolve(linkLike,
        text: text, linkReferences: parser.document.linkReferences,
        resolver: (String destination, [String title]) {
      var element = new Element('a', state.children);
      element.attributes['href'] = escapeAttribute(
          destination.replaceAll(r'\(', '(').replaceAll(r'\)', ')'));
      if (title != null && title.isNotEmpty) {
        element.attributes['title'] = escapeAttribute(title);
      }
      return element;
    });
    if (element == null) {
      return false;
    }
    parser.addNode(element);
    parser.pos = linkLike.endPos;
    parser.start = parser.pos;
    _pendingStatesAreActive = false;
    return true;
  }
}

/// Matches images like `![alternate text](url "optional title")` and
/// `![alternate text][label]`.
class ImageSyntax extends LinkSyntax {
  ImageSyntax({Resolver linkResolver})
      : super(linkResolver: linkResolver, pattern: r'!\[');

  // Add an image node to [parser]'s AST.
  //
  // If [label] is present, the potential image is treated as a reference image.
  // Otherwise, it is treated as an inline image.
  //
  // Returns whether the image was added successfully.
  bool _addNode(InlineParser parser, TagState state, LinkLike linkLike) {
    var text = parser.source.substring(state.endPos, parser.pos);
    var element = _resolve(linkLike,
        text: text, linkReferences: parser.document.linkReferences,
        resolver: (String destination, [String title]) {
      var element = new Element.empty('img');
      element.attributes['src'] = escapeHtml(destination);
      element.attributes['alt'] = state?.textContent ?? '';
      if (title != null && title.isNotEmpty) {
        element.attributes['title'] = escapeAttribute(title);
      }
      return element;
    });
    if (element == null) {
      return false;
    }
    parser.addNode(element);
    parser.pos = linkLike.endPos;
    parser.start = parser.pos;
    return true;
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

  bool tryMatch(InlineParser parser) {
    if (parser.pos > 0 && parser.charAt(parser.pos - 1) == $backquote) {
      // Not really a match! We can't just sneak past one backtick to try the
      // next character. An example of this situation would be:
      //
      //     before ``` and `` after.
      //             ^--parser.pos
      return false;
    }

    var match = pattern.matchAsPrefix(parser.source, parser.pos);
    if (match == null) {
      return false;
    }
    parser.writeText();
    if (onMatch(parser, match)) parser.consume(match[0].length);
    return true;
  }

  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(new Element.text('code', escapeHtml(match[2].trim())));
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

  bool onMatch(InlineParser parser, Match match) {
    var alias = match[1];
    var emoji = emojis[alias];
    if (emoji == null) {
      parser.advanceBy(1);
      return false;
    }
    parser.addNode(new Text(emoji));

    return true;
  }
}

/// Keeps track of a currently open tag while it is being parsed.
///
/// The parser maintains a stack of these so it can handle nested tags.
class TagState {
  /// The point in the original source where this tag started.
  final int startPos;

  /// The point in the original source where open tag ended.
  final int endPos;

  /// The syntax that created this node.
  final TagSyntax syntax;

  /// The children of this node. Will be `null` for text nodes.
  final List<Node> children;

  final _DelimiterRun openingDelimiterRun;

  TagState(this.startPos, this.endPos, this.syntax, this.openingDelimiterRun)
      : children = <Node>[];

  /// Attempts to close this tag by matching the current text against its end
  /// pattern.
  bool tryMatch(InlineParser parser) {
    var endMatch = syntax.endPattern.matchAsPrefix(parser.source, parser.pos);
    if (endMatch == null) {
      return false;
    }

    if (!syntax.requiresDelimiterRun) {
      // Close the tag.
      close(parser, endMatch);
      return true;
    }

    // TODO: Move this logic into TagSyntax.
    var runLength = endMatch.group(0).length;
    var openingRunLength = endPos - startPos;
    var closingMatchStart = parser.pos;
    var closingMatchEnd = parser.pos + runLength - 1;
    var closingDelimiterRun =
        _DelimiterRun.tryParse(parser, closingMatchStart, closingMatchEnd);
    if (closingDelimiterRun != null && closingDelimiterRun.canClose) {
      // Emphasis rules #9 and #10:
      var oneRunOpensAndCloses =
          (openingDelimiterRun.canOpen && openingDelimiterRun.canClose) ||
              (closingDelimiterRun.canOpen && closingDelimiterRun.canClose);
      if (oneRunOpensAndCloses &&
          (openingRunLength + closingDelimiterRun.length) % 3 == 0) {
        return false;
      }
      // Close the tag.
      close(parser, endMatch);
      return true;
    } else {
      return false;
    }
  }

  /// Pops this tag off the stack, completes it, and adds it to the output.
  ///
  /// Will discard any unmatched tags that happen to be above it on the stack.
  /// If this is the last node in the stack, returns its children.
  List<Node> close(InlineParser parser, Match endMatch) {
    // If there are unclosed tags on top of this one when it's closed, that
    // means they are mismatched. Mismatched tags are treated as plain text in
    // markdown. So for each tag above this one, we write its start tag as text
    // and then adds its children to this one's children.
    var index = parser._stack.indexOf(this);

    // Remove the unmatched children.
    var unmatchedTags = parser._stack.sublist(index + 1);
    parser._stack.removeRange(index + 1, parser._stack.length);

    // Flatten them out onto this tag.
    for (var unmatched in unmatchedTags) {
      // Write the start tag as text.
      parser.writeTextRange(unmatched.startPos, unmatched.endPos);

      // Bequeath its children unto this tag.
      children.addAll(unmatched.children);
    }

    // Pop this off the stack.
    parser.writeText();
    parser._stack.removeLast();

    // If the stack is empty now, this is the special "results" node.
    if (parser._stack.length == 0) return children;

    // We are still parsing, so add this to its parent's children.
    if (syntax.onMatchEnd(parser, endMatch, this)) {
      parser.consume(endMatch[0].length);
    } else {
      // Didn't close correctly so revert to text.
      parser.start = startPos;
      parser.pos = parser.start;
      parser.advanceBy(endMatch[0].length);
    }

    return null;
  }

  String get textContent =>
      children.map((Node child) => child.textContent).join('');
}
