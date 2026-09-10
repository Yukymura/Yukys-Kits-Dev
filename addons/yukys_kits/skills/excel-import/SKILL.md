---
name: excel-import
description: 使用 Yuky's Kits 的导表工具（excel_import_tools）时使用——包括理解/编写规定格式的 CSV、走 CSV→JSON 导表流程、按需扩展导表代码、游戏内调取导表数据，以及读取导表日志排查问题。
---

# 导表（excel_import_tools）

把「规定格式」的 CSV 表格导出为 JSON 数据文件，并在游戏内通过 `GameDB` 访问。
插件根目录：`addons/yukys_kits/`。
- `runtime/` —— 游戏代码（随游戏导出）。
- `excel_import_tools/` —— 编辑器工具代码（导出时排除）。

## 导表相关代码指引

### 目录结构

| 路径 | 作用 | 导出 |
| --- | --- | --- |
| `runtime/game_db.gd` | 运行时 autoload `GameDB`，游戏内取数据 | ✅ |
| `runtime/json_data_tool.gd` | JSON 读写 + 类型转换（编辑器写 / 运行时读共用） | ✅ |
| `excel_import_tools/script/data_importer.gd` | 编辑器专用实例 `DataImporter`（plugin.gd 创建并注入），串起导表流程 | ❌ |
| `excel_import_tools/script/import_dock.gd` | 编辑器 Dock 面板（选 CSV、导出路径、触发导表） | ❌ |
| `excel_import_tools/script/preview_dock.gd` | 主面板「数据预览」（数据库路径、数据树浏览、把 JSON 渲染成表格） | ❌ |
| `excel_import_tools/tool/csv_parser.gd` | 解析规定格式 CSV | ❌ |
| `excel_import_tools/tool/config_tool.gd` | 读写 `config.json` | ❌ |
| `excel_import_tools/tool/logger.gd` | 导表日志 | ❌ |
| `excel_import_tools/config.json` | 配置：`export_path` / `log_path` / `dock_name` / `panel_names` | ❌ |

### 导表流程（代码调用链）

```
import_dock._on_import_pressed()
  └─ DataImporter.import_csv(csv_path, output_dir)
       ├─ CsvParser.read_csv(csv_path)          # 解析 CSV → { header, keys, types, values }
       ├─ JsonData.create_json(out_path, csv_path, csv_data)  # 类型转换 + 序列化 JSON
       └─ _refresh_filesystem(out_path)          # 刷新数据树 / 编辑器文件系统
```

关键函数签名：

```gdscript
# DataImporter（编辑器专用实例，不随游戏导出）
DataImporter.import_csv(csv_path, output_dir) -> { ok, message }
DataImporter.load_data_file(path)             -> { ok, data:{table_name, data, types} / error }  # 预览用
DataImporter.set_export_path(path)
DataImporter.request_preview(path)            # 触发主面板预览

# GameDB（运行时 autoload）
GameDB.get_table("表名")    # { id: {字段:值}, ... }
GameDB.get_row("表名", id)  # {字段:值}
```

### 导出结果 JSON 结构

```json
{
  "table_name": "表名",
  "import_path": "源 CSV 路径",
  "update_time": "更新时间",
  "types": { "字段": "类型", ... },
  "data": { "id": { "字段": 值, ... }, ... }
}
```

`data` 里的 id 键在 `load_file` 时会被 `_convert_id` 从字符串转回 int（`"1"` → `1`）。

### CSV 规定格式

| 行 | 内容 | 说明 |
| --- | --- | --- |
| 1 | `表名` | 第一格为表名，其余忽略 |
| 2 | `*id` + `字段:类型` | 首格以 `*` 开头（第一列为 id，不导出），之后每格 `字段名:类型` |
| 3+ | `id` + 值 | 首格为 id，之后为各字段值 |

- 字段名以 `#` 开头 → 该字段不导出；id 以 `#` 开头或为空 → 该行不导出。
- 支持类型：`String` `int` `float` `bool` `Vector2` `Vector3` `Vector2i` `Vector3i` `Array[类型]`
- 数组值用 `;` 分隔（`a;b;c`）；向量值写成 `(x, y)` 或 `(x, y, z)`。

示例：

|  | A | B | C | D |
| --- | --- | --- | --- | --- |
| 1 | ItemTable |  |  |  |
| 2 | *id | name:String | price:int | tags:Array[String] |
| 3 | 1 | 剑 | 100 | 武器;近战 |
| 4 | 2 | 盾 | 80 | 防具 |

### 扩展导表代码

- **新增类型**：改 `json_data_tool.gd` 的 `cell_to_value`（写方向）与 `json_to_value`（读方向）两个 `match` 分支。
- **调整字段过滤规则**：改 `csv_parser.gd` 的 `read_csv`（`#` 前缀、空行/注释行处理）。
- **改 Dock 面板布局**：改 `import_dock.tscn` + `import_dock.gd`。

## 游戏代码调取导表数据

### 前置条件

- `GameDB` 是 `project.godot` 里的静态 autoload，游戏运行时直接按名称访问。
- `DataImporter` 是编辑器专用实例（由 plugin.gd 创建并注入 dock/preview），**不随游戏导出**，运行时不可用。
- `GameDB._ready()` 会在启动时通过 `JsonData.load_all(DATA_DIR)` 一次性把 `res://data` 下所有 JSON 载入内存（`DATA_DIR` 是 `game_db.gd` 里的常量，需与编辑器 `export_path` 默认值一致）。

### 取数 API

```gdscript
# 取整张表：{ id: { 字段: 值, ... }, ... }
var table: Dictionary = GameDB.get_table("ItemTable")

# 取某一行：{ 字段: 值, ... }
var row: Dictionary = GameDB.get_row("ItemTable", 1)
```

### 使用示例

```gdscript
# 遍历整张表
for id in GameDB.get_table("ItemTable"):
	var row: Dictionary = GameDB.get_table("ItemTable")[id]
	print(id, " -> ", row["name"], " 价格:", row["price"])

# 直接取单行字段
var price: int = GameDB.get_row("ItemTable", 1)["price"]

# 数组字段（导出时用 ; 分隔，读回后为 Godot Array）
var tags: Array = GameDB.get_row("ItemTable", 1)["tags"]  # ["武器", "近战"]
```

### 数据形态说明

- `get_table` 返回的键是 **id**，读取时已被还原为 **int**（`"1"` → `1`），用整数 id 取行。
- 字段值按 `types` 里声明的类型还原成 Godot 类型：
  - `int` → `int`，`float` → `float`，`bool` → `bool`，`String` → `String`
  - `Vector2/3` → `Vector2/3`，`Vector2i/3i` → `Vector2i/3i`
  - `Array[T]` → `Array`，元素按 `T` 递归还原
- 取不存在的表/行返回空 `Dictionary`（`{}`），不报错，业务代码按需判空。

### 编辑器内读单文件（预览用）

```gdscript
# DataImporter 仅供编辑器使用；读单个 JSON（含 types）
var r := DataImporter.load_data_file("res://data/ItemTable.json")
if r.ok:
	var rows: Dictionary = r.data["data"]   # { 1: {字段:值}, ... }
	var types: Dictionary = r.data["types"] # { 字段: "类型", ... }
```

运行时读整目录请直接走 `GameDB`（`get_table` / `get_row`），或调用 `JsonData.load_all("res://data")`。

## 导表 log 读取方法

### 日志位置

- 默认路径：`addons/yukys_kits/excel_import_tools/logs/import.log`
- 可在 `excel_import_tools/config.json` 的 `log_path` 项覆盖。

### 输出规则

| 级别 | 写文件 | 写控制台 | 用途 |
| --- | --- | --- | --- |
| `INFO` | ✅ | ❌ | 导表过程记录 |
| `WARN` | ✅ | ❌ | 警告 |
| `ERROR` | ✅ | ✅（`printerr`） | 失败原因 |
| `DONE` | ✅ | ✅（`print`） | 导表结果 |

> 控制台只输出「导表结果」和「失败原因」，完整记录/过程/失败原因都在日志文件里。

### 日志行格式

```
[时间] [级别] 消息
```

例：`[2026-09-09 10:00:00] [DONE] 导表成功: res://data/ItemTable.json（3 行）`

### 排查步骤

1. 读 `logs/import.log` 尾部（追加模式），看最近的 `ERROR` / `DONE` 行。
2. 若控制台报错但日志为空 → 检查 `config.json` 的 `log_path` 是否为空/无效。
3. 常见失败原因：
   - 「文件不存在 / 无法打开」→ CSV 路径错误。
   - 「缺少表头」→ 第 1 行第一格不是表名。
   - 「缺少字段行」→ 第 2 行首格不是 `*` 开头。
   - 「id 重复」→ 数据行首格有重复 id。
   - 「JSON 结构不完整」→ 读的 JSON 缺 `table_name`/`data`/`types` 字段。

### 配置项

`config.json` 支持：`export_path`（导出目录，默认 `res://data`）、`log_path`（日志路径）、`dock_name`（Dock 标签名，改后需重载插件）、`panel_names`（各子面板 tab 标题，key 为页面节点名）。
