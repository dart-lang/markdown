import 'package:polymer/polymer.dart';

main() { }

@CustomTag('my-app')
class App extends PolymerElement {
  @observable String content = """
# Dart Markdown

A standalone version of the [dartdoc markdown library][dartdoc].

Features
--------

1. Converts markdown to HTML
2. Syntax highlighting for Dart, HTML and CSS

Highlighting
------------

Currently only HTML highlighting is supported in the client, due to some
dart:io dependencies in analyzer_experimental and csslib.

```html
<html>
  <head>
    <style type="text/css">
      html { font-family: sans-serif; }
      pre { background-color: #fafafa; }
    </style>
  </head>
  <body>
    <div>Hello counter: {{count}}</div>
    <script type="application/dart">
      import 'dart:html';
      import 'package:web_ui/watcher.dart' as watchers;

      int count;
      main() {
        count = 0;
        window.setInterval(() {
          count++;
          watchers.dispatch();
        }, 1000);
      }
    </script>
  </body>
</html>
```

[dartdoc]: http://code.google.com/p/dart/source/browse/trunk/dart/sdk/lib/_internal/dartdoc/lib/markdown.dart
""";

  App.created():super.created();
}

