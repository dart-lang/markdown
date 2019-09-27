import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:markdown/markdown.dart';

final extensionSets = <String, ExtensionSet>{
  'none': ExtensionSet.none,
  'CommonMark': ExtensionSet.commonMark,
  'GitHubFlavored': ExtensionSet.gitHubFlavored,
  'GitHubWeb': ExtensionSet.gitHubWeb,
};

Future<void> main(List<String> args) async {
  var parser = ArgParser()
    ..addFlag('help', negatable: false, help: 'Print help text and exit')
    ..addFlag('version', negatable: false, help: 'Print version and exit')
    ..addOption('extension-set',
        allowed: ['none', 'CommonMark', 'GitHubFlavored', 'GitHubWeb'],
        defaultsTo: 'CommonMark',
        help: 'Specify a set of extensions',
        allowedHelp: {
          'none': 'No extensions; similar to Markdown.pl',
          'CommonMark': 'Parse like CommonMark Markdown (default)',
          'GitHubFlavored': 'Parse like GitHub Flavored Markdown',
          'GitHubWeb': 'Parse like GitHub\'s Markdown-enabled web input fields',
        });
  var results = parser.parse(args);

  if (results['help'] as bool) {
    printUsage(parser);
    return;
  }

  if (results['version'] as bool) {
    print(version);
    return;
  }

  var extensionSet = extensionSets[results['extension-set']];

  if (results.rest.length > 1) {
    printUsage(parser);
    exitCode = 1;
    return;
  }

  if (results.rest.length == 1) {
    // Read argument as a file path.
    var input = File(results.rest.first).readAsStringSync();
    print(markdownToHtml(input, extensionSet: extensionSet));
    return;
  }

  // Read from stdin.
  var buffer = StringBuffer();
  String line;
  while ((line = stdin.readLineSync()) != null) {
    buffer.writeln(line);
  }
  print(markdownToHtml(buffer.toString(), extensionSet: extensionSet));
}

void printUsage(ArgParser parser) {
  print('''Usage: markdown.dart [options] [file]

Parse [file] as Markdown and print resulting HTML. If [file] is omitted,
use stdin as input.

By default, CommonMark Markdown will be parsed. This can be changed with
the --extensionSet flag.

${parser.usage}
''');
}
