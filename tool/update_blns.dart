import 'dart:convert';
import 'dart:io';

final _blnsJsonRawUrl =
    'https://github.com/minimaxir/big-list-of-naughty-strings/raw/master/blns.json';
final _blnsFilePath = 'test/blns.dart';

Future<Null> main() async {
  var client = new HttpClient();
  var request = await client.getUrl(Uri.parse(_blnsJsonRawUrl));
  var response = await request.close();
  var json = JSON.decode(await response.transform(UTF8.decoder).join(''))
      as List<String>;
  var blnsContent = new StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from big-list-of-naughty-strings's JSON file:
// $_blnsJsonRawUrl
// at ${new DateTime.now()} by the script, tool/update_blns.dart.

''');
  blnsContent.writeln('const blns = const <String>[');
  for (var str in json) {
    var escaped = str
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
    blnsContent.writeln("  '$escaped',");
  }
  blnsContent.writeln('];');
  new File(_blnsFilePath)..writeAsStringSync(blnsContent.toString());
  exit(0);
}
