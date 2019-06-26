import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _blnsJsonRawUrl =
    'https://github.com/minimaxir/big-list-of-naughty-strings/raw/master/blns.json';
final _blnsFilePath = 'test/blns.dart';

Future<Null> main() async {
  var client = HttpClient();
  List<String> json;
  try {
    var request = await client.getUrl(Uri.parse(_blnsJsonRawUrl));
    var response = await request.close();
    json = (jsonDecode(await response
            .cast<List<int>>()
            .transform(utf8.decoder)
            .join('')) as List)
        .cast<String>();
  } finally {
    client.close();
  }
  var blnsContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from big-list-of-naughty-strings's JSON file:
// $_blnsJsonRawUrl
// at ${DateTime.now()} by the script, tool/update_blns.dart.

''');
  blnsContent.writeln('const blns = <String>[');
  for (var str in json) {
    var escaped = str
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
    blnsContent.writeln("  '$escaped',");
  }
  blnsContent.writeln('];');
  File(_blnsFilePath)..writeAsStringSync(blnsContent.toString());
}
