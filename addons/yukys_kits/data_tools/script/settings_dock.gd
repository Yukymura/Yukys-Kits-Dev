# ================================================================================
# SettingsDock —— 设置界面（排在 tab 页最后）
#
# 数据驱动：根据「设置栏配置表」+「设置项配置表」导出的 JSON 生成界面。
#   - 栏位（栏）→ SettingSection 场景
#   - 设置项     → SettingItem 场景（按 type 显示不同控件）
# 每个设置项按 data_name 通过 DataImporter.get_setting / set_setting 读写，
# 由 DataImporter 统一持久化到 config.json。
# ================================================================================

@tool
extends Control

const SettingSectionScene := preload("res://addons/yukys_kits/data_tools/scene/setting_section.tscn")
const SettingItemScene := preload("res://addons/yukys_kits/data_tools/scene/setting_item.tscn")
const Config := preload("res://addons/yukys_kits/data_tools/tool/config_tool.gd")

const COLUME_CONFIG_PATH := "res://addons/yukys_kits/data_tools/datas/setting_colume_config.json"
const ITEM_CONFIG_PATH := "res://addons/yukys_kits/data_tools/datas/setting_config.json"

@onready var items_box: VBoxContainer = $Scroll/VBox

var _importer: Variant

func set_importer(importer) -> void:
	_importer = importer
	if is_node_ready():
		_build()

func _ready() -> void:
	_build()

func _build() -> void:
	if _importer == null:
		return
	for child in items_box.get_children():
		child.queue_free()

	var colume_table := _load_table_data(COLUME_CONFIG_PATH)  # id -> {colume_name, index}
	var item_table := _load_table_data(ITEM_CONFIG_PATH)      # id -> {setting_name, type, ...}

	# 按栏位分组
	var sections := {}  # colume_id(String) -> {name, index, items: Array}
	for id in item_table:
		var item: Dictionary = item_table[id]
		# 导表 JSON 里数字被解析成 float（1 -> 1.0），而栏位表的键是字符串 "1"，
		# 必须先用 int() 归一化再转字符串，否则 str(1.0) == "1.0" 匹配不到栏位。
		var colume_id := str(int(item.get("colume", 0)))
		if not sections.has(colume_id):
			var colume: Dictionary = colume_table.get(colume_id, {})
			sections[colume_id] = {
				"name": str(colume.get("colume_name", "")),
				"index": int(colume.get("index", 0)),
				"items": [],
			}
		sections[colume_id]["items"].append(item)

	# 栏位按 index 排序
	var section_ids := sections.keys()
	section_ids.sort_custom(func(a, b): return sections[a]["index"] < sections[b]["index"])

	for colume_id in section_ids:
		var section: Dictionary = sections[colume_id]
		var section_node := SettingSectionScene.instantiate()
		items_box.add_child(section_node)
		section_node.setup(section["name"])

		var items: Array = section["items"]
		items.sort_custom(func(a, b): return a["index"] < b["index"])
		for item in items:
			var item_node := SettingItemScene.instantiate()
			section_node.add_item(item_node)
			item_node.setup(_importer, item)

func _load_table_data(path: String) -> Dictionary:
	var r := Config.load_config(path)
	if not r.get("ok", false):
		return {}
	var root: Variant = r.get("data", {})
	if root is Dictionary:
		var table: Variant = root.get("data", {})
		if table is Dictionary:
			return table
	return {}

# ================================================================================
