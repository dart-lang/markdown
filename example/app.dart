// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:kroki/kroki.dart';
import 'package:markdown/markdown.dart' as md;

import 'highlight.dart';

final markdownInput = querySelector('#markdown') as TextAreaElement;
final htmlDiv = querySelector('#html') as DivElement;
final versionSpan = querySelector('.version') as SpanElement;

final nullSanitizer = NullTreeSanitizer();
const typing = Duration(milliseconds: 150);
final sampleDiagramsText = buildSamplesText();

// Flavor support.
final basicRadio = querySelector('#basic-radio') as HtmlElement;
final commonmarkRadio = querySelector('#commonmark-radio') as HtmlElement;
final gfmRadio = querySelector('#gfm-radio') as HtmlElement;
md.ExtensionSet? extensionSet;

final extensionSets = {
  'basic-radio': md.ExtensionSet.none,
  'commonmark-radio': md.ExtensionSet.commonMark,
  'gfm-radio': md.ExtensionSet.gitHubWeb,
};

final Kroki kroki = Kroki();

class DiagramTransfomer extends md.CodeBlockTransformer {
  @override
  md.Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, md.BlockParser parser) {
    final md.AsyncText asyncText = md.AsyncText(
        kroki.convertDiagram(codeBlockType, rawCodeBlock), parser,
        uncompletedFutureTextValue:
            'Request made to Kroki.io to render $codeBlockType diagram');
    return asyncText;
  }

  DiagramTransfomer() {
    handledCodeBlockTypes = KrokiDiagramEndpoints.supportedEndpoints;
  }
}

var diagramTransformingFencedCodeBlock =
    md.TransformableFencedCodeBlockSyntax([DiagramTransfomer()]);

void main() {
  versionSpan.text = 'v${md.version}';
  markdownInput.onKeyUp.listen(_renderMarkdown);

  final savedMarkdown = window.localStorage['markdown'];

  if (savedMarkdown != null &&
      savedMarkdown.isNotEmpty &&
      savedMarkdown != sampleDiagramsText) {
    markdownInput.value = savedMarkdown;
    markdownInput.focus();
    _renderMarkdown();
  } else {
    _typeItOut(sampleDiagramsText, sampleDiagramsText.length);
  }

  // GitHub is the default extension set.
  gfmRadio.attributes['checked'] = '';
  gfmRadio.querySelector('.glyph')!.text = 'radio_button_checked';
  extensionSet = extensionSets[gfmRadio.id];
  _renderMarkdown();

  basicRadio.onClick.listen(_switchFlavor);
  commonmarkRadio.onClick.listen(_switchFlavor);
  gfmRadio.onClick.listen(_switchFlavor);
}

void _renderMarkdown([Event? event]) async {
  final markdown = markdownInput.value!;

  final finalHtml = await md.markdownToHtmlWithAsyncTransforms(markdown,
      blockSyntaxes: [diagramTransformingFencedCodeBlock],
      extensionSet: extensionSet);

  htmlDiv.setInnerHtml(
    finalHtml,
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

class NullTreeSanitizer implements NodeTreeSanitizer {
  @override
  void sanitizeTree(Node node) {}
}

String buildSamplesText() {
  final List<String> sampleTextBlocks = [];

  for( final sample in KrokiSampleDiagrams.samples) {
      sampleTextBlocks.add(
        '''
## [${sample.name}](${sample.url})
----------------------------------
```${sample.diagramType}
${sample.diagramSource}
```
''');
  }

  return sampleTextBlocks.join('\n');
}


