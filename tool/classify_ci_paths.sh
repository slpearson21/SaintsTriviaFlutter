#!/usr/bin/env bash
# Classify a pull request's changed paths for CI.
#
# Reads a newline-separated file list on stdin (paths only).
# Writes docs_only and ios to stdout and, when set, to GITHUB_OUTPUT.
#
# docs_only: every changed file is Markdown, under docs/, or a CSV that is
# outside assets/ and test/. assets/ is bundled, and test/ is what the Linux
# job runs, so a change in either tree still runs that job.
# ios: any changed file can affect the iOS simulator build: ios/, the
# pubspecs, workflow files, or native plugin config (Podfile, Podfile.lock,
# *.podspec).
#
# An empty list does not count as docs-only. A pull request with no file
# list still runs the Linux job.

set -euo pipefail

is_ios_path() {
  case "$1" in
    ios/* | pubspec.yaml | pubspec.lock | .github/workflows/* | *.podspec | Podfile | Podfile.lock | */Podfile | */Podfile.lock)
      return 0
      ;;
  esac
  return 1
}

is_docs_path() {
  case "$1" in
    assets/* | test/*)
      return 1
      ;;
    *.md | docs/* | *.csv)
      return 0
      ;;
  esac
  return 1
}

classify() {
  local docs_only=true
  local ios=false
  local seen=false
  local line

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line}" ]] && continue
    seen=true
    if is_ios_path "${line}"; then
      ios=true
    fi
    if ! is_docs_path "${line}"; then
      docs_only=false
    fi
  done

  if [[ "${seen}" == false ]]; then
    docs_only=false
    ios=false
  fi

  printf '%s\n%s\n' "${docs_only}" "${ios}"
}

emit() {
  printf '%s=%s\n' "$1" "$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT}"
  fi
}

self_test() {
  local fail=0

  expect() {
    local name="$1"
    local expected_docs="$2"
    local expected_ios="$3"
    local input="$4"
    local got docs ios

    got="$(printf '%s\n' "${input}" | classify)"
    docs="${got%%$'\n'*}"
    ios="${got#*$'\n'}"
    if [[ "${docs}" != "${expected_docs}" || "${ios}" != "${expected_ios}" ]]; then
      echo "FAIL ${name}: docs=${docs} ios=${ios} expected docs=${expected_docs} ios=${expected_ios}" >&2
      fail=1
    fi
  }

  expect "readme" true false "README.md"
  expect "nested markdown" true false "docs/review/notes.md"
  expect "csv review" true false "review/questions.csv"
  expect "docs csv" true false "docs/bank/questions.csv"
  expect "asset csv" false false "assets/questions/v1/extra.csv"
  expect "asset json" false false "assets/questions/v1/old_testament.json"
  expect "asset png" false false "assets/icon/ios-master-1024.png"
  expect "asset markdown" false false "assets/fonts/OFL.md"
  expect "test csv" false false "test/fixtures/questions/v1/extra.csv"
  expect "test markdown" false false "test/README.md"
  expect "readme and test csv" false false $'README.md\ntest/fixtures/bank.csv'
  expect "dart and readme" false false $'README.md\nlib/main.dart'
  expect "ios plist" false true "ios/Runner/Info.plist"
  expect "ios readme only" true true "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md"
  expect "pubspec" false true "pubspec.yaml"
  expect "lock" false true "pubspec.lock"
  expect "workflow" false true ".github/workflows/ci.yml"
  expect "workflow and readme" false true $'README.md\n.github/workflows/ci.yml'
  expect "podspec" false true "third_party/Foo.podspec"
  expect "nested podfile" false true "ios/Podfile"
  expect "podfile lock" false true "vendor/Podfile.lock"
  expect "root podfile" false true "Podfile"
  expect "not a podfile" false false "notes/Podfile.txt"
  expect "docs and asset csv" false false $'README.md\nassets/questions/v1/x.csv'
  expect "empty" false false ""

  if [[ "${fail}" -ne 0 ]]; then
    echo "classify_ci_paths self-test failed" >&2
    exit 1
  fi
  echo "classify_ci_paths self-test ok"
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if [[ $# -ne 0 ]]; then
  echo "usage: classify_ci_paths.sh [--self-test] < paths.txt" >&2
  exit 2
fi

result="$(classify)"
docs_only="${result%%$'\n'*}"
ios="${result#*$'\n'}"
emit docs_only "${docs_only}"
emit ios "${ios}"
