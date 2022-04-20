// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// TODO(srawlins): Switch to https://github.com/muan/unicode-emoji-json. This
// is definitely a breaking change; the emoji names are not necessarily the
// same.
final _emojisJsonRawUrl =
    'https://raw.githubusercontent.com/muan/emojilib/v2.4.0/emojis.json';
final _emojisFilePath = 'lib/src/emojis.dart';

Future<void> main() async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(_emojisJsonRawUrl));
  final response = await request.close();
  final json = jsonDecode(
          await response.cast<List<int>>().transform(utf8.decoder).join(''))
      .map((String alias, dynamic info) =>
          MapEntry(alias, info.cast<String, dynamic>()))
      .cast<String, Map<String, dynamic>>();
  final emojisContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from emojilib's emoji data file:
// $_emojisJsonRawUrl
// at ${DateTime.now()} by the script, tool/update_emojis.dart.

''');
  emojisContent.writeln('const emojis = <String, String>{');
  var emojiCount = 0;
  final ignored = <String>[];
  json.forEach((String alias, Map<String, dynamic> info) {
    if (info['char'] != null) {
      emojisContent.writeln("  '$alias': '${info['char']}',");
      emojiCount++;
    } else {
      ignored.add(alias);
    }
  });
  emojisContent.writeln('};');
  File(_emojisFilePath).writeAsStringSync(emojisContent.toString());
  print('Wrote data to $_emojisFilePath for $emojiCount emojis, '
      'ignoring ${ignored.length}: ${ignored.join(', ')}.');
  exit(0);
}
