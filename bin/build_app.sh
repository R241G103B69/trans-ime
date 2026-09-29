#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( dirname "$DIR" )"
APP_DIR="$PROJECT_ROOT/bin/TransType.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building TransType.app..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 1. Compile binary
clang -O2 -fobjc-arc \
  -framework Cocoa \
  -framework Carbon \
  -framework ApplicationServices \
  -I "$PROJECT_ROOT/src/macos-app" \
  "$PROJECT_ROOT/src/macos-app"/*.m \
  -o "$MACOS_DIR/TransType"

# 2. Copy Info.plist and PkgInfo
cp "$PROJECT_ROOT/src/macos-app/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
echo -n "APPLTRNS" > "$CONTENTS_DIR/PkgInfo"

# 3. Copy Resources
cp "$PROJECT_ROOT/src/macos-app/Resources/dictionary.json" "$RESOURCES_DIR/dictionary.json"

chmod +x "$MACOS_DIR/TransType"

echo "==> TransType.app built successfully at: $APP_DIR"
