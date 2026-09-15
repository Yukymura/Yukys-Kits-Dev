---
name: excel-import
description: 使用 Yuky's Kits 的导表工具（data_tools）时使用——包括理解/编写规定格式的 CSV、走 CSV→JSON 导表流程、按需扩展导表代码、游戏内调取导表数据，以及读取导表日志排查问题。
---

# 导表（data_tools）

把「规定格式」的 CSV 表格导出为 JSON 数据文件，并在游戏内通过 `GameDB` 访问。
插件根目录：`addons/yukys_kits/`。
- `runtime/` —— 游戏代码（随游戏导出）。
- `data_tools/` —— 编辑器工具代码（导出时排除）。

## 导表相关代码指引

### 目录结构

| 路径 | 作用 | 导出 |
| --- | --- | --- |
| `runtime/game_db.gd` | 运行时 autoload `GameDB`，游戏内取数据 | ✅ |
| `runtime/json_data_tool.gd` | JSON 读写 + 类型转换（编辑器写 / 运行时读共用） | ✅ |
| `data_tools/script/data_importer.gd` | 编辑器专用实例 `DataImporter`（plugin.gd 创建并注入），串起导表流程（含 `read_table` / `table_exists`） | ❌ |
| `data_tools/script/import_dock.gd` | 编辑器 Dock 面板（选 CSV、选导出路径、触发导表、预览与重复提醒） | ❌ |
| `data_tools/script/mcp_export_tool.gd` | 「AI 导表」自定义 MCP 工具处理器（`yukys_export_csv`：切导表页 + 调 `import_csv`） | ❌ |
| `data_tools/script/preview_dock.gd` | 主面板「数据预览」（数据库路径、数据树浏览、把 JSON 渲染成表格） | ❌ |
| `data_tools/tool/csv_parser.gd` | 解析规定格式 CSV | ❌ |
| `data_tools/tool/config_tool.gd` | 读写 `config.json` | ❌ |
| `data_tools/tool/logger.gd` | 导表日志 | ❌ |
| `data_tools/config.json` | 配置：`export_path` / `log_path` / `dock_name` / `panel_names` | ❌ |

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
DataImporter.read_table(csv_path)             -> { ok, data:{header, keys, types, values} / error }  # 导表面板预览用
DataImporter.table_exists(output_dir, table_name) -> bool                                            # 是否已有同名 JSON
DataImporter.load_data_file(path)             -> { ok, data:{table_name, data, types} / error }      # 预览用
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
- `GameDB._ready()` 会在启动时从 ProjectSettings（键 `addons/yukys_kits/data_dir`，缺省 `res://data`）读取数据库路径，再 `JsonData.load_all()` 载入该目录下所有 JSON。该键由编辑器侧 `DataImporter` 在用户设置导出路径时同步写入，故运行时跟随用户配置、不写死。

### 取数 API

```gdscript
# 取所有表名：Array[String]（已排序，供下拉列表等枚举用）
var names: Array = GameDB.get_table_names()

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

## 资源库资源加载（需求 2.1）

`GameDB` 除取数外，还提供从「资源库」加载外部导入资源（图片/音频/Godot 资源）的能力。资源库目录与数据库目录一样，由编辑器「设置」页配置、`DataImporter` 同步写入 ProjectSettings（键 `addons/yukys_kits/resource_dir`，缺省 `res://res`）。

### API

```gdscript
GameDB.get_resource_dir()        # String         资源库目录（ProjectSettings，缺省 res://res）
GameDB.resolve_resource_path(p)  # String         相对路径 → 拼上资源库目录；res:// / user:// / 绝对路径原样返回
GameDB.list_resource_files()     # Array[String]  资源库下所有资源文件（相对资源库目录的路径，已排序）
GameDB.get_resource_type(p)      # String         资源分类：image / audio / godot / ""
GameDB.is_resource_file(p)       # bool           是否为受支持的资源文件
GameDB.load_sprite(p)            # Texture2D      加载图片（png/jpg/webp/...）
GameDB.load_audio(p)             # AudioStream    加载音频（wav/ogg/mp3/...）
GameDB.load_resource(p)          # Resource       加载 Godot 资源（.tres/.res/.tscn/.gdshader 等）
GameDB.clear_resource_cache()    # void           清空资源缓存
```

`p` 支持两种写法：相对资源库的路径（`"pic/啤酒.png"`）或完整 `res://` 路径（`"res://res/pic/啤酒.png"`）。加载失败（文件不存在）返回 `null`，不报错，业务代码按需判空。

`list_resource_files()` 返回相对资源库目录的路径（如 `pic/啤酒.png`），可直接传给 `load_sprite` / `load_audio` / `load_resource`；`get_resource_type()` 用于按分类区分图片/音频/Godot 资源（做文件树着色、选择加载分支等）。

### 性能：缓存

同一路径重复加载会命中缓存、返回**同一实例**，避免反复解析/解码。需要重新加载或主动释放内存时调用 `clear_resource_cache()`。缓存按「解析后的完整路径」为键。

### 导出后 res:// 路径变化的问题（重点）

- 编辑器里 `res://` 指向项目根目录；**导出后 `res://` 指向 `.pck`**。
- 若资源库里的外部资源按「保留文件（Export Mode: keep）」方式导出到 exe 旁（而非打进 pck），`res://res/pic/啤酒.png` 这类路径在导出后就会失效。
- `GameDB` 的加载按以下顺序回退，解决该问题：
  1. `ResourceLoader`（编辑器内 / 已按导入方式打进 pck 的资源）；
  2. `ProjectSettings.globalize_path()` 得到的全局化路径（编辑器=真实路径；导出后=exe 相对路径）；
  3. `OS.get_executable_path().get_base_dir()` + `res://` 相对部分（exe 旁目录兜底）。
- 命中文件系统路径后，按扩展名直接读原始文件：图片走 `Image.load_from_file` + `ImageTexture.create_from_image`，音频走 `AudioStreamWAV/OggVorbis/MP3.load_from_file`（均为静态方法，失败返回 null）。

### 使用示例

```gdscript
var card: Texture2D = GameDB.load_sprite("pic/啤酒.png")          # 相对资源库
var icon: Texture2D = GameDB.load_sprite("res://res/pic/弯刀.png") # 完整 res://
var bgm: AudioStream = GameDB.load_audio("sfx/我的世界拾取物品.mp3")
var theme: Theme = GameDB.load_resource("theme/theme1.tres")       # Godot 资源

var card_path: String = GameDB.resolve_resource_path("pic/啤酒.png") # res://res/pic/啤酒.png
GameDB.clear_resource_cache()  # 需要热更新资源时先清缓存再重新加载
```

## AI 导表（单表导出）

当用户输入指令 `单表导出xxx` 或 `单表导出 xxx`（xxx 为 CSV 的 `res://` 路径或用户绝对路径）时，AI 助手应切换到导表页并调用现有接口 `DataImporter.import_csv` 完成导出。

> AI 指令的权威清单（触发句式、工具、参数、返回值）见 `ai-commands` skill；本节保留导表实现细节与排查。

### 触发命令

| 指令 | 说明 |
| --- | --- |
| `单表导出 res://test_tables/方块组数据.csv` | 导出一个 `res://` CSV |
| `单表导出 g:\...\方块组数据.csv` | 导出一个用户绝对路径 CSV（自动转 `res://`） |

### 执行方式（自定义 MCP 工具）

插件启用时向 godot_ai 注册了一个自定义 MCP 工具 `yukys_export_csv`（处理器 `data_tools/script/mcp_export_tool.gd`，注册代码在 `plugin.gd`）。它内部做两件事：

1. 切到导表页：`MainPanel.show_page("ImportDock")`。
2. 调用现有接口：`DataImporter.import_csv(csv_path, output_dir)`。

AI 通过 `custom_manage` 调用该工具：

```
custom_manage(op="invoke", params={
    "tool_name": "yukys_export_csv",
    "params": {"csv_path": "res://test_tables/方块组数据.csv"},
})
```

- `csv_path`（必填）：CSV 路径，`res://` 或用户绝对路径均可。
- `output_dir`（可选）：导出目录；缺省用 `config.json` 的 `export_path`。

返回值（MCP 信封，dispatcher 已解包）：

- 成功 → `{ "ok": true, "message": "导表成功: res://data/xxx.json（N 行）" }`
- 失败 → `{ "status": "error", "error": { "code": "MISSING_REQUIRED_PARAM"|"INTERNAL_ERROR", "message": "失败原因" } }`

### 路径解析规则

- `res://` / `user://` 开头 → 原样使用。
- 用户绝对路径（含盘符）→ 若在项目内则转成 `res://`，否则原样传给 `FileAccess`（仍可读）。
- 导出 JSON 里记录的 `import_path` 即解析后的 CSV 路径。

### 结果与日志

- 导表结果直接看工具返回的 `message`（如「导表成功: res://data/方块组数据.json（N 行）」）。
- 完整过程/失败原因另见 `logs/import.log`（见下文「导表 log 读取方法」）。

### 排查

- 工具返回「导表工具未就绪」→ 插件未启用，检查 `project.godot` 的 `editor_plugins/enabled` 是否含 `yukys_kits`。
- `custom_manage(op="list")` 看不到 `yukys_export_csv` → 插件尚未重载；在「项目设置 → 插件」里禁用再启用 yukys_kits（或重启编辑器）。

## 设置界面（数据驱动）

设置 tab（排在主面板最后）集中管理插件配置：数据库路径、资源库路径、资源库分类背景色。界面由两张导表驱动（同 CSV→JSON 流程），新增/调整设置项只需改表再重新导表。

### 配置表

| 表 | CSV | 导出的 JSON | 作用 |
| --- | --- | --- | --- |
| 设置栏配置表 | `data_tools/chart/设置栏配置表.csv` | `data_tools/datas/setting_colume_config.json` | 栏位（分区）：`id` / `colume_name` / `index` |
| 设置项配置表 | `data_tools/chart/设置项配置表.csv` | `data_tools/datas/setting_config.json` | 设置项：类型、关联字段、顺序、默认值 |

设置项配置表字段：

| 字段 | 说明 |
| --- | --- |
| `id` | 设置项唯一 id（表内标识，无业务含义） |
| `setting_name` | 显示在设置项上的名字 |
| `type` | 控件类型：`1`=勾选框、`2`=输入框、`3`=路径框、`4`=选项框、`5`=颜色框 |
| `data_name` | 持久化字段名（即写入 `config.json` 的键） |
| `colume` | 所属栏位 id（对应设置栏配置表的 id） |
| `index` | 栏位内排序权重（小的排前面） |
| `description` | 鼠标悬停提示（可选） |
| `option` | `Array[String]`，供选项框使用（可选） |
| `default` | 默认值，**均为 String**，按 `type` 转换（见下） |

### 默认值与重置（需求 3.2）

- 默认值来自配置表 `default` 列，导出后仍是 String，按 `type` 转换：
  - `type=5`（颜色）→ `Color`（`Color.from_string`，hex 无 `#`，如 `459fff40`）
  - `type=1`（勾选）→ `bool`（`true`/`1`/`yes` 视为真）
  - 其余 → 保持 String
- 加载顺序：`DataImporter._load_settings()` 先读 `setting_config.json` 把每行默认值按类型缓存到 `_setting_defaults`（`_load_setting_defaults`），再读 `config.json`；**用户未设置过的字段回退到配置表默认值**（配置表缺失时再回退到脚本里字段声明处的硬编码值）。
- 每个设置项右侧有一个「重置」图标按钮（Godot 检查器同款 `Reload` 图标，tooltip「重置为默认值」），点击调用 `set_setting(data_name, get_setting_default(data_name))` 恢复默认并刷新控件。

### 设置项读写 API（DataImporter）

```gdscript
DataImporter.get_setting(data_name)          # 读当前值（颜色返回 Color、路径返回 String）
DataImporter.set_setting(data_name, value)   # 写值并持久化到 config.json
DataImporter.get_setting_default(data_name)  # 读配置表默认值（已按类型转换），无则 null
```

新增设置项：在「设置项配置表」加一行 → 重新导表 → 在 `DataImporter.get_setting` / `set_setting` 的 `match` 里补一个分支。颜色字段的十六进制序列化由 `_save_config()` 统一处理（`Color.to_html(true)` / `_parse_color`）。

## 导表 log 读取方法

### 日志位置

- 默认路径：`addons/yukys_kits/data_tools/logs/import.log`
- 可在 `data_tools/config.json` 的 `log_path` 项覆盖。

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

设置相关字段（`resource_path`、`pic_bg_color` / `audio_bg_color` / `res_bg_color`）与默认值/重置机制见上文「设置界面（数据驱动）」。
