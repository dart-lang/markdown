#!/bin/bash

# Fast fail the script on failures.
set -e

# Analyze sources. Add --fatal-hints, --fatal-warnings, --fatal-lints
# as you see fit.
dartanalyzer lib/ test/

# Run tests.
pub run test

# Assert that code is formatted.
pub global activate dart_style
dirty_code=$(pub global run dart_style:format --dry-run lib/ test/ example/ benchmark/)
if [[ -n "$dirty_code" ]]; then
  echo Unformatted files:
  echo "$dirty_code" | sed 's/^/    /'
  exit 1
else
  echo All Dart source files are formatted.
fi
