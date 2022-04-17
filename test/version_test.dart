// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'util.dart';

void main() {
  test('check versions', () async {
    final packageRoot = await markdownPackageRoot;
    final binary = p.normalize(p.join(packageRoot, 'bin', 'markdown.dart'));
    final dartBin = Platform.executable;
    final result = Process.runSync(dartBin, [binary, '--version']);
    expect(
      result.exitCode,
      0,
      reason: 'Exit code expected: 0; actual: ${result.exitCode}\n\n'
          'stdout: ${result.stdout}\n\n'
          'stderr: ${result.stderr}',
    );

    final binVersion = (result.stdout as String).trim();

    final pubspecFile = p.normalize(p.join(packageRoot, 'pubspec.yaml'));

    final pubspecContent =
        loadYaml(File(pubspecFile).readAsStringSync()) as YamlMap;

    expect(
      binVersion,
      pubspecContent['version'],
      reason: 'The version reported by bin/markdown.dart should match the '
          'version in pubspec. Run `pub run build_runner build` to update.',
    );
  });
}
