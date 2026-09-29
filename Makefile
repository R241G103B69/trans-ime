.PHONY: all app imk test clean run help

PROJECT_DIR := $(shell pwd)
BIN_DIR := $(PROJECT_DIR)/bin
SRC_APP := $(PROJECT_DIR)/src/macos-app
SRC_IMK := $(PROJECT_DIR)/src/macos-imkit
TESTS_DIR := $(PROJECT_DIR)/tests

CC := clang
CFLAGS := -O2 -fobjc-arc -Wall

all: app imk test

help:
	@echo "TransType 译打 - 智能翻译输入法 构建指令:"
	@echo "  make app    - 编译构建 TransType.app (独立悬浮智能翻译输入法)"
	@echo "  make imk    - 编译构建 TranslateIME.app (macOS 原生系统级输入法)"
	@echo "  make test   - 编译并运行自动化单元测试"
	@echo "  make run    - 启动 TransType.app 悬浮翻译输入法"
	@echo "  make clean  - 清理构建产物"

app:
	@echo "==> 构建 TransType.app..."
	@bash $(BIN_DIR)/build_app.sh

imk:
	@echo "==> 构建 TranslateIME.app (Native IMKit)..."
	@bash $(SRC_IMK)/build_imk.sh

test:
	@echo "==> 运行自动化测试套件..."
	@mkdir -p $(BIN_DIR)
	@$(CC) $(CFLAGS) -framework Foundation -I $(SRC_APP) \
		$(SRC_APP)/LocalDictionary.m \
		$(SRC_APP)/TranslationEngine.m \
		$(TESTS_DIR)/test_engine.m \
		-o $(BIN_DIR)/test_engine
	@$(BIN_DIR)/test_engine
	@$(CC) $(CFLAGS) -framework Cocoa -framework Carbon -I $(SRC_APP) \
		$(SRC_APP)/TextOutputManager.m \
		$(TESTS_DIR)/test_output.m \
		-o $(BIN_DIR)/test_output
	@$(BIN_DIR)/test_output

run: app
	@echo "==> 启动 TransType.app..."
	@open $(BIN_DIR)/TransType.app

clean:
	@echo "==> 清理构建目录..."
	@rm -rf $(BIN_DIR)/*
