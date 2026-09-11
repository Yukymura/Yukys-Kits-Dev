---
name: ai-commands
description: 记录 Yuky's Kits 插件暴露给 AI 助手的全部自然语言指令（当前为「单表导出 xxx」）——触发句式、参数、底层自定义 MCP 工具、返回值与示例。当用户输入「单表导出/导表」等指令、需要确认 AI 能响应哪些命令、或新增一条 AI 指令时使用。
---

# AI 指令总览（Yuky's Kits）

本 skill 是本插件**所有 AI 指令的权威清单**。每条指令对应一个插件自定义 MCP 工具（经 godot_ai 的 `McpToolRegistry` 注册），AI 助手收到自然语言指令后，通过 `custom_manage(op="invoke", …)` 调用对应工具完成。

> 与其它 skill 的分工：本 skill 只回答「用户能对 AI 下哪些指令、怎么触发」；指令背后的实现细节见 `excel-import`（导表代码）、`ai-development`（开发流程）。

## 指令清单

| 指令 | 触发句式 | 作用 | MCP 工具 | 状态 |
| --- | --- | --- | --- | --- |
| 单表导出 | `单表导出 xxx` / `单表导出xxx`（xxx = CSV 的 `res://` 或用户绝对路径） | 切到导表页并调用 `DataImporter.import_csv`，把指定 CSV 导出为 JSON | `yukys_export_csv` | ✅ |

---

## 单表导出

### 触发句式

| 句式 | 示例 |
| --- | --- |
| `单表导出 <路径>`（带空格） | `单表导出 res://test_tables/方块组数据.csv` |
| `单表导出<路径>`（无空格） | `单表导出 g:\...\特殊方块数据.csv` |

> 用户实际也常用「`导表 <路径>`」作为口语化简写，同样按单表导出处理。

### 参数

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `csv_path` | ✅ | CSV 路径：`res://`、`user://` 或用户绝对路径（含盘符）均可 |
| `output_dir` | ❌ | 导出目录；缺省用 `config.json` 的 `export_path`（默认 `res://data`） |

### 执行方式

AI 通过 godot_ai 的自定义 MCP 工具 `yukys_export_csv` 调用：

```
custom_manage(op="invoke", params={
    "tool_name": "yukys_export_csv",
    "params": {"csv_path": "res://test_tables/方块组数据.csv"},
})
```

处理器 `excel_import_tools/script/mcp_export_tool.gd`（方法 `export_csv`）内部做两件事：

1. 切到导表页：`MainPanel.show_page("ImportDock")`。
2. 调用现有接口：`DataImporter.import_csv(csv_path, output_dir)`。

### 路径解析规则

- `res://` / `user://` 开头 → 原样使用。
- 用户绝对路径（含盘符）→ 若在项目内则 `ProjectSettings.localize_path()` 转成 `res://`，否则原样传给 `FileAccess`（仍可读）。
- 导出 JSON 的 `import_path` 字段记录解析后的路径。

### 返回值（MCP 信封，dispatcher 已解包）

- 成功 → `{ "ok": true, "message": "导表成功: res://data/xxx.json（N 行）" }`
- 失败 → `{ "status": "error", "error": { "code": "MISSING_REQUIRED_PARAM" | "INTERNAL_ERROR", "message": "失败原因" } }`

失败 `code` 与典型原因：

| code | 原因 |
| --- | --- |
| `MISSING_REQUIRED_PARAM` | 未传 `csv_path` |
| `INTERNAL_ERROR` | 插件未启用（DataImporter 不存在）；或 `import_csv` 本身失败（路径错、格式错、id 重复等，见 `excel-import` 的排查章节） |

### 示例

输入：

```
单表导出 G:\Work\Godot\GodotProj\Yukys-Kits-Dev\test_tables\特殊方块数据.csv
```

输出 JSON 名取 CSV 首行首格的表名（如 `key_block_data.json`），而非文件名。

---

## 新增一条 AI 指令（给开发者）

1. 在 `excel_import_tools/script/` 下新建处理器 `.gd`，方法返回 MCP 信封：成功 `{"data": {…}}`，失败 `ErrorCodes.make(code, msg)`（参考 `mcp_export_tool.gd`）。
2. 在 `plugin.gd` 的 `_register_export_tool()` 处用 `McpToolRegistry.register(McpCustomToolSpec)` 注册，`_exit_tree` 里注销。
3. 在本 skill 的「指令清单」加一行，并新增对应详细章节（触发句式/参数/执行方式/返回值）。
4. 在 `需求文档.md`（新增 FEAT 行）与 `原始需求` 里跟踪状态。

## 相关 skill

- `excel-import` —— 导表代码、CSV 格式、日志排查（单表导出的实现细节）。
- `ai-development` —— 插件开发的流程、边界与验证方法。
