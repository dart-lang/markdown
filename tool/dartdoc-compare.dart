import 'dart:convert' show JSON;
import 'dart:io' show Directory, File, Process, exitCode;

import 'package:args/args.dart' show ArgParser;
import 'package:path/path.dart' show absolute;
import 'package:yaml/yaml.dart' show loadYaml;

const _dartdocDir = 'dartdoc-dir';
const _markdownBefore = 'before';
const _markdownAfter = 'after';
const _sdk = 'sdk';
const _help = 'help';

void main(List<String> arguments) {
  final parser = new ArgParser()
    ..addSeparator("Usage: dartdoc-compare.dart [OPTIONS] <dart-package>")
    ..addOption(_dartdocDir, help: "Directory of the dartdoc package")
    ..addOption(_markdownBefore, help: "Markdown package 'before' ref")
    ..addOption(_markdownAfter,
        defaultsTo: "HEAD", help: "Markdown package 'after' ref")
    ..addFlag(_sdk,
        defaultsTo: false, negatable: false, help: "Is the package the SDK?")
    ..addFlag(_help, abbr: "h", hide: true);
  var options = parser.parse(arguments);
  if (options[_help]) {
    print(parser.usage);
    exitCode = 0;
    return;
  }
  if (options[_dartdocDir] == null || options[_markdownBefore] == null) {
    print(
        "Invalid arguments: Options --$_dartdocDir and --$_markdownBefore must be specified");
    print(parser.usage);
    exitCode = 1;
    return;
  }
  var comparer = new DartdocCompare(
      options[_dartdocDir],
      options[_markdownBefore],
      options[_markdownAfter],
      absolute(options[_dartdocDir], "bin/dartdoc.dart"),
      absolute(options[_dartdocDir], "pubspec.yaml"),
      options[_sdk]);

  var package = options.rest.first;

  if (comparer.compare(package)) {
    exitCode = 0;
  } else {
    exitCode = 1;
  }
}

class DartdocCompare {
  final String dartdocDir;
  final String markdownBefore;
  final String markdownAfter;
  final String dartdocBin;
  final String dartdocPubspecPath;
  final bool sdk;

  DartdocCompare(this.dartdocDir, this.markdownBefore, this.markdownAfter,
      this.dartdocBin, this.dartdocPubspecPath, this.sdk);

  bool compare(String package) {
    // Generate docs with Markdown "A".
    var out_before = _runDartdoc(markdownBefore, package);

    // Generate docs with Markdown "B".
    var out_after = _runDartdoc(markdownAfter, package);

    // Compare outputs
    var diffOptions = ["-r", "-B", out_before, out_after];
    var result = Process.runSync("diff", diffOptions, runInShell: true);
    var nlines = "\n".allMatches(result.stdout).length;
    print("Diff lines: $nlines");
    print("diff ${diffOptions.join(" ")}");
    return result.exitCode == 0;
  }

  String _runDartdoc(String markdownRef, String package) {
    print("==========================================================");
    print("Running dartdoc for $markdownRef...");
    print("==========================================================");
    _doInPath(dartdocDir, () => _updateDartdocPubspec(markdownRef));
    return _doInPath(package, () {
      if (!sdk) _system('pub', ['get']);
      var out = Directory.systemTemp
          .createTempSync("dartdoc-compare-${markdownRef}__");
      var sdk_options =
          sdk ? ["--sdk-docs", "--dart-sdk=$package"] : <String>[];
      var cmd = "dart";
      var args = ["$dartdocBin", "--output=${out.path}"]..addAll(sdk_options);
      print("Command: $cmd ${args.join(" ")}");
      _system(cmd, args);
      print("");

      return out.path;
    });
  }

  int _updateDartdocPubspec(String markdownRef) {
    var dartdocPubspec =
        loadYaml(new File(dartdocPubspecPath).readAsStringSync()) as Map;
    // make modifiable copy
    dartdocPubspec = JSON.decode(JSON.encode(dartdocPubspec));

    dartdocPubspec['dependencies']['markdown'] = {
      'git': {
        'url': 'git://github.com/dart-lang/markdown.git',
        'ref': markdownRef
      }
    };

    new File(dartdocPubspecPath).writeAsStringSync(JSON.encode(dartdocPubspec));
    return _system('pub', ['get']);
  }
}

int _system(String cmd, List<String> args) {
  var result = Process.runSync(cmd, args);
  print(result.stdout);
  print(result.stderr);
  return result.exitCode;
}

T _doInPath<T>(String path, T f()) {
  var former = Directory.current.path;
  Directory.current = path;
  var result = f();
  Directory.current = former;
  return result;
}
