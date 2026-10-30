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
LINT="$BUILD/quotelint"

rm -rf "$BUILD"
mkdir -p "$BUILD/src"

cp "$ROOT"/Sources/BiasCore/*.swift "$BUILD/src/"
# Single-module build, so the cross-module import has to go.
sed 's/^import BiasCore$//' "$ROOT/Sources/QuoteLint/main.swift" > "$BUILD/src/main.swift"

echo "compiling…"
swiftc -O -o "$LINT" "$BUILD"/src/*.swift

echo
echo "── self-checks ──"
"$LINT" self-check

echo
echo "── syntax-check the app and widget sources ──"
# `-parse` checks syntax only. No SwiftUI module and no Xcode required. It cannot catch type
# errors — only CI can — but it does catch unbalanced braces, bad expressions and typos in structure.
find "$ROOT/BiasApp" "$ROOT/BiasWidgets" "$ROOT/Shared" -name '*.swift' -print0 \
  | xargs -0 swiftc -parse
echo "ok: app + widget sources parse"

echo
echo "── build quotes.json from CSV ──"
cd "$ROOT"
"$LINT" build \
  --groups data/groups.csv \
  --quotes data/quotes.csv \
  --out "$BUILD/quotes.build.json" \
  --mode development \
  --min 1

echo
echo "── validate the generated file ──"
"$LINT" "$BUILD/quotes.build.json" --mode development --min 1

echo
echo "── build output must match the committed JSON ──"
if diff -q data/quotes.json "$BUILD/quotes.build.json" > /dev/null; then
  echo "ok: data/quotes.json is up to date with data/quotes.csv"
else
  echo "FAIL: data/quotes.json is stale — run: quotelint build"
  diff data/quotes.json "$BUILD/quotes.build.json" | head -20 || true
  exit 1
fi

echo
echo "── placeholder data must be refused in shipping mode ──"
if "$LINT" data/quotes.json --mode shipping > /dev/null 2>&1; then
  echo "FAIL: placeholder data passed shipping validation"
  exit 1
else
  echo "ok: placeholders are blocked from shipping"
fi

echo
echo "all local checks passed"
