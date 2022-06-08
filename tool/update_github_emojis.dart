// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:markdown/src/legacy_emojis.dart' as legacy;

/// Regular expression to match GitHub emoji API output filenames.
RegExp gitHubEmojiApiPattern =
    RegExp(r'^[\ \t]+"(.*?)".*unicode\/([A-Fa-f0-9\-]+)\.png');

/// Regular expression to parse unicode from GitHub emoji API output filenames.
RegExp gitHubEmojiUnicodeFromFilenamePattern =
    RegExp(r'.*unicode\/([A-Fa-f0-9\-]+)\.png');

/// URL for GitHub's emoji API.  We reconcile with our legacy emoji so that
/// we don't change or break anything.
/// There are essentially only TWO (2) emoji that change and the
/// legacy emoji is still available with an alternate name.
/// The 'beetle' emoji changes from `🐞` to `🪲`, legacy available as 'lady_beetle'.
/// The 'cricket' emoji changes from `🏏` to `🦗`, legacy available as 'cricket_game'.
/// (if the -g flag us used to force using the GitHub Unicode sequences for the
/// emoji then additionally the 'email' emoji changes from '✉️' to '📧').
final _emojisJsonRawUrl = 'https://api.github.com/emojis';
final _emojisFilePath = 'lib/src/emojis.dart';

/// Reference to emoji map within legacy_emojis.dart
final legacyEmojis = legacy.emojis;

/// AUTO GENERATED by [reconcile_emojis.dart] - this only needed to be done ONCE
/// during the reconciliation process with the legacy emoji.
/// This array is ONLY USED when the --useGitHubUnicodes option is used to
/// minimize the visual differences in the output emoji.
const legacyEmojisUsedVariationModifier = [
  '263a',
  '2600',
  '2601',
  '2744',
  '2708',
  '260e',
  '2702',
  '2712',
  '270f',
  '2764',
  'd83c-de37',
  '2734',
  '3299',
  '3297',
  'd83c-dd70',
  'd83c-dd71',
  'd83c-dd7e',
  '2668',
  '203c',
  '2049',
  '303d',
  '26a0',
  '267b',
  '2747',
  '2733',
  '24c2',
  'd83c-de02',
  'd83c-dd7f',
  '23cf',
  '25b6',
  '25c0',
  '27a1',
  '2b05',
  '2b06',
  '2b07',
  '2197',
  '2198',
  '2199',
  '2196',
  '2195',
  '2194',
  '21aa',
  '21a9',
  '2934',
  '2935',
  '2139',
  '3030',
  '2714',
  '2716',
  '00a9',
  '00ae',
  '2122',
  '2611',
  '25aa',
  '25ab',
  '25fc',
  '25fb',
  '2660',
  '2663',
  '2665',
  '2666',
];

/// Special replacement character '�'
const errorSpecialReplacement = '\u{FFFD}';

const useOfGitHubUnicodeSequencesWarning = '''
IMPORTANT NOTE: The use of the --useGitHubUnicodes switch will force using
GitHub Unicode sequences.
This option is essentially here only for completeness, not for
release use.
The slight visual differences of some emoji might also be another
reason using --useGitHubUnicodes should be considered a *Breaking Change*.

Some test will fail because of the different Unicode sequences
and the emojis.unit file would need to be updated to contain the new
expected GitHub versions of the Unicode sequences of the emoji in order
for the tests to pass.
''';

/// The GitHub API URL will return a JSON map of all emoji in the form of
/// `{ 'shortcode':'emojifilename' ... }`.
/// The filenames are simply a list of all of the hex string of the
/// *essential* Unicode codepoints representing the emoji.
/// These sequences exclude the Unicode join zero width (0x200D) and
/// variation select (0xFE0F) modifiers. (We will need to add these in to
/// build our actually Unicode strings representing the emoji).
/// Multiple Unicode codepoints are separated by '-'.
/// Examples filenames (single and double code point examples):
///  - "https://github.githubassets.com/images/icons/emoji/unicode/1f643.png?v8"
///  - "https://github.githubassets.com/images/icons/emoji/unicode/1f1fa-1f1fe.png?v8"
///  - "https://github.githubassets.com/images/icons/emoji/unicode/1f469-1f469-1f467-1f466.png?v8"
/// NOTE: Some filenames will be GitHub 'custom' emoji that have no Unicode
/// equivalent and these will not have hex codepoints, only the GitHub custom name.
/// We will ingore these (there are only a 19 and they are mostly pixel art from
/// the old Doom game).
/// Example GitHub custom emoji filename:
///  - "https://github.githubassets.com/images/icons/emoji/godmode.png?v8",
String parseGitHubFilenameIntoUnicodeString(String emojiFilename) {
  const variationSelector = 0xFE0F;
  const zeroWidthJoiner = 0x200D;

  try {
    final String? rawHexList = gitHubEmojiUnicodeFromFilenamePattern
        .firstMatch(emojiFilename)
        ?.group(1);
    if (rawHexList == null) {
      // This is a GitHub custom emoji and it is represented by a PNG image only and
      // there is no equivalent Unicode.  We have to ingore.
      return '';
    }
    var legacyUsedVariationCode = false;
    if (legacyEmojisUsedVariationModifier.contains(rawHexList)) {
      legacyUsedVariationCode = true;
    }
    final rawCodePointsHex = rawHexList
        .split('-')
        .map((hexstr) => int.parse(hexstr, radix: 16))
        .toList();
    final codePointsHex = <int>[];

    if (legacyUsedVariationCode) {
      // Just add single variation selector.
      codePointsHex.addAll(rawCodePointsHex);
      codePointsHex.add(variationSelector);
    } else {
      // Now insert the join zero width and variation select modifying Unicode chars.
      for (var i = 0; i < rawCodePointsHex.length; i++) {
        final codePointAtIndex = rawCodePointsHex[i];
        codePointsHex.add(codePointAtIndex);
        if (i < (rawCodePointsHex.length - 1)) {
          codePointsHex.add(variationSelector);
          // # and 0-9 don't use Zero Width Joiner.
          if (codePointAtIndex == 0x23 ||
              (codePointAtIndex >= 0x30 && codePointAtIndex <= 0x39)) {
            // Don't add Zero Width Joiner.
          } else {
            codePointsHex.add(zeroWidthJoiner);
          }
        }
      }
    }
    return String.fromCharCodes(codePointsHex);
  } catch (e) {
    print('Invalid/Non-Conformant emoji filename encountered "$emojiFilename"!');
    return (errorSpecialReplacement);
  }
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Print help text and exit.')
    ..addFlag('useGitHubUnicodes',
        abbr: 'g',
        negatable: false,
        help: 'Use the GitHub Unicode sequences instead of legacy sequences.')
    ..addFlag('visualizeDifferentUnicodes',
        abbr: 'v',
        negatable: false,
        help: 'Visualize any Unicode sequence differences.')
    ..addOption('dumpMarkdownShortCodes',
        abbr: 's',
        defaultsTo: 'missing',
        allowed: ['plain', 'tooltip'],
        allowedHelp: {
          'plain': 'just shortcode',
          'tooltip': '(shortcode with link to provide emoji name in tooltip)',
        },
        help:
            'Outputs all emoji shortcodes to stdout which can be used in markdown to show and tests all emoji.');
  late final ArgResults results;

  try {
    results = parser.parse(args);
  } catch (e) {
    printUsage(parser);
    exit(0);
  }

  if (results['help'] as bool) {
    printUsage(parser);
    exit(0);
  }

  int totalEmojiWithDifferentUnicodeSequences = 0;
  final bool useLegacyUnicodeSequences =
      !(results['useGitHubUnicodes'] as bool);
  final bool visualizeUnicodeDiffs =
      results['visualizeDifferentUnicodes'] as bool;
  final bool dumpMarkdownShortCodes =
      (results['dumpMarkdownShortCodes'].toLowerCase() == 'plain');
  final bool dumpMarkdownToolTipShortCodes =
      (results['dumpMarkdownShortCodes'].toLowerCase() == 'tooltip');

  if (!useLegacyUnicodeSequences) {
    // Issue warning.
    print(useOfGitHubUnicodeSequencesWarning);
  }
  if (visualizeUnicodeDiffs) {
    print(
        'The following emoji have different Unicode sequences from those of legacy versions:');
  }
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(_emojisJsonRawUrl));
  final response = await request.close();
  final shortcodeToEmoji = jsonDecode(
          await response.cast<List<int>>().transform(utf8.decoder).join(''))
      .map((String alias, dynamic filename) => MapEntry(
          alias, parseGitHubFilenameIntoUnicodeString(filename as String)))
      .cast<String, String>() as Map<String, String>;

  // Now before we proceed we need to 'mix in' any legacy emoji alias shortcodes that
  // are missing from the GitHub emoji list.
  legacyEmojis.forEach((String shortCodeAlias, String emojiUnicode) {
    if (!shortcodeToEmoji.containsKey(shortCodeAlias)) {
      shortcodeToEmoji[shortCodeAlias] = emojiUnicode;
    }
  });

  final emojisContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from GitHub's emoji API list endpoint:
// $_emojisJsonRawUrl
// at ${DateTime.now()} by the script, tool/update_github_emojis.dart.

''');
  emojisContent.writeln('const emojis = <String, String>{');
  var emojiCount = 0;
  final ignored = <String>[];
  final errored = <String>[];
  // Dump in sorted order now to facilitate comparison with new GitHub emoji.
  final sortedKeys = shortcodeToEmoji.keys.toList()..sort();
  for (final String shortCodeAlias in sortedKeys) {
    String emojiUnicode = shortcodeToEmoji[shortCodeAlias]!;
    if (useLegacyUnicodeSequences &&
        legacyEmojis.containsKey(shortCodeAlias) &&
        shortCodeAlias != 'cricket' &&
        shortCodeAlias != 'beetle') {
      emojiUnicode = legacyEmojis[
          shortCodeAlias]!; // Use legacy Unicode string if available.
    }
    if (legacyEmojis.containsKey(shortCodeAlias) &&
        emojiUnicode != legacyEmojis[shortCodeAlias]) {
      totalEmojiWithDifferentUnicodeSequences++;
      if (visualizeUnicodeDiffs) {
        print(
            '$emojiUnicode was ${legacyEmojis[shortCodeAlias]} :$shortCodeAlias:');
      }
    }
    if (emojiUnicode != errorSpecialReplacement && emojiUnicode.isNotEmpty) {
      emojisContent.writeln("  '$shortCodeAlias': '$emojiUnicode',");
      if (dumpMarkdownShortCodes) {
        print(':$shortCodeAlias:');
      } else if (dumpMarkdownToolTipShortCodes) {
        print('[:$shortCodeAlias:](## "&colon;$shortCodeAlias&colon; emoji")');
      }
      emojiCount++;
    } else {
      if (emojiUnicode == errorSpecialReplacement) {
        errored.add(shortCodeAlias);
      } else {
        ignored.add(shortCodeAlias);
      }
    }
  }
  emojisContent.writeln('};');
  File(_emojisFilePath).writeAsStringSync(emojisContent.toString());

  if (dumpMarkdownShortCodes) {
    // We are outputing the markdown to stdout, and presumably it
    // is being captured, so we exit now to exclude the summary
    // report from being included in the emoji markdown we have
    // been outputing.
    exit(0);
  }

  print('''Wrote data to $_emojisFilePath for $emojiCount emoji,
$totalEmojiWithDifferentUnicodeSequences emoji's Unicode sequences differ from legacy versions${!visualizeUnicodeDiffs ? " (run with -v flag to visualize)" : ""},
ignoring ${ignored.length}: ${ignored.join(', ')},
errored: ${errored.length} ${errored.join(', ')}.''');
  exit(0);
}

void printUsage(ArgParser parser) {
  print('''Usage: update_emojis.dart [--useGitHubUnicodes | -l]

By default, the legacy Unicode sequences are used (for
maximum visual compatability with the legacy emoji).
The --useGitHubUnicodes flag can be used so that the 
Unicode sequences from GitHub are used for emoji's that
existed within the legacy set.  This will result in very slight visual
differences for some emoji, but it will result in many more
binary differences when comparing legacy_emoji.dart to emoji.dart.
$useOfGitHubUnicodeSequencesWarning

The --visualizeDifferentUnicodes flag can be used to visually
verify that any different Unicode sequences produce the same
emoji.

${parser.usage}
''');
}
