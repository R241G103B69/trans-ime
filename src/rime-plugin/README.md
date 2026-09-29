# Rime 鼠须管 / 小狼毫 翻译输入法扩展 (TransType for Rime)

通过 Rime 的 Lua 扩展机制，你可以直接在你现有的 Rime 输入法（macOS 鼠须管 Squirrel、Windows 小狼毫 Weasel、Linux Fcitx5-Rime）中获得“输入中文/拼音，候选词呈现英文，选词直接输出英文”的能力！

---

## 🛠 安装与配置步骤

### 1. 复制文件到 Rime 用户目录
- **macOS (鼠须管)**: `~/Library/Rime/`
- **Windows (小狼毫)**: `%APPDATA%\Rime\`
- **Linux (Fcitx5-Rime)**: `~/.local/share/fcitx5/rime/`

将本目录下的两个文件复制过去：
```bash
cp translate.schema.yaml ~/Library/Rime/
cp rime.lua ~/Library/Rime/
```

### 2. 在 `default.custom.yaml` 中添加该方案
在 `~/Library/Rime/default.custom.yaml`（若无则新建）中增加：
```yaml
patch:
  schema_list/+:
    - schema: translate
```

### 3. 重新部署 Rime
- macOS 菜单栏点击【鼠须管】图标 -> 点击【重新部署】(Deploy)。
- 切换到【译打 · 翻译输入法】。

---

## 🚀 使用体验
- 输入拼音 `nihao`：
  - 候选 1: `Hello [你好]`
  - 候选 2: `Hi [你好]`
- 按空格或数字键 `1`：
  - **屏幕上直接输出：`Hello`**！
- 输入 `fangan`：
  - 候选 1: `Solution [方案]`
  - 候选 2: `Proposal [方案]`
- 完美契合“输入中文选好词汇，输出英文”的核心诉求！
