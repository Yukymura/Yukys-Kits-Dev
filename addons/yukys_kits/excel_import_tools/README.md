# 导表工具（excel_import_tools）

把「规定格式」的 CSV 表格导出为 JSON 数据文件，并在游戏内通过 `GameDB` 访问。

## CSV 规定格式

| 行 | 内容 | 说明 |
| --- | --- | --- |
| 1 | `表名` | 第一格为表名，其余忽略 |
| 2 | `*id` + `字段:类型` | 首格以 `*` 开头标记（如 `*id`，第一列为 id），之后每格 `字段名:类型` |
| 3+ | `id` + 值 | 首格为 id，之后为各字段的值 |

- 字段名以 `#` 开头 → 该字段不导出。
- id 以 `#` 开头或为空 → 该行不导出。
- 支持类型：`String` `int` `float` `bool` `Vector2` `Vector3` `Vector2i` `Vector3i` `Array[类型]`
- 数组值用 `;` 分隔，例如 `a;b;c`
- 向量值写成 `(x, y)` 或 `(x, y, z)`

### 示例

|  | A | B | C | D |
| --- | --- | --- | --- | --- |
| 1 | ItemTable |  |  |  |
| 2 | *id | name:String | price:int | tags:Array[String] |
| 3 | 1 | 剑 | 100 | 武器;近战 |
| 4 | 2 | 盾 | 80 | 防具 |
| 5 | #3 | 忽略行 | 0 |  |

## 导出结果

导出为 `{导出路径}/{表名}.json`：

```json
{
	"table_name": "ItemTable",
	"import_path": "res://tables/ItemTable.csv",
	"update_time": "2026-09-07 22:00:00",
	"types": { "name": "String", "price": "int", "tags": "Array[String]" },
	"data": { "1": { "name": "剑", "price": 100, "tags": ["武器", "近战"] } }
}
```

## 游戏内访问

```gdscript
var table: Dictionary = GameDB.get_table("ItemTable")  # { 1: {...}, 2: {...} }
var row: Dictionary = GameDB.get_row("ItemTable", 1)   # { "name": "剑", ... }
```

## 日志

- 控制台只输出导表结果与失败原因。
- 详细过程（记录、过程、失败原因）写入 `logs/import.log`，路径可在 `config.json` 中配置。

## 配置

`config.json` 支持以下配置项：

| 键 | 说明 | 默认值 |
| --- | --- | --- |
| `export_path` | 数据导出目录 | `res://data` |
| `log_path` | 日志文件路径 | `…/logs/import.log` |
| `dock_name` | Dock 面板标签页的名称 | `导表工具` |

> 修改 `dock_name` 后需重新加载插件（禁用再启用，或重启编辑器）才会生效。
