# Yuky's Kits · Yuky 的工具集

> **English** · A Godot 4.7 editor plugin that turns formatted CSV spreadsheets into runtime JSON data, with an in-game data API, a resource library browser, and runtime resource loading.
>
> **中文** · 一个 Godot 4.7 编辑器插件：把「规定格式」的 CSV 表格导出为运行时可读的 JSON 数据，提供游戏内数据访问 API（`GameDB`）、资源库浏览面板，以及运行时资源加载能力。

[![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Version](https://img.shields.io/badge/version-0.1.0-informational)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Yukys--Kits--Dev-181717?logo=github)](https://github.com/Yukymura/Yukys-Kits-Dev)

---

## 目录 · Table of Contents

- [功能特性 · Features](#-功能特性--features)
- [安装 · Installation](#-安装--installation)
- [快速开始 · Quick Start](#-快速开始--quick-start)
- [CSV 规定格式 · CSV Format](#-csv-规定格式--csv-format)
- [GameDB 运行时 API · GameDB Runtime API](#-gamedb-运行时-api--gamedb-runtime-api)
- [AI 导表 · AI-driven Import](#-ai-导表--ai-driven-import)
- [目录结构 · Directory Structure](#-目录结构--directory-structure)
- [测试 · Testing](#-测试--testing)
- [许可证 · License](#-许可证--license)

---

## ✨ 功能特性 · Features

| 功能 Feature | 说明 Description | 状态 Status |
| --- | --- | --- |
| 导表 Data Import | 规定格式 CSV → JSON，含类型转换，游戏内 `GameDB` 访问 | ✅ |
| 日志 Logging | 控制台只输出导表结果/失败原因，详细过程写入 `logs/import.log` | ✅ |
| 数据预览 Data Preview | 数据树浏览 + JSON 可视化预览（只读），表格带行号/字段名 | ✅ |
| 资源库 Resource Library | 图片 / 音频 / Godot 资源预览面板，分类着色，点击打开对应界面 | ✅ |
| 资源加载 Resource Loading | `load_sprite` / `load_audio` / `load_resource`，缓存 + 解决导出后 `res://` 路径变化 | ✅ |
| 设置界面 Settings UI | 数据驱动设置页，数据库/资源库路径、资源配色，全部持久化 | ✅ |
| 默认设置 Defaults | 配置表 `default` 列 + 类型转换 + 一键重置按钮 | ✅ |
| AI 导表 AI Import | 注册自定义 MCP 工具 `yukys_export_csv`，AI 指令 `单表导出xxx` 自动导表 | ✅ |

> **依赖 Dependency**：AI 导表功能依赖 **godot_ai**（Godot AI MCP 插件）提供的自定义工具桥接；其余功能无第三方依赖。
> The AI-import feature depends on the **godot_ai** (Godot AI MCP) plugin for its custom-tool bridge; everything else has no third-party dependencies.

---

## 📦 安装 · Installation

1. 把 `addons/yukys_kits` 整个目录拷贝到你的 Godot 项目的 `addons/` 下。
   Copy the whole `addons/yukys_kits` folder into your project's `addons/` directory.
2. 在 **项目设置 → 插件（Project Settings → Plugins）** 中启用 **Yuky'sKits**。
   Enable **Yuky'sKits** under *Project Settings → Plugins*.
3. 确认 `project.godot` 里注册了 autoload（插件会自动处理，也可手动确认）：
   Ensure the autoload is registered in `project.godot` (the plugin handles this; verify manually if needed):

   ```ini
   [autoload]
   GameDB="*res://addons/yukys_kits/runtime/game_db.tscn"
   ```

4. 重新加载项目，插件会新增一个 **导表工具** Dock（含「数据 / 资源 / 设置」页面）。
   Reload the project; the plugin adds a **导表工具 (Data Tools)** dock with Data / Resource / Settings pages.

> **要求 Requirements**：Godot 4.7+。

---

## 🚀 快速开始 · Quick Start

### 1. 导表 · Import data

1. 在 Dock 的「导表」页选择 CSV 文件与导出目录（默认 `res://data`）。
   In the Import page, pick a CSV file and an export directory (default `res://data`).
2. 点击 **导表**，生成 `{导出目录}/{表名}.json`；面板底部会预览该表数据。
   Click **导表 (Import)**; it writes `{export_dir}/{table_name}.json` and previews the table at the bottom.
3. 若导出目录已有同名 JSON，面板会提示「已存在同名 JSON」。
   If a JSON of the same name already exists, the panel warns you before overwriting.

### 2. 游戏内取数 · Read data in game

```gdscript
# 所有表名（已排序） All table names (sorted)
var names: Array = GameDB.get_table_names()

# 整张表：{ id: { 字段: 值, ... }, ... }  Whole table
var table: Dictionary = GameDB.get_table("ItemTable")

# 单行：{ 字段: 值, ... }  Single row
var row: Dictionary = GameDB.get_row("ItemTable", 1)

print(row["name"], " 价格:", row["price"])
```

### 3. 资源加载 · Load resources

```gdscript
# 图片 / 音频 / Godot 资源，相对资源库路径或完整 res:// 均可
# Images / audio / Godot resources — relative-to-library or full res:// paths both work
var card: Texture2D = GameDB.load_sprite("pic/啤酒.png")
var bgm: AudioStream = GameDB.load_audio("sfx/我的世界拾取物品.mp3")
var theme: Theme = GameDB.load_resource("theme/theme1.tres")
```

> 加载失败返回 `null`（不报错）；同一路径重复加载命中缓存返回同一实例，需要时调用 `GameDB.clear_resource_cache()`。
> Loading failure returns `null` (no error). Repeated loads of the same path hit a cache and return the same instance; call `GameDB.clear_resource_cache()` when needed.

### 4. 设置 · Settings

在「设置」页配置数据库路径、资源库路径与资源分类背景色，全部持久化到 `data_tools/config.json`，并可在每项右侧点击重置按钮恢复默认值。
Use the Settings page to configure the data directory, resource directory, and resource category colors; everything persists to `data_tools/config.json`, with a per-item reset button.

---

## 📖 CSV 规定格式 · CSV Format

| 行 Row | 内容 Content | 说明 Description |
| --- | --- | --- |
| 1 | `表名` Table name | 第一格为表名，其余忽略 First cell is the table name, rest ignored |
| 2 | `*id` + `字段:类型` | 首格以 `*` 开头（第一列为 id），之后每格 `字段名:类型` First cell starts with `*` (id column), then `field:type` pairs |
| 3+ | `id` + 值 | 首格为 id，之后为各字段值 First cell is id, then values |

- 字段名以 `#` 开头 → 该字段不导出。Fields prefixed with `#` are not exported.
- id 以 `#` 开头或为空 → 该行不导出。Rows whose id starts with `#` or is empty are not exported.
- 支持类型 Supported types：`String` `int` `float` `bool` `Vector2` `Vector3` `Vector2i` `Vector3i` `Array[类型]`
- 数组值用 `;` 分隔（`a;b;c`）；向量值写成 `(x, y)` 或 `(x, y, z)`。
  Array values are separated by `;`; vectors are written `(x, y)` or `(x, y, z)`.

**示例 Example**：

|  | A | B | C | D |
| --- | --- | --- | --- | --- |
| 1 | ItemTable |  |  |  |
| 2 | *id | name:String | price:int | tags:Array[String] |
| 3 | 1 | 剑 Sword | 100 | 武器;近战 |
| 4 | 2 | 盾 Shield | 80 | 防具 |

导出的 JSON（Export output）：

```json
{
  "table_name": "ItemTable",
  "import_path": "res://tables/ItemTable.csv",
  "update_time": "2026-09-07 22:00:00",
  "types": { "name": "String", "price": "int", "tags": "Array[String]" },
  "data": { "1": { "name": "剑", "price": 100, "tags": ["武器", "近战"] } }
}
```

---

## 🧰 GameDB 运行时 API · GameDB Runtime API

`GameDB` 是运行时 autoload（随游戏导出），只依赖 ProjectSettings 读取路径，不依赖编辑器代码。
`GameDB` is a runtime autoload (ships with your game); it reads paths from ProjectSettings and does not depend on any editor code.

### 数据访问 · Data access

```gdscript
GameDB.get_table_names()      # Array[String]    所有表名（已排序） All table names (sorted)
GameDB.get_table("表名")      # Dictionary       整张表 { id: {字段:值}, ... }
GameDB.get_row("表名", id)    # Dictionary       单行 {字段:值}
```

### 资源加载 · Resource loading

```gdscript
GameDB.get_resource_dir()       # String         资源库目录（缺省 res://res）
GameDB.resolve_resource_path(p) # String         相对路径 → 拼上资源库目录；res:///user:///绝对路径原样返回
GameDB.list_resource_files()    # Array[String]  资源库下所有资源文件（相对路径，已排序）
GameDB.get_resource_type(p)     # String         分类：image / audio / godot / ""
GameDB.is_resource_file(p)      # bool           是否为受支持的资源文件
GameDB.load_sprite(p)           # Texture2D      加载图片（png/jpg/webp/...）
GameDB.load_audio(p)            # AudioStream    加载音频（wav/ogg/mp3/...）
GameDB.load_resource(p)         # Resource       加载 Godot 资源（.tres/.res/.tscn/.gdshader 等）
GameDB.clear_resource_cache()   # void           清空资源缓存
```

### 导出后 `res://` 路径变化 · The `res://` path problem after export

编辑器里 `res://` 指向项目根目录；**导出后 `res://` 指向 `.pck`**。若资源库里的外部资源按「保留文件（keep）」方式导出到 exe 旁，`res://res/pic/啤酒.png` 这类路径就会失效。
In the editor `res://` points at the project root; **after export `res://` points at the `.pck`**. External files exported next to the executable (export mode "keep") can no longer be found through `res://` paths.

`GameDB` 按以下顺序回退，解决该问题 —— `GameDB` falls back in this order to fix it:

1. `ResourceLoader`（编辑器内 / 已打进 pck 的资源）— editor or resources packed into the `.pck`;
2. `ProjectSettings.globalize_path()`（导出后通常为 exe 相对路径）— usually an exe-relative path after export;
3. `OS.get_executable_path().get_base_dir()` + `res://` 相对部分（exe 旁目录兜底）— the folder next to the executable.

命中文件系统路径后按扩展名直接读原始文件（图片 `Image.load_from_file`、音频 `AudioStreamWAV/OggVorbis/MP3.load_from_file`）。
Once a filesystem path is found, raw files are read directly by extension.

---

## 🤖 AI 导表 · AI-driven Import

对 AI 助手（如 Claude Code）说 `单表导出xxx`（xxx 为 CSV 的 `res://` 路径或用户绝对路径），助手会切换到导表页并调用接口完成导出。
Tell an AI assistant (e.g. Claude Code) `单表导出xxx` (xxx is a `res://` or absolute CSV path); it switches to the import page and exports automatically.

| 指令 Command | 说明 Description |
| --- | --- |
| `单表导出 res://test_tables/方块组数据.csv` | 导出一个 `res://` CSV |
| `单表导出 g:\...\方块组数据.csv` | 导出一个用户绝对路径 CSV（自动转 `res://`） |

插件启用时向 godot_ai 注册自定义 MCP 工具 `yukys_export_csv`（处理器 `data_tools/script/mcp_export_tool.gd`）。
On enable, the plugin registers a custom MCP tool `yukys_export_csv` with godot_ai.

---

## 🏗️ 目录结构 · Directory Structure

| 路径 Path | 作用 Purpose | 随游戏导出 Exported |
| --- | --- | --- |
| `addons/yukys_kits/runtime/` | 运行时代码（`game_db.gd` autoload、`json_data_tool.gd`） | ✅ |
| `addons/yukys_kits/data_tools/` | 编辑器工具代码（导表 / 预览 / 资源库 / 设置面板） | ❌ |
| `addons/yukys_kits/plugin.gd` | 插件入口（EditorPlugin） | ❌ |
| `addons/yukys_kits/skills/` | 附带的 AI skill 文档（导表 / AI 指令 / 开发流程） | 文档 |
| `test/` | 测试场景（数据 + 资源两个 tab） | ✅ |

> 关键边界 Boundary：编辑器代码（`data_tools/`）与运行时代码（`runtime/`）严格分离；游戏目录的测试场景只能调用 `GameDB` 暴露的公开接口，不能 `preload` 插件内部脚本。
> Editor code (`data_tools/`) and runtime code (`runtime/`) are strictly separated; non-plugin scenes may only use `GameDB`'s public API and must not `preload` internal plugin scripts.

---

## 🧪 测试 · Testing

插件自带 Godot 单元测试（`tests/`），需配合编辑器运行：

- `test_resource_load.gd` — 资源加载回归测试（路径解析 / 图片 / 音频 / Godot 资源 / 缓存 / 不存在资源）。
- `test_resource_colors.gd` — 资源分类背景色测试。
- `test_settings_data.gd` — 设置默认值与类型转换测试。

运行方式：在 Godot 编辑器中执行 `test_run`（MCP）或直接运行测试套件。
The plugin ships editor regression tests under `tests/`; run them via `test_run` (MCP) or the editor's test runner.

---

## 📄 许可证 · License

本项目采用 [MIT 许可证](LICENSE)。This project is licensed under the [MIT License](LICENSE).

© 2026 [Yukymura](https://github.com/Yukymura)

---

## 🙏 致谢 · Credits

- **作者 Author**：[Yukymura](https://github.com/Yukymura) · **仓库 Repository**：[Yukymura/Yukys-Kits-Dev](https://github.com/Yukymura/Yukys-Kits-Dev)
- 参考了个人项目中的导表插件实现思路，命名与实现已做优化。
  The data-import workflow is inspired by an earlier personal project, reworked for clarity and robustness.
