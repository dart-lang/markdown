import 'dart:convert' show JSON;
import 'dart:io' show Directory, File, Process;

import 'package:args/args.dart' show ArgParser;
import 'package:path/path.dart' show absolute;
import 'package:yaml/yaml.dart' show loadYaml;

int main(List<String> arguments) {
  const dartdoc_dir = 'dartdoc-dir';
  const markdown_before = 'before';
  const markdown_after = 'after';
  const sdk = 'sdk';
  const help = 'help';
  final parser = new ArgParser()
    ..addSeparator("Usage: dartdoc-compare.dart [OPTIONS] <dart-package>")
    ..addOption(dartdoc_dir, help: "Directory of the dartdoc package")
    ..addOption(markdown_before, help: "Markdown package 'before' ref")
    ..addOption(markdown_after,
        defaultsTo: "HEAD", help: "Markdown package 'after' ref")
    ..addFlag(sdk,
        defaultsTo: false, negatable: false, help: "Is the package the SDK?")
    ..addFlag(help, abbr: "h", hide: true);
  var options = parser.parse(arguments);
  if (options[help]) {
    print(parser.usage);
    return 0;
  }
  if (options[dartdoc_dir] == null || options[markdown_before] == null) {
    print(
        "Invalid arguments: Options --$dartdoc_dir and --$markdown_before must be specified");
    print(parser.usage);
    return 1;
  }
  var comparer = new DartdocCompare()
    ..dartdoc_dir = options[dartdoc_dir]
    ..markdown_before = options[markdown_before]
    ..markdown_after = options[markdown_after]
    ..dartdoc_bin = absolute(options[dartdoc_dir], "bin/dartdoc.dart")
    ..dartdoc_pubspec_path = absolute(options[dartdoc_dir], "pubspec.yaml")
    ..sdk = options[sdk];

  var package = options.rest.first;
  var success = comparer.compare(package);
  return success ? 0 : 1;
}

class DartdocCompare {
  String dartdoc_dir;
  String markdown_before;
  String markdown_after;
  String dartdoc_bin;
  String dartdoc_pubspec_path;
  bool sdk;

  bool compare(package) {
    // Generate docs with Markdown "A".
    var out_before = run_dartdoc(markdown_before, package);

    // Generate docs with Markdown "B".
    var out_after = run_dartdoc(markdown_after, package);

    // Compare outputs
    var diffOptions = ["-r", "-B", out_before, out_after];
    var result = Process.runSync("diff", diffOptions, runInShell: true);
    var nlines = "\n".allMatches(result.stdout).length;
    print("Diff lines: ${ nlines }");
    print("diff ${diffOptions.join(" ")}");
    return result == 0;
  }

  run_dartdoc(markdown_ref, package) {
    print("==========================================================");
    print("Running dartdoc for ${markdown_ref}...");
    print("==========================================================");
    doInPath(dartdoc_dir, () => update_dartdoc_pubspec(markdown_ref));
    return doInPath(package, () {
      if (!sdk)
        system('pub', ['get']);
      var out = Directory.systemTemp
          .createTempSync("dartdoc-compare-${markdown_ref}__");
      var sdk_options = sdk ? ["--sdk-docs", "--dart-sdk=$package"] : [];
      var cmd = "dart";
      var args = ["${dartdoc_bin}", "--output=${out.path}"]
          ..addAll(sdk_options);
      print("Command: $cmd ${args.join(" ")}");
      system(cmd, args);
      print("");

      return out.path;
    });
  }

  update_dartdoc_pubspec(markdown_ref) {
      var dartdoc_pubspec =
          loadYaml(new File(dartdoc_pubspec_path).readAsStringSync());
      // make modifiable copy
      dartdoc_pubspec = JSON.decode(JSON.encode(dartdoc_pubspec));

      dartdoc_pubspec['dependencies']['markdown'] = {
        'git': {
          'url': 'git://github.com/dart-lang/markdown.git',
          'ref': markdown_ref
        }
      };

      new File(dartdoc_pubspec_path)
          .writeAsStringSync(JSON.encode(dartdoc_pubspec));
      return system('pub', ['get']);
  }

  static system(cmd, args) {
    var result = Process.runSync(cmd, args);
    print(result.stdout);
    print(result.stderr);
    return result.exitCode;
  }

  static doInPath(String path, Function f) {
    var former = Directory.current.path;
    Directory.current = path;
    var result = f();
    Directory.current = former;
    return result;
  }
}
