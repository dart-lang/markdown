// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:kroki/kroki.dart';
import 'package:markdown/markdown.dart' as md;

import 'highlight.dart';
import 'kroki_markdown_ext.dart';

final markdownInput = querySelector('#markdown') as TextAreaElement;
final htmlDiv = querySelector('#html') as DivElement;
final versionSpan = querySelector('.version') as SpanElement;

final nullSanitizer = NullTreeSanitizer();

String sampleDiagramsText = buildSamplesText(1, 10);
bool useLocalStorageVersion = false;

// Flavor support.
final basicRadio = querySelector('#basic-radio') as HtmlElement;
final commonmarkRadio = querySelector('#commonmark-radio') as HtmlElement;
final gfmRadio = querySelector('#gfm-radio') as HtmlElement;

// samples groups radio buttons.
final group1Radio = querySelector('#group1-radio') as HtmlElement;
final group2Radio = querySelector('#group2-radio') as HtmlElement;
final group3Radio = querySelector('#group3-radio') as HtmlElement;

// extension set choices
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

  if (useLocalStorageVersion &&
      savedMarkdown != null &&
      savedMarkdown.isNotEmpty &&
      savedMarkdown != sampleDiagramsText) {
    markdownInput.value = savedMarkdown;
    markdownInput.focus();
    _renderMarkdown();
  } else {
    _setMarkdown(sampleDiagramsText);
  }

  // GitHub is the default extension set.
  gfmRadio.attributes['checked'] = '';
  gfmRadio.querySelector('.glyph')!.text = 'radio_button_checked';
  extensionSet = extensionSets[gfmRadio.id];
  _renderMarkdown();

  basicRadio.onClick.listen(_switchFlavor);
  commonmarkRadio.onClick.listen(_switchFlavor);
  gfmRadio.onClick.listen(_switchFlavor);

  // set default samples group
  group1Radio.attributes['checked'] = '';
  group1Radio.querySelector('.glyph')!.text = 'radio_button_checked';

  group1Radio.onClick.listen(_switchExamples);
  group2Radio.onClick.listen(_switchExamples);
  group3Radio.onClick.listen(_switchExamples);
}

void _renderMarkdown([Event? event]) async {
  final markdown = markdownInput.value!;

  final outputHtml = await md.markdownToHtmlWithAsyncTransforms(markdown,
      blockSyntaxes: [diagramTransformingFencedCodeBlock],
      extensionSet: extensionSet);

  htmlDiv.setInnerHtml(
    outputHtml,
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

  if (event != null) {
    // Not simulated typing. Store it.
    window.localStorage['markdown'] = markdown;
  }
}

void _setMarkdown(String newMarkdown) {
  markdownInput.value = newMarkdown;
  markdownInput.focus();
  _renderMarkdown();
}

void _switchFlavor(Event e) {
  final target = e.currentTarget as HtmlElement;
  if (!target.attributes.containsKey('checked')) {
    if (basicRadio != target) {
      basicRadio.attributes.remove('checked');
      basicRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }
    if (commonmarkRadio != target) {
      commonmarkRadio.attributes.remove('checked');
      commonmarkRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }
    if (gfmRadio != target) {
      gfmRadio.attributes.remove('checked');
      gfmRadio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }

    target.attributes['checked'] = '';
    target.querySelector('.glyph')!.text = 'radio_button_checked';
    extensionSet = extensionSets[target.id];
    _renderMarkdown();
  }
}

void _switchExamples(Event e) {
  final target = e.currentTarget as HtmlElement;
  if (!target.attributes.containsKey('checked')) {
    int groupStart = 0;
    int groupLen = 10;
    if (group1Radio != target) {
      group1Radio.attributes.remove('checked');
      group1Radio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    }
    if (group2Radio != target) {
      group2Radio.attributes.remove('checked');
      group2Radio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    } else {
      groupStart = 10;
    }
    if (group3Radio != target) {
      group3Radio.attributes.remove('checked');
      group3Radio.querySelector('.glyph')!.text = 'radio_button_unchecked';
    } else {
      groupStart = 20;
      groupLen = 15;
    }

    target.attributes['checked'] = 'true';
    target.querySelector('.glyph')!.text = 'radio_button_checked';
    sampleDiagramsText = buildSamplesText(groupStart, groupLen);
    _setMarkdown(sampleDiagramsText);
  }
}

class NullTreeSanitizer implements NodeTreeSanitizer {
  @override
  void sanitizeTree(Node node) {}
}

String buildSamplesText(int startIndex, int numTests) {
  final List<String> sampleTextBlocks = [];

  for (var i = startIndex; i < (startIndex + numTests); i++) {
    if (i >= KrokiSampleDiagrams.samples.length) break;
    final sample = KrokiSampleDiagrams.samples[i];
    sampleTextBlocks.add('''
## [${sample.name}](${sample.url})
----------------------------------
```${sample.diagramType}
${sample.diagramSource}
```
''');
  }

  return sampleTextBlocks.join('\n');
}
