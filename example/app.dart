// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart';

import 'highlight.dart';

final markdownInput =
    document.querySelector('#markdown') as HTMLTextAreaElement;
final htmlDiv = document.querySelector('#html') as HTMLDivElement;
final versionSpan = document.querySelector('.version') as HTMLSpanElement;

const typing = Duration(milliseconds: 150);
const introText = '''Markdown is the **best**!

* It has lists.
* It has [links](https://dart.dev).
* It has...
  ```dart
  void sourceCode() {}
  ```
* ...and _so much more_...''';

// Flavor support.
final basicRadio = document.querySelector('#basic-radio') as HTMLElement;
final commonmarkRadio =
    document.querySelector('#commonmark-radio') as HTMLElement;
final gfmRadio = document.querySelector('#gfm-radio') as HTMLElement;
md.ExtensionSet? extensionSet;

final extensionSets = {
  'basic-radio': md.ExtensionSet.none,
  'commonmark-radio': md.ExtensionSet.commonMark,
  'gfm-radio': md.ExtensionSet.gitHubWeb,
};

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

  // GitHub is the default extension set.
  gfmRadio.attributes.getNamedItem('checked')?.value = '';
  gfmRadio.querySelector('.glyph')!.text = 'radio_button_checked';
  extensionSet = extensionSets[gfmRadio.id];
  _renderMarkdown();

  basicRadio.onClick.listen(_switchFlavor);
  commonmarkRadio.onClick.listen(_switchFlavor);
  gfmRadio.onClick.listen(_switchFlavor);
}

void _renderMarkdown([Event? event]) {
  final markdown = markdownInput.value;

  htmlDiv.innerHTML = md.markdownToHtml(markdown, extensionSet: extensionSet);

  for (final block in htmlDiv.querySelectorAll('pre code').items) {
    try {
      highlightElement(block);
    } catch (e) {
      console.error('Error highlighting markdown:'.toJS);
      console.error(e.toString().toJS);
    }
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

void _switchFlavor(Event e) {
  final target = e.currentTarget as HTMLElement;
  if (target.attributes.getNamedItem('checked') == null) {
    if (basicRadio != target) {
      basicRadio.attributes.safeRemove('checked');
      basicRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }
    if (commonmarkRadio != target) {
      commonmarkRadio.attributes.safeRemove('checked');
      commonmarkRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }
    if (gfmRadio != target) {
      gfmRadio.attributes.safeRemove('checked');
      gfmRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }

    target.attributes.getNamedItem('checked')?.value = '';
    target.querySelector('.glyph')!.text = 'radio_button_checked';
    extensionSet = extensionSets[target.id];
    _renderMarkdown();
  }
}

extension on NodeList {
  List<Node> get items => [
        for (var i = 0; i < length; i++) item(i)!,
      ];
}

extension on NamedNodeMap {
  void safeRemove(String qualifiedName) {
    if (getNamedItem(qualifiedName) != null) removeNamedItem(qualifiedName);
  }
}
