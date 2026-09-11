# ================================================================================
# GameDB —— 游戏内数据访问（autoload，仅运行时）
#
# 用法：
#   GameDB.get_table_names()   -> Array[String]          所有数据表名（已排序）
#   GameDB.get_table("表名")   -> { id: { 字段: 值, ... }, ... }
#   GameDB.get_row("表名", id) -> { 字段: 值, ... }
#
# 运行时不依赖编辑器的 DataImporter/config/log，直接从 DATA_DIR 读取导出的 JSON。
# ================================================================================

extends Node

const JsonData := preload("res://addons/yukys_kits/runtime/json_data_tool.gd")
const DATA_DIR := "res://data"

var _data: Dictionary = {}

func _ready() -> void:
	_data = JsonData.load_all(DATA_DIR)

# 所有数据表名（已排序），供下拉列表等场景枚举。
func get_table_names() -> Array:
	var names: Array = _data.keys()
	names.sort()
	return names

func get_table(table_name: String) -> Dictionary:
	return _data.get(table_name, {})

func get_row(table_name: String, id) -> Dictionary:
	var table: Dictionary = get_table(table_name)
	return table.get(id, {})

# ================================================================================
