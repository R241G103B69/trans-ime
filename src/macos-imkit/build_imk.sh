#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$DIR/../.." && pwd )"
IMK_APP_DIR="$PROJECT_ROOT/bin/TranslateIME.app"
CONTENTS_DIR="$IMK_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building native macOS InputMethodKit TranslateIME.app..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 1. Compile
clang -O2 -fobjc-arc \
  -framework Cocoa \
  -framework InputMethodKit \
  -I "$DIR" \
  "$DIR/PinyinEngine.m" \
  "$DIR/TransInputController.m" \
  "$DIR/IMKMain.m" \
  -o "$MACOS_DIR/TranslateIME"

# 2. Copy Plist
cp "$DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
echo -n "APPLTRNS" > "$CONTENTS_DIR/PkgInfo"

chmod +x "$MACOS_DIR/TranslateIME"

echo "==> TranslateIME.app built successfully at: $IMK_APP_DIR"
echo "==> To install to macOS system input sources:"
echo "    cp -R \"$IMK_APP_DIR\" ~/Library/Input\\ Methods/"
echo "    Then log out and log in, and enable it in System Settings -> Keyboard -> Input Sources."
