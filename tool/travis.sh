#!/bin/bash

# Fast fail the script on failures.
set -e

# Analyze sources. Add --fatal-hints, --fatal-warnings, --fatal-lints
# as you see fit.
dartanalyzer --strong lib/ test/

# Run tests.
pub run test

# Assert that code is formatted.
pub global activate dart_style
dirty_code=$(pub global run dart_style:format --dry-run lib/ test/)
if [[ -n "$dirty_code" ]]; then
  echo Unformatted files:
  echo "$dirty_code" | sed 's/^/    /'
  exit 1
else
  echo All Dart source files are formatted.
fi

# Assert that versions match.
pubspec_version=$(awk '/^version:/' pubspec.yaml |cut -f2 -d' ')
bin_version=$(dart bin/markdown.dart --version )
if [[ $pubspec_version != $bin_version ]]; then
  echo Version mismatch:
  echo "    From pubspec.yaml:         $pubspec_version"
  echo "    From lib/src/version.dart: $bin_version"
  exit 1
else
  echo Package versions match.
fi
