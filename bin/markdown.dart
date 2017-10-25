import 'dart:async';
import 'dart:io';

import 'package:markdown/markdown.dart';

Future main(List<String> args) async {
  if (args.length > 1) {
    print('Usage: markdown.dart [file]');
    exitCode = 1;
    return;
  }

  if (args.length == 1) {
    switch (args.first) {
      case '--help':
        print('''Usage:
    markdown [markdown file]
        Convert [markdown-file] from Markdown to HTML. If no file is passed on
        the commandline, then the Markdown source is read from STDIN.

    markdown --version
        Print the markdown package version.

    markdown --help
        Print this help text.
  ''');
        return;

      case '--version':
        print(version);
        return;

      default:
        // Read argument as a file path.
        print(markdownToHtml(new File(args[0]).readAsStringSync()));
        return;
    }
  }

  // Read from stdin.
  var buffer = new StringBuffer();
  String line;
  while ((line = stdin.readLineSync()) != null) {
    buffer.writeln(line);
  }
  print(markdownToHtml(buffer.toString()));
}
