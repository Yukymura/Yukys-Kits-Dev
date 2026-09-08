# ================================================================================
# GameDB —— 游戏内数据访问（autoload，仅运行时）
#
# 用法：
#   GameDB.get_table("表名")   -> { id: { 字段: 值, ... }, ... }
#   GameDB.get_row("表名", id) -> { 字段: 值, ... }
# ================================================================================

extends Node

var _data: Dictionary = {}

func _ready() -> void:
	_data = DataImporter.get_all_data()

func get_table(table_name: String) -> Dictionary:
	return _data.get(table_name, {})

func get_row(table_name: String, id) -> Dictionary:
	var table: Dictionary = get_table(table_name)
	return table.get(id, {})

# ================================================================================
