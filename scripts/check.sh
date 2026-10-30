#!/usr/bin/env bash
# Local verification without Xcode.
#
# This machine has no Xcode and a broken Command Line Tools install: `PackageDescription`
# ships without its .swiftmodule, so `swift build` / `swift test` cannot compile a manifest.
# `swiftc` itself works fine, so this script compiles BiasCore + quotelint as one module and
# runs the real checks. CI uses SwiftPM normally.
#
#   ./scripts/check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/.localbuild"

rm -rf "$BUILD"
mkdir -p "$BUILD/src"

cp "$ROOT"/Sources/BiasCore/*.swift "$BUILD/src/"
# Single-module build, so the cross-module import has to go.
sed 's/^import BiasCore$//' "$ROOT/Sources/QuoteLint/main.swift" > "$BUILD/src/main.swift"

echo "compiling…"
swiftc -O -o "$BUILD/quotelint" "$BUILD"/src/*.swift

echo
echo "self-checks"
"$BUILD/quotelint" --self-check

echo
echo "sample data (development mode — placeholders are allowed here)"
"$BUILD/quotelint" "$ROOT/data/quotes.sample.json" --mode development --stats

echo
echo "sample data in shipping mode (must fail: placeholders present)"
if "$BUILD/quotelint" "$ROOT/data/quotes.sample.json" --mode shipping > /dev/null; then
  echo "FAIL: placeholder data passed shipping validation"
  exit 1
else
  echo "ok: placeholder data correctly refused in shipping mode"
fi

echo
echo "all local checks passed"
