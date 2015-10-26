import 'dart:io';

import 'package:markdown/markdown.dart';

main(List<String> args) async {
  if (args.length > 1) {
    print('Usage: markdown.dart [file]');
    exit(1);
  }

  if (args.length == 1) {
    // Read argument as a file path.
    print(markdownToHtml(new File(args[0]).readAsStringSync()));
    exit(0);
  }

  // Read from stdin.
  var buffer = new StringBuffer();
  var line;
  while ((line = stdin.readLineSync()) != null) buffer.writeln(line);
  print(markdownToHtml(buffer.toString()));
}
