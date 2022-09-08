import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _blnsJsonRawUrl =
    'https://github.com/minimaxir/big-list-of-naughty-strings/raw/master/blns.json';
const _blnsFilePath = 'test/blns.dart';

Future<void> main() async {
  final client = HttpClient();
  List<String> json;
  try {
    final request = await client.getUrl(Uri.parse(_blnsJsonRawUrl));
    final response = await request.close();
    final source =
        await response.cast<List<int>>().transform(utf8.decoder).join('');
    json = (jsonDecode(source) as List).cast<String>();
  } finally {
    client.close();
  }
  final blnsContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from big-list-of-naughty-strings's JSON file:
// $_blnsJsonRawUrl
// at ${DateTime.now()} by the script, tool/update_blns.dart.

// ignore_for_file: text_direction_code_point_in_literal, use_raw_strings

''');
  blnsContent.writeln('const blns = <String>[');
  for (final str in json) {
    final escaped = str
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
    blnsContent.writeln("  '$escaped',");
  }
  blnsContent.writeln('];');
  File(_blnsFilePath).writeAsStringSync(blnsContent.toString());
}
