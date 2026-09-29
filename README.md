# 🔤 TransType 译打 · 智能翻译输入法

> **“输入中文，选好词汇，直接输出英文”** —— 为跨语言工作者打造的即打即译桌面输入法。

[![macOS Supported](https://img.shields.io/badge/platform-macOS%2011%2B-blue)](https://apple.com)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](Makefile)
[![Tests Status](https://img.shields.io/badge/tests-6%2F6%20passed-success)](tests/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## ✨ 核心特性

- 🎯 **输入中文，直接输出英文**：你在任何软件中打出中文或拼音，选好中意的英文表达或词汇，选定后**直接打入目标文本框**，无需切屏、复制和粘贴！
- 🪄 **双形态架构支持**：
  1. **独立悬浮智能翻译 HUD (`TransType.app`)**：类似 Spotlight / Raycast / 微信输入法翻译浮窗，常驻后台，按 `⌥ + Space` 瞬时呼出，兼容搜狗、微信、自带拼音、双拼、五笔等所有输入法习惯。
  2. **原生 macOS 系统级输入法 (`TranslateIME.app`)**：基于 Apple `InputMethodKit` 框架，直接注册为 macOS 系统键盘输入源，在系统输入法列表中自由切换。
  3. **Rime 开源输入法滤镜 (`rime-plugin/`)**：为鼠须管 (macOS) 和小狼毫 (Windows) 用户提供即插即用的 Lua 翻译扩展。
  4. **跨平台交互式仿真演练器 (`web-simulator/`)**：在浏览器中无死角演练输入、选词与上屏交互。
- 🎭 **四维风格多候选生成**：
  - **【候选 1】自然推荐 (Natural)**：地道流畅的日常工作表达。
  - **【候选 2】商务正式 (Formal / Business)**：适合商务邮件、学术写作与正式沟通。
  - **【候选 3】日常口语 (Casual / Colloquial)**：适合 Slack、Discord 等即时聊天。
  - **【候选 4】精炼简短 (Concise)**：提纲短语，直奔要点。
- 🧩 **重点词汇拆解 (Vocabulary Breakdown)**：自动分词并展示句子中的关键词汇、词性（名词/动词/形容词）及近义词（Synonyms），助你在日常打字中积累高级词汇。
- ⚡ **离线高速词典 + 免费云端翻译 + AI 级增强**：
  - 内置本地离线中英双向常用句型与词库（断网 0ms 响应）。
  - 内置公共翻译 API，开箱即用免配置。
  - 支持接入 DeepSeek、OpenAI 或本地 Ollama 模型，享受上下文语境高级润色。
- 🚀 **极速无损上屏 (Zero-Loss Auto Commit)**：选定候选词后，浮窗瞬隐，自动恢复前台目标应用（Chrome, Slack, VS Code, Word, 终端等）焦点并将选定英文精准键入光标处。

---

## 📸 交互流程演示

```text
[在任意聊天框/文档中]
       │
       ▼ 按下 ⌥ + Space
┌─────────────────────────────────────────────────────────────┐
│ 🔍 今天下午三点在会议室开会                                   │
├─────────────────────────────────────────────────────────────┤
│ [1] 自然推荐  Meeting in the conference room at 3 PM today. │
│ [2] 正式书面  We will have a meeting in the conference room.│
│ [3] 日常口语  Let's meet in the conference room at 3pm!     │
│ [4] 精炼短语  3pm conference room meeting today.            │
│ 📌 词汇拆解:  会议室(conference room) · 开会(have a meeting) │
├─────────────────────────────────────────────────────────────┤
│ [↵] 确认首选  [1-4] 选词上屏  [↑/↓] 切换  [ESC] 取消          │
└─────────────────────────────────────────────────────────────┘
       │
       ▼ 按数字键 1 或 回车 (Enter)
[目标窗口光标处直接出现]: "Meeting in the conference room at 3 PM today."
```

---

## 📂 项目结构

```text
trans-ime/
├── README.md                          # 项目介绍与使用指南
├── ARCHITECTURE.md                    # 输入法底层深度技术架构指南 (IMKit & TSF)
├── Makefile                           # 一键编译、构建与运行自动化脚本
│
├── bin/                               # 构建输出目录
│   ├── TransType.app                  # 独立悬浮翻译输入法 (打包产物)
│   ├── TranslateIME.app               # macOS 原生系统级输入法 (打包产物)
│   ├── test_engine                    # 词库与翻译引擎单元测试程序
│   └── test_output                    # 焦点恢复与上屏测试程序
│
├── src/
│   ├── macos-app/                     # 独立常驻翻译输入法源码 (Objective-C / Cocoa)
│   │   ├── main.m                     # 入口主程序
│   │   ├── AppDelegate.h / .m         # 菜单栏常驻与 Option+Space 全局热键
│   │   ├── TranslationWindow.h / .m   # 磨砂毛玻璃 HUD 输入与交互面板
│   │   ├── CandidateView.h / .m       # 动态候选词与词汇拆解视图
│   │   ├── TranslationEngine.h / .m   # 本地词库 + 免费云端 + LLM 协同引擎
│   │   ├── TextOutputManager.h / .m   # 目标焦点追踪与自动上屏执行器
│   │   ├── LocalDictionary.h / .m     # 本地离线高频词库 Trie 检索器
│   │   └── Resources/
│   │       ├── dictionary.json        # 精选离线中英高频短语与核心词汇
│   │       └── Info.plist             # 应用配置清单
│   │
│   ├── macos-imkit/                   # 原生 macOS 系统级输入法 (InputMethodKit)
│   │   ├── IMKMain.m                  # IMKServer 守护进程入口
│   │   ├── TransInputController.h/.m  # 继承 IMKInputController 拦截按键与上屏
│   │   ├── PinyinEngine.h / .m        # 轻量拼音转换与双语候选引擎
│   │   ├── Info.plist                 # 系统输入法配置 (TIS 接入点)
│   │   └── build_imk.sh               # 打包并提示安装到系统输入源
│   │
│   ├── rime-plugin/                   # Rime 鼠须管 / 小狼毫 翻译方案
│   │   ├── translate.schema.yaml      # Rime 输入方案定义
│   │   ├── rime.lua                   # Lua 翻译滤镜 (输出英文)
│   │   └── README.md                  # Rime 安装指南
│   │
│   └── web-simulator/                 # 跨平台交互式仿真演练器
│       ├── index.html                 # 完整的系统桌面与目标应用模拟器
│       ├── style.css                  # 现代化毛玻璃样式与动效
│       └── app.js                     # 即时翻译、分词、选词上屏完整逻辑
│
└── tests/                             # 自动化单元测试套件
    ├── test_engine.m                  # 词典匹配与引擎防抖测试
    └── test_output.m                  # 剪贴板注入与应用焦点捕获测试
```

---

## ⚡ 快速上手与编译运行

本项目使用原生 C / Objective-C 编写，依赖 macOS 自带的底层系统框架（Cocoa, Carbon, InputMethodKit, ApplicationServices），**无需安装任何庞大的第三方依赖包**，启动毫秒级，内存占用仅约 15MB。

### 1. 编译并运行自动化测试
```bash
make test
```
*测试将自动验证离线精准句型匹配、关键词抽取、拼音前缀索引、LRU 缓存机制与剪贴板注入。*

### 2. 编译并启动 TransType 悬浮输入法
```bash
make run
```
或者手动执行：
```bash
open bin/TransType.app
```
启动后，macOS 右上角菜单栏会出现 `[译] TransType` 图标。

### 3. 使用方法
1. 在任何软件（如微信、Slack、浏览器文本框、VS Code、Word）中定位光标；
2. 按下系统全局快捷键：
   $$\mathbf{Option + Space} \quad (\⌥ \text{ 空格})$$
3. 输入中文句子（如：“今天下午开会” 或 “请问您明天下午是否有空”）；
4. 候选词框即刻呈现多风格英文翻译与重点词汇；
5. 按数字键 `1` ~ `7` 或直接按 `Enter`（确认第 1 个推荐）：
   浮窗自动隐藏，**所选英文直接输入到刚才的光标位置**！

---

## 🛠 安装为 macOS 系统原生输入法 (InputMethodKit)

如果你希望将其作为像“简体拼音”或“ABC”一样的系统原生输入源：
```bash
make imk
cp -R bin/TranslateIME.app ~/Library/Input\ Methods/
```
1. 打开 macOS **【系统设置】 -> 【键盘】 -> 【文字输入 (输入法)】 -> 【编辑】**；
2. 点击左下角 `+` 号，在列表中选择 **【中文 (简体)】 -> 【译打输入法 (TransIME)】** 并添加；
3. 使用 `Control + Space` 切换至该输入法，键入拼音（如 `nihao` / `kaihui`），按空格直接输出对应英文！

---

## 🌐 浏览器交互仿真演练器 (Web Simulator)

我们在 `src/web-simulator/` 下提供了纯前端的高保真仿真器：
1. 双击打开 `src/web-simulator/index.html`（或使用任意静态服务器运行）；
2. 可以在模拟的真实办公应用中体验快捷键唤起、中文输入、候选高亮、词汇拆解及一键上屏的全部交互。

---

## ⚙️ 高级配置与 AI 大模型对接

在 `src/macos-app/TranslationEngine.m` 中，你可以自由配置 AI 大模型 API Key（如 DeepSeek）：
```objc
TranslationEngine *engine = [TranslationEngine sharedEngine];
engine.enableLLM = YES;
engine.llmApiKey = @"sk-your-deepseek-api-key";
engine.llmModelName = @"deepseek-chat";
```
启用后，系统将结合上下文语境进行智能润色与同义词联想。

---

## 📄 开源许可证
本项目基于 [MIT License](LICENSE) 开源发布。
