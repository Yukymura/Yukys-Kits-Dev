---
name: ai-development
description: 使用 AI 开发 Yuky's Kits 插件（Godot 4.7）时的开发流程、代码边界、需求跟踪、Godot MCP 验证方法与常见坑。当要新增/修改插件功能、在游戏目录写测试场景、用 Godot MCP 验证代码、或排查 Tree/game_eval 等 Godot 4.7 API 坑时使用。
---

# AI 开发流程（Yuky's Kits）

本 skill 记录开发 Yuky's Kits 插件的**标准流程与约束**，让 AI 助手每次开发都走一致的路径，少踩重复的坑。

## 项目概览

- **插件名**：Yuky'sKits（`addons/yukys_kits/`），Godot 4.7。
- **首个功能**：导表工具（excel_import_tools）——把「规定格式」CSV 导出为 JSON，游戏内通过 autoload `GameDB` 访问。
- **需求来源**：`addons/yukys_kits/原始需求`（自然语言需求）+ `addons/yukys_kits/需求文档.md`（结构化跟踪，FEAT-ID + 状态图例 ✅/🚧/🔲…）。

## 目录结构与代码边界（最重要）

| 路径 | 作用 | 随游戏导出 |
| --- | --- | --- |
| `runtime/` | 游戏运行时代码（`game_db.gd` autoload、`json_data_tool.gd`） | ✅ |
| `excel_import_tools/` | 编辑器工具代码（`data_importer`、`import_dock`、`preview_dock`、`tool/` 下的 parser/config/logger） | ❌ |
| `plugin.gd` | 插件入口（EditorPlugin，`_enter_tree`/`_exit_tree`） | ❌ |
| `skills/` | 本插件附带的 skill 文档 | 文档 |
| `test/` | **测试场景（游戏目录，非插件目录）** | ✅ |
| `data/` | 导出的 JSON 数据（`res://data`，`export_path` 默认值） | ✅ |
| `原始需求` / `需求文档.md` | 需求跟踪 | 文档 |

关键边界：

1. **编辑器代码与运行时代码必须分离**：
   - `GameDB` 是静态 autoload（写进 `project.godot`，随游戏导出）。
   - `DataImporter` 是编辑器专用实例（`plugin.gd` 里 `new()` 并注入 dock/preview），**不写进 autoload、不随游戏导出**。
2. **非插件场景只允许调用插件暴露的接口**，禁止调用插件内部接口：
   - ✅ 可用：`GameDB`（`get_table_names()` / `get_table()` / `get_row()`）。
   - ❌ 禁用：`JsonData`、`DataImporter`、`CsvParser`、`ConfigTool`、`Logger` 等内部类。
   - 测试场景缺什么公开能力，就在 `game_db.gd`（运行时）里**新增公开方法**，而不是让测试场景去 `preload` 内部脚本。
3. **「AI 导表」通过 godot_ai 自定义 MCP 工具桥接**：插件 `_enter_tree` 向 `McpToolRegistry` 注册 `yukys_export_csv`（处理器 `excel_import_tools/script/mcp_export_tool.gd`，经 `plugin.gd` 的静态访问器拿 importer/主面板）。所有 AI 指令的权威清单在 `skills/ai-commands/SKILL.md`；改导表或页面切换逻辑时，记得同步该工具、`ai-commands` 指令清单与 `skills/excel-import/SKILL.md` 的「AI 导表」章节。

## 标准开发流程

1. **读需求**：先读 `原始需求` 对应条目 + `需求文档.md` 对应 FEAT，明确验收标准。
2. **定位改动目录**：编辑器功能 → `excel_import_tools/`；游戏内能力 → `runtime/`；测试/验证 → `test/`。
3. **实现**：遵循现有代码风格（见下「代码规范」）；如需新公开接口，加到 `GameDB` 并在对应 `skills/*/SKILL.md` 里文档化。
4. **更新需求跟踪**：改完在 `需求文档.md` 补「功能点清单」勾选 + 「状态更新记录」一行；`原始需求` 条目后加「(已实现)」。
5. **验证**：走「验证方法」流程，用 Godot MCP 实跑确认，而非只靠静态读代码。
6. **记录坑**：遇到 Godot 4.7 的新坑，补充到本 skill 的「常见坑」。

## 验证方法（Godot MCP）

本环境连着 Godot 编辑器的 MCP 服务（`mcp__godot-ai__*`）。优先实跑验证：

| 工具 | 用途 |
| --- | --- |
| `editor_state` | 查编辑器状态 / 是否 playing |
| `scene_open` + `scene_get_hierarchy` | 打开场景并确认节点层级/类型/命名正确 |
| `project_run` (mode=main) | 运行游戏 |
| `project_manage` (op=stop) | 停止游戏 |
| `editor_manage` (op=game_eval) | **在运行中的游戏里执行 GDScript**，返回结果——验证逻辑最直接的手段 |
| `game_manage` (op=get_scene_tree / get_ui_elements) | 检查运行时场景树 / UI 元素（文本、rect、可见性） |
| `logs_read` (source=game/editor/plugin/all) | 读日志排查（game=运行时输出，editor=脚本错误，plugin=MCP 收发） |
| `editor_screenshot` (source=game) | 截图 |

`game_eval` 返回 JSON 结果，适合做断言式验证，例如：

```gdscript
# 验证下拉列表与表格行数
var scene = get_tree().current_scene
var sel = scene.get_node('Margin/VBox/TableRow/TableSelector')
var tree = scene.get_node('Margin/VBox/DataTree')
return {
    'options': [sel.get_item_text(i) for i in range(sel.item_count)],
    'rows': tree.get_root().get_child_count(),
}
```

排查运行时问题的日志优先级：`logs_read(source='game')`（运行时输出）→ `source='editor'`（脚本报错）→ `source='all'`（含 MCP 收发，能看出游戏是否真的 launch / helper 是否 live）。

## 常见坑（Godot 4.7，均实测踩过）

1. **`Tree.create_item()`（不传父节点）会把首个 item 错当成根节点**，导致第一行数据丢失。必须显式创建隐藏根节点，数据行作为其子节点：
   ```gdscript
   var root: TreeItem = data_tree.create_item()   # 隐藏根（hide_root=true）
   for ...:
       var item: TreeItem = data_tree.create_item(root)  # 显式父节点
   ```
2. **`game_eval` 里 `%UniqueName` 不可用**，会报 null instance。改用 `get_tree().current_scene.get_node('相对路径')` 或绝对路径 `/root/TestScene/...`（`game_manage` 返回的路径是相对当前场景根的，如 `/TestScene/...`）。
3. **`game_eval` 里直接 `line_edit.text = x` 不触发 `text_changed` 信号**，需手动 `line_edit.emit_signal('text_changed', x)` 才能触发连接的回调。真机用户输入会正常触发，测试脚本需模拟。
4. **`project_run` 偶尔返回 `stopped`**，或游戏跑几秒就停——多为 MCP 桥接/焦点时序问题而非代码 bug。确认游戏是否真的 launch：看 `logs_read(source='all')` 里有没有 `mcp:hello from game_helper`；没有脚本报错（`source='editor'` 为空、`godot.log` 无 `SCRIPT ERROR`）就重跑。
5. **新增 `.gd`/`.tscn` 后编辑器会重新导入**（`readiness -> importing`），可能打断刚发起的 run，重跑即可。
6. **`game_manage` 的 `op=debug_status` 映射有误**（内部报 `Unknown command: game_debug_control`），改用 `get_scene_tree` / `get_ui_elements` / `game_eval`。

## 代码规范

- **注释用中文**，顶部用 `# ====...` 分隔块注释说明文件职责与关键用法（照抄现有文件风格）。
- **命名 snake_case**；变量用类型推断 `:=`，类型标注只加在公开函数签名与 `@onready`。
- **统一结果模式**：返回 `{ "ok": true, "data": ... }` 或 `{ "ok": false, "error": "原因" }`，用 `_ok(data)` / `_fail(reason)` 辅助函数（见 `json_data_tool.gd`）。
- **CSV → 类型** 双向转换集中在 `json_data_tool.gd`：写方向 `cell_to_value`、读方向 `json_to_value` 两个 `match`，新增类型改这里。
- **字段过滤规则**（`#` 前缀、空行）集中在 `csv_parser.gd`。
