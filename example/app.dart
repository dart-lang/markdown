// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown/src/block_parser.dart';
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
final basicRadio = querySelector('#basic-radio') as HtmlElement;
final commonmarkRadio = querySelector('#commonmark-radio') as HtmlElement;
final gfmRadio = querySelector('#gfm-radio') as HtmlElement;
md.ExtensionSet? extensionSet;

final extensionSets = {
  'basic-radio': md.ExtensionSet.none,
  'commonmark-radio': md.ExtensionSet.commonMark,
  'gfm-radio': md.ExtensionSet.gitHubWeb,
};

const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
final Random rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

Map<String, String?> bookmarks = {};

bool checkAllBookmarks() {
  for (final v in bookmarks.values) {
    if (v == null) {
      return false;
    }
  }
  return true;
}

String dumpBookmarks(String bookmarkedHtml) {
  bookmarks.forEach((final String k, final String? v) {
    print(
        "Bookmark $k = ${v == null ? 'UNRESOLVED' : '${v.substring(0, 10)}...'}");
    if (v != null) {
      bookmarkedHtml = bookmarkedHtml.replaceFirst(k, v);
    }
  });
  return bookmarkedHtml;
}

class KrokiDiagramEndpoints {
  /*static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';
  static String  = '';  static String  = '';*/
  static String bytefield = 'bytefield';
  static String c4plantuml = 'c4plantuml';
  static String ditaa = 'ditaa';
  static String erd = 'erd';
  static String graphviz = 'graphviz';
  static String dot = 'dot';
  static String mermaid = 'mermaid';
  static String nomnoml = 'nomnoml';
  static String pikchr = 'pikchr';
  static String plantuml = 'plantuml';
  static String structurizr = 'structurizr';
  static String svgbob = 'svgbob';
  static String umlet = 'umlet';
  static String vega = 'vega';
  static String vegalite = 'vegalite';
  static String wavedrom = 'wavedrom';
}

/// Checks if you are awesome. Spoiler: you are.
class Kroki {
  final http.Client _client;

  static const String _krokiApiUrl = 'https://kroki.io/';

/*
Diagram Type	png	svg	jpeg	pdf	base64
BlockDiag️
BPMN️
Bytefield️
SeqDiag️
ActDiag️
NwDiag️
PacketDiag️
RackDiag️
C4 with PlantUML
Ditaa️
Erd️
Excalidraw️
GraphViz
Mermaid
Nomnoml
Pikchr️
PlantUML
Structurizr
Svgbob
UMlet
Vega️
Vega-Lite️
WaveDrom

<td><a href="https://github.com/blockdiag/blockdiag">BlockDiag</a></td>

<td><a href="https://github.com/bpmn-io/bpmn-js">BPMN</a></td>

<td><a href="https://github.com/Deep-Symmetry/bytefield-svg/">Bytefield</a></td>

<td><a href="https://github.com/blockdiag/seqdiag">SeqDiag</a></td>

<td><a href="https://github.com/blockdiag/actdiag">ActDiag</a></td>

<td><a href="https://github.com/blockdiag/nwdiag">NwDiag</a></td>

<td><a href="https://github.com/blockdiag/nwdiag">PacketDiag</a></td>

<td><a href="https://github.com/blockdiag/nwdiag">RackDiag</a></td>

<td><a href="https://github.com/RicardoNiepel/C4-PlantUML">C4 with PlantUML</a></td>

<td><a href="http://ditaa.sourceforge.net">Ditaa</a></td>

<td><a href="https://github.com/BurntSushi/erd">Erd</a></td>

<td><a href="https://github.com/excalidraw/excalidraw">Excalidraw</a></td>

<td><a href="https://www.graphviz.org/">GraphViz</a></td>

<td><a href="https://github.com/knsv/mermaid">Mermaid</a></td>

<td><a href="https://github.com/skanaar/nomnoml">Nomnoml</a></td>

<td><a href="https://github.com/drhsqlite/pikchr">Pikchr</a></td>

<td><a href="https://github.com/plantuml/plantuml">PlantUML</a></td>

<td><a href="https://github.com/structurizr/dsl">Structurizr</a></td>

<td><a href="https://github.com/ivanceras/svgbob">Svgbob</a></td>

<td><a href="https://github.com/umlet/umlet">UMlet</a></td>

<td><a href="https://github.com/vega/vega">Vega</a></td>

<td><a href="https://github.com/vega/vega-lite">Vega-Lite</a></td>

<td><a href="https://github.com/wavedrom/wavedrom">WaveDrom</a></td>

*/
  Kroki({
    http.Client? client,
  }) : _client = client ?? http.Client();

  String _getEndpointFromDiagramType(String diagramType) {
    return diagramType;
  }

  Future<String> convertDiagram(
      String diagramType, String diagramSource) async {
    final String endpoint =
        _getEndpointFromDiagramType(_getEndpointFromDiagramType(diagramType));

    final stringBytes = utf8.encode(diagramSource);
    try {
      final gzipBytes = ZLibEncoder().encode(stringBytes, level: 9);
      final compressedString = base64Url.encode(gzipBytes);

      print(compressedString);

      //final encoded =Uri.encodeFull(compressedString);

      final theuri = Uri.parse('$_krokiApiUrl/$endpoint/svg/$compressedString');
      //theuri = Uri.parse('https://kroki.io/mermaid/svg/eNpljzFuwzAMRXefgtlrZzcKBymCtMjQoTegZdYiwoqqTLfw7SMrSDKEi4j_H6nPaqLfmYKjA-OY8KeCXBGTseOIwWAv7OhJfdO-aMWtu5P60MIHiSis_Qt4_QdMBIvOu0KKaswEinnnyZ2LuNbK3zYcefQGOCKHycAvUZ3XMCTGglMYyvupRpAKq99wHf1CYw0oYF7n7Ezw2qdtFxP9IUvTNNX9s7orsVt4T4S2eRhdPiufsUbvdbZH-KzXt4wnFVlgVB021QUIImOl');

      print('the url we made is $theuri');

      final response = await _client.get(theuri);

      if (response.statusCode == 404) {
        throw Exception('status code 404 contentNotFound');
      } else if (response.statusCode == 403) {
        throw Exception('status code 403 rateLimitExceeded');
      } else if (response.statusCode != 200) {
        throw Exception('status code ${response.statusCode} error unknown');
      }

      print("GOT SVG = ``${response.body.substring(0, 20)}``");
      return response.body;
    } catch (e) {
      return 'gzip compression error $e';
    }
  }
}

final Kroki kroki = Kroki();

class DiagramTransfomer extends md.CodeBlockTransformer {
  ///List<String> handledCodeBlockTypes = ['mermaid', 'wavedrom'];

  @override
  md.Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, BlockParser parser) {
    final String bookmark = getRandomString(30);

    final md.AsyncText asyncText = md.AsyncText(parser,
        initialPendingTextMessage: 'The bookmark is $bookmark');

    bookmarks[bookmark] = null;

    // () async {
    //   await kroki.convertDiagram(codeBlockType, rawCodeBlock).then((svg){
    //     print('Setting $bookmark to returnsvg = ${svg.substring(0,20)}');
    //     bookmarks[bookmark] = svg;
    //   }).onError((error, stackTrace) {
    //     print('Exception $error creating svg for $bookmark');
    //     print(stackTrace);
    //     bookmarks[bookmark] = 'Exception $error creating svg for $bookmark';
    //   });
    // } ();

    asyncText.asyncFutureText =
        kroki.convertDiagram(codeBlockType, rawCodeBlock).then((svg) {
      asyncText.asyncTextVal = svg;
      asyncText.isComplete = true;
      print('Setting $bookmark to returnsvg = ${svg.substring(0, 20)}');
      return svg;
    }).onError((error, stackTrace) {
      asyncText.asyncTextVal = 'Exception $error creating svg for $bookmark';
      asyncText.isComplete = true;
      print('Exception $error creating svg for $bookmark');
      print(stackTrace);
      return asyncText.asyncTextVal!;
    });

    print('Remembered bookmark $bookmark');
    return asyncText;
  }

  DiagramTransfomer() {
    handledCodeBlockTypes = ['mermaid', 'wavedrom'];
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
      savedMarkdown != introText) {
    markdownInput.value = savedMarkdown;
    markdownInput.focus();
    _renderMarkdown();
  } else {
    _typeItOut(mermaidExample, mermaidExample.length); //introText, 82);
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

  String bookmarkedHtml = await md.markdownToHtmlWithAsyncTransforms(markdown,
      blockSyntaxes: [diagramTransformingFencedCodeBlock],
      extensionSet: extensionSet);

  /* CheckAndFileBookmarks() {
    print('Checking bookmarks');
    if (checkAllBookmarks()) {
      print('Done -fixing up');
      bookmarkedHtml = dumpBookmarks(bookmarkedHtml);
      htmlDiv.setInnerHtml(
        bookmarkedHtml,
        treeSanitizer: nullSanitizer,
      );
    } else {
      Timer(Duration(milliseconds: 250), CheckAndFileBookmarks);
    }
  }

  Timer(Duration(milliseconds: 250), CheckAndFileBookmarks);
 */
   htmlDiv.setInnerHtml(bookmarkedHtml,
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

const String mermaidExample = """
```
Test language not specified code block
```

```dart
 mermaid.initialize(Config(theme:Theme.Dark));
```

:merman: Mermaid :mermaid: Diagram Types
Mermaid Diagram Types
=====================

Here are examples of various mermaid diagram types

[Flowchart](http://mermaid-js.github.io/mermaid/#/./flowchart?id=flowcharts-basic-syntax)
-----------
```mermaid
graph TD;
    A-->B;
    A-->C;
    B-->D;
    C-->D;
```

[Sequence Diagram](http://mermaid-js.github.io/mermaid/#/./sequenceDiagram)
------------------
```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    Alice->>John: Hello John, how are you?
    loop Healthcheck
        John->>John: Fight against hypochondria
    end
    Note right of John: Rational thoughts <br/>prevail!
    John-->>Alice: Great!
    John->>Bob: How about you?
    Bob-->>John: Jolly good!
```

[Gantt Diagram](http://mermaid-js.github.io/mermaid/#/./gantt)
----
```mermaid
gantt
dateFormat  YYYY-MM-DD
title Adding GANTT diagram to mermaid
excludes weekdays 2014-01-10

section A section
Completed task            :done,    des1, 2014-01-06,2014-01-08
Active task               :active,  des2, 2014-01-09, 3d
Future task               :         des3, after des2, 5d
Future task2               :         des4, after des3, 5d
```

[Class Diagram](http://mermaid-js.github.io/mermaid/#/./classDiagram)
----
```mermaid
classDiagram
Class01 <|-- AveryLongClass : Cool
Class03 *-- Class04
Class05 o-- Class06
Class07 .. Class08
Class09 --> C2 : Where am i?
Class09 --* C3
Class09 --|> Class07
Class07 : equals()
Class07 : Object[] elementData
Class01 : size()
Class01 : int chimp
Class01 : int gorilla
Class08 <--> C2: Cool label
```

[User Journey Diagram](http://mermaid-js.github.io/mermaid/#/./user-journey)
-----
```mermaid
journey
    title My working day
    section Go to work
      Make tea: 5: Me
      Go upstairs: 3: Me
      Do work: 1: Me, Cat
    section Go home
      Go downstairs: 5: Me
      Sit down: 5: Me
```

[Pie Chart Diagram](http://mermaid-js.github.io/mermaid/#/pie?id=pie-chart-diagrams)
-----
```mermaid
pie showData
    title Key elements in Product X
    "Calcium" : 42.96
    "Potassium" : 50.05
    "Magnesium" : 10.01
    "Iron" :  5
```

[State diagram](http://mermaid-js.github.io/mermaid/#/stateDiagram?id=state-diagrams)
-----
```mermaid
stateDiagram-v2
    [*] --> Still
    Still --> [*]

    Still --> Moving
    Moving --> Still
    Moving --> Crash
    Crash --> [*]
```

[Entity Relationship Diagram](http://mermaid-js.github.io/mermaid/#/entityRelationshipDiagram?id=entity-relationship-diagrams)
-------
```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
```

[Requirement Diagram](http://mermaid-js.github.io/mermaid/#/requirementDiagram?id=requirement-diagram)
---------------
```mermaid
requirementDiagram

    requirement test_req {
    id: 1
    text: the test text.
    risk: high
    verifymethod: test
    }

    element test_entity {
    type: simulation
    }

    test_entity - satisfies -> test_req
```

[Gitgraph Diagrams](http://mermaid-js.github.io/mermaid/#/gitgraph?id=gitgraph-diagrams)
-------
```mermaid
       gitGraph
       commit
       branch develop
       commit tag:"v1.0.0"
       commit
       checkout main
       commit type: HIGHLIGHT
       commit
       merge develop
       commit
       branch featureA
       commit
```
""";
