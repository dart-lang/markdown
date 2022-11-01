// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart' as http;
import 'package:markdown/markdown.dart';
import 'package:pool/pool.dart';
import 'package:tar/tar.dart';
import 'package:test/test.dart';

void main() async {
  // This test is a really dumb and very slow crash-test.
  // It downloads the latest package version for each package on pub.dev
  // and tries to parse all `*.md` files in the package, counting the number
  // of times where the parser throws.
  //
  // Needless to say, this test is very slow and running it eats a lot of CPU.
  // But it's a fairly good way to try a lot of real-world markdown text to see
  // if any of the poorly formatted markdown causes the parser to crash.
  test(
    'crash test',
    () async {
      final c = http.RetryClient(http.Client());
      Future<dynamic> getJson(String url) async {
        final u = Uri.tryParse(url);
        if (u == null) {
          return null;
        }
        try {
          final data = await c.read(u);
          try {
            return jsonDecode(data);
          } on FormatException {
            return null;
          }
        } on http.ClientException {
          return null;
        } on IOException {
          return null;
        }
      }

      final packages =
          ((await getJson('https://pub.dev/api/package-names'))['packages']
                  as List)
              .cast<String>();
      print('Found ${packages.length} packages to scan');

      final errors = <String>[];
      final pool = Pool(50);
      var count = 0;
      var skipped = 0;
      var lastStatus = DateTime.now();
      await Future.wait(packages.map((package) async {
        await pool.withResource(() async {
          final versionsResponse =
              await getJson('https://pub.dev/api/packages/$package');
          final archiveUrl = Uri.tryParse(
            versionsResponse['latest']?['archive_url'] as String? ?? '',
          );
          if (archiveUrl == null) {
            skipped++;
            return;
          }
          late List<int> archive;
          try {
            archive = gzip.decode(await c.readBytes(archiveUrl));
          } on http.ClientException {
            skipped++;
            return;
          } on IOException {
            skipped++;
            return;
          }
          try {
            await TarReader.forEach(Stream.value(archive), (entry) async {
              if (entry.name.endsWith('.md')) {
                late String contents;
                try {
                  final bytes = await http.ByteStream(entry.contents).toBytes();
                  contents = utf8.decode(bytes);
                } on FormatException {
                  return; // ignore invalid utf8
                }
                try {
                  markdownToHtml(
                    contents,
                    extensionSet: ExtensionSet.gitHubWeb,
                  );
                } catch (err, st) {
                  errors
                      .add('package:$package/${entry.name}, throws: $err\n$st');
                }
              }
            });
          } on FormatException {
            skipped++;
            return;
          }
        });
        count++;
        if (DateTime.now().difference(lastStatus) > Duration(seconds: 30)) {
          lastStatus = DateTime.now();
          print('Scanned $count / ${packages.length} (skipped $skipped),'
              ' found ${errors.length} issues');
        }
      }));

      await pool.close();
      c.close();

      if (errors.isNotEmpty) {
        print('Found issues:');
        errors.forEach(print);
        fail('Found ${errors.length} cases where markdownToHtml threw!');
      }
    },
    timeout: Timeout(Duration(hours: 1)),
    tags: 'crash_test', // skipped by default, see: dart_test.yaml
  );
}
