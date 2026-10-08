#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( dirname "$DIR" )"
DIST_DIR="$PROJECT_ROOT/dist"

echo "==> [1/4] 编译构建所有产物..."
cd "$PROJECT_ROOT"
make app
make imk

echo "==> [2/4] 准备发布归档目录..."
RELEASE_NAME="trans-ime-v1.0.0-macos"
STAGE_DIR="$DIST_DIR/$RELEASE_NAME"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

# 复制可执行 App
cp -R "$PROJECT_ROOT/bin/TransType.app" "$STAGE_DIR/"
cp -R "$PROJECT_ROOT/bin/TranslateIME.app" "$STAGE_DIR/"

# 复制 Rime 扩展
cp -R "$PROJECT_ROOT/src/rime-plugin" "$STAGE_DIR/"

# 复制 Web 仿真器
cp -R "$PROJECT_ROOT/src/web-simulator" "$STAGE_DIR/"

# 复制文档与许可证
cp "$PROJECT_ROOT/README.md" "$STAGE_DIR/"
cp "$PROJECT_ROOT/ARCHITECTURE.md" "$STAGE_DIR/"
cp "$PROJECT_ROOT/LICENSE" "$STAGE_DIR/"

echo "==> [3/4] 打包生成归档压缩包..."
cd "$DIST_DIR"
tar -czf "${RELEASE_NAME}.tar.gz" "$RELEASE_NAME"
zip -rq "${RELEASE_NAME}.zip" "$RELEASE_NAME"

echo "==> [4/4] 打包完成！"
echo "发布包位置："
ls -lh "$DIST_DIR"
