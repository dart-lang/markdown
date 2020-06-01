// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;

const numTrials = 100;
const runsPerTrial = 50;

final source = _loadFile('input.md');
final expected = _loadFile('output.html');

void main() {
  var best = double.infinity;

  // Run the benchmark several times. This ensures the VM is warmed up and lets
  // us see how much variance there is.
  for (var i = 0; i <= numTrials; i++) {
    var start = DateTime.now();

    // For a single benchmark, convert the source multiple times.
    String result;
    for (var j = 0; j < runsPerTrial; j++) {
      result = markdownToHtml(source);
    }

    var elapsed =
        DateTime.now().difference(start).inMilliseconds / runsPerTrial;

    // Keep track of the best run so far.
    if (elapsed >= best) continue;
    best = elapsed;

    // Sanity check to make sure the output is what we expect and to make sure
    // the VM doesn't optimize "dead" code away.
    if (result != expected) {
      print('Incorrect output:\n$result');
      exit(1);
    }

    // Don't print the first run. It's always terrible since the VM hasn't
    // warmed up yet.
    if (i == 0) continue;
    _printResult("Run ${_padLeft('#$i', 3)}", elapsed);
  }

  _printResult('Best   ', best);
}

String _loadFile(String name) {
  var path = p.join(p.dirname(p.fromUri(Platform.script)), name);
  return File(path).readAsStringSync();
}

void _printResult(String label, double time) {
  print('$label: ${_padLeft(time.toStringAsFixed(2), 4)}ms '
      "${'=' * ((time * 20).toInt())}");
}

String _padLeft(String input, int length) {
  var result = input.toString();
  if (result.length < length) {
    result = ' ' * (length - result.length) + result;
  }

  return result;
}
