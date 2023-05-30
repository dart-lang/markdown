// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'update_shared.dart';

// update_github_emojis.dart now generates the emoji list using the GitHub API
// to retrieve the emoji list.  It uses this emoji source as a source to keep
// binary compatibility with the Unicode sequences for each emoji found here.
const _emojisJsonRawUrl =
    'https://raw.githubusercontent.com/muan/emojilib/v2.4.0/emojis.json';
const _emojisFilePath = 'lib/src/legacy_emojis.dart';

Future<void> main() async {
  final json =
      (await downloadJson(_emojisJsonRawUrl) as Map<String, dynamic>).map(
    (String alias, dynamic info) =>
        MapEntry(alias, info as Map<String, dynamic>),
  );
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
  // Dump in sorted order now to facilitate comparison with new GitHub emoji.
  final sortedKeys = json.keys.toList()..sort();
  for (final alias in sortedKeys) {
    final info = json[alias] as Map<String, dynamic>;
    if (info['char'] != null) {
      emojisContent.writeln("  '$alias': '${info['char']}',");
      emojiCount++;
    } else {
      ignored.add(alias);
    }
  }
  emojisContent.writeln('};');
  File(_emojisFilePath).writeAsStringSync(emojisContent.toString());
  print('WARNING: This updates only the LEGACY emoji - to update the active\n'
      'emoji recognized by the markdown package, execute `update_github_emojis.dart`.\n');
  print('Wrote data to $_emojisFilePath for $emojiCount emoji, '
      'ignoring ${ignored.length}: ${ignored.join(', ')}.');
}
