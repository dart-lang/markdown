import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _emojisJsonRawUrl =
    'https://github.com/muan/emojilib/raw/master/emojis.json';
final _emojisFilePath = 'lib/src/emojis.dart';

Future<Null> main() async {
  var client = HttpClient();
  var request = await client.getUrl(Uri.parse(_emojisJsonRawUrl));
  var response = await request.close();
  var json = jsonDecode(
          await response.cast<List<int>>().transform(utf8.decoder).join(''))
      .map((alias, info) => MapEntry(alias, info.cast<String, dynamic>()))
      .cast<String, Map<String, dynamic>>();
  var emojisContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from emojilib's emoji data file:
// $_emojisJsonRawUrl
// at ${DateTime.now()} by the script, tool/update_emojis.dart.

''');
  emojisContent.writeln('const emojis = <String, String>{');
  var emojiCount = 0;
  var ignored = <String>[];
  json.forEach((String alias, Map<String, dynamic> info) {
    if (info['char'] != null) {
      emojisContent.writeln("  '$alias': '${info['char']}',");
      emojiCount++;
    } else {
      ignored.add(alias);
    }
  });
  emojisContent.writeln('};');
  File(_emojisFilePath)..writeAsStringSync(emojisContent.toString());
  print('Wrote data to $_emojisFilePath for $emojiCount emojis, '
      'ignoring ${ignored.length}: ${ignored.join(', ')}.');
  exit(0);
}
