// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:markdown/markdown.dart' as md;

import 'highlight.dart';

final markdownInput = querySelector('#markdown') as TextAreaElement;
final htmlDiv = querySelector('#html') as DivElement;
final versionSpan = querySelector('.version') as SpanElement;

final nullSanitizer = NullTreeSanitizer();
const typing = Duration(milliseconds: 150);
final introText = '''Markdown is the **best**!

* It has lists.
* It has [links](https://dart.dev).
* It has _so much more_...''';

// Flavor support.
// GitHub is the default extension set.
final flavors = [
  _SimpleRadioOption('Basic Markdown', md.ExtensionSet.none),
  _SimpleRadioOption('CommonMark', md.ExtensionSet.commonMark),
  _SimpleRadioOption('GitHub Flavored Markdown', md.ExtensionSet.gitHubWeb),
];
final flavorRadio = _SimpleRadioGroup('#flavor_switch', flavors);

// Output type.
enum OutputType { html, mdast }

final outputTypes = [
  _SimpleRadioOption('HTML', OutputType.html),
  _SimpleRadioOption('Markdown AST', OutputType.mdast),
];
final outputRadio = _SimpleRadioGroup('#output_switch', outputTypes);

void main() {
  versionSpan.text = 'v${md.version}';
  markdownInput.onKeyUp.listen(_renderMarkdown);

  final savedMarkdown = window.localStorage['markdown'];

  if (savedMarkdown != null &&
      savedMarkdown.isNotEmpty &&
      savedMarkdown != introText) {
    markdownInput.value = savedMarkdown;
    markdownInput.focus();
    _renderMarkdown();
  } else {
    _typeItOut(introText, 82);
  }

  _renderMarkdown();
}

void _renderMarkdown([Event? event]) {
  final markdown = markdownInput.value!;
  final outputType = outputRadio.value;
  final extensionSet = flavorRadio.value;
  htmlDiv.text = '';

  if (outputType == OutputType.html) {
    htmlDiv.setInnerHtml(
      md.markdownToHtml(markdown, extensionSet: extensionSet),
      treeSanitizer: nullSanitizer,
    );

    for (final block in htmlDiv.querySelectorAll('pre code')) {
      try {
        highlightElement(block);
      } catch (e) {
        window.console.error('Error highlighting markdown:');
        window.console.error(e);
      }
    }
  } else if (outputType == OutputType.mdast) {
    final document = md.Document(extensionSet: extensionSet);
    final nodes = document.parseLines(markdown);
    final json = JsonEncoder.withIndent("  ")
        .convert(nodes.map((e) => e.toMap()).toList());
    htmlDiv.setInnerHtml(
      '<pre><code>$json</code></pre>',
    );
  }

  if (event != null) {
    // Not simulated typing. Store it.
    window.localStorage['markdown'] = markdown;
  }
}

void _typeItOut(String msg, int pos) {
  late Timer timer;
  markdownInput.onKeyUp.listen((_) {
    timer.cancel();
  });
  void addCharacter() {
    if (pos > msg.length) {
      return;
    }
    markdownInput.value = msg.substring(0, pos);
    markdownInput.focus();
    _renderMarkdown();
    pos++;
    timer = Timer(typing, addCharacter);
  }

  timer = Timer(typing, addCharacter);
}

class NullTreeSanitizer implements NodeTreeSanitizer {
  @override
  void sanitizeTree(Node node) {}
}

class _SimpleRadioGroup<T> {
  final List<_SimpleRadioOption<T>> options;
  final _radios = <_SimpleRadio<T>>[];
  int checkedIndex;
  T value;

  _SimpleRadioGroup(String containerId, this.options, {this.checkedIndex = 0})
      : value = options[checkedIndex].value {
    _render(containerId, checkedIndex);
  }

  void _render(String containerId, int checkedIndex) {
    final container = querySelector(containerId) as HtmlElement;
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      final checked = i == checkedIndex;
      final radio = _SimpleRadio<T>(
        option.label,
        option.value,
        checked,
      );
      radio.element.onClick.listen((event) {
        if (i == checkedIndex) {
          return;
        }
        _radios[checkedIndex].check(false);
        radio.check(true);
        value = radio.value;
        checkedIndex = i;
        _renderMarkdown();
      });
      container.append(radio.element);
      _radios.add(radio);
    }
  }
}

class _SimpleRadio<T> {
  final Element element;
  final Element _icon;
  final T value;

  _SimpleRadio(String label, this.value, bool checked)
      : element = DivElement(),
        _icon = document.createElement('i') {
    element
      ..className = 'radio'
      ..append(_icon..className = 'glyph')
      ..appendText(label);
    check(checked);
  }

  void check(bool checked) {
    _icon.text = checked ? 'radio_button_checked' : 'radio_button_unchecked';
  }
}

class _SimpleRadioOption<T> {
  final String label;
  final T value;
  _SimpleRadioOption(this.label, this.value);
}
