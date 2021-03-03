import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _emojisJsonRawUrl =
    'https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json';
final _emojisFilePath = 'lib/src/emojis.dart';

Future<Null> main() async {
  var client = HttpClient();
  var request = await client.getUrl(Uri.parse(_emojisJsonRawUrl));
  var response = await request.close();
  var json = jsonDecode(
          await response.cast<List<int>>().transform(utf8.decoder).join(''))
      .map((String emoji, dynamic aliases) =>
          MapEntry(emoji, aliases.cast<String>()))
      .cast<String, List<String>>();
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
  json.forEach((String emoji, List<String> aliases) {
    if (aliases.isNotEmpty) {
      emojisContent.writeln("  '${aliases.first}': '$emoji',");
      emojiCount++;
    } else {
      ignored.add(emoji);
    }
  });
  emojisContent.writeln('};');
  File(_emojisFilePath).writeAsStringSync(emojisContent.toString());
  print('Wrote data to $_emojisFilePath for $emojiCount emojis, '
      'ignoring ${ignored.length}: ${ignored.join(', ')}.');
  exit(0);
}
