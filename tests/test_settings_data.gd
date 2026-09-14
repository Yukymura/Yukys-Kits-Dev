# ================================================================================
# 设置界面数据流诊断 —— 复现 settings_dock 的栏位分组逻辑
# ================================================================================

@tool
extends McpTestSuite

const Config := preload("res://addons/yukys_kits/data_tools/tool/config_tool.gd")
const DataImporter := preload("res://addons/yukys_kits/data_tools/script/data_importer.gd")

func suite_name() -> String:
	return "settings_data"

func test_colume_table_loads() -> void:
	var colume_table := _load_table_data("res://addons/yukys_kits/data_tools/datas/setting_colume_config.json")
	assert_true(colume_table.has("1"), "colume_table 缺少键 '1': %s" % [colume_table])
	assert_true(colume_table.has("2"), "colume_table 缺少键 '2': %s" % [colume_table])

func test_section_name_grouping() -> void:
	var colume_table := _load_table_data("res://addons/yukys_kits/data_tools/datas/setting_colume_config.json")
	var item_table := _load_table_data("res://addons/yukys_kits/data_tools/datas/setting_config.json")
	var sections := {}
	for id in item_table:
		var item: Dictionary = item_table[id]
		var colume_id := str(int(item.get("colume", 0)))
		if not sections.has(colume_id):
			var colume: Dictionary = colume_table.get(colume_id, {})
			sections[colume_id] = {
				"name": str(colume.get("colume_name", "")),
				"index": int(colume.get("index", 0)),
				"items": [],
			}
		sections[colume_id]["items"].append(item)
	assert_true(sections.has("1"), "sections 缺少 '1': %s" % [sections])
	assert_true(sections.has("2"), "sections 缺少 '2': %s" % [sections])
	assert_true(sections["1"]["name"] == "数据", "栏位1名称错误: '%s'" % [sections["1"]["name"]])
	assert_true(sections["2"]["name"] == "资源", "栏位2名称错误: '%s'" % [sections["2"]["name"]])

func test_item_defaults_present() -> void:
	var item_table := _load_table_data("res://addons/yukys_kits/data_tools/datas/setting_config.json")
	assert_true(item_table.has("2003"), "配置表缺少 2003（音频背景色）")
	for id in item_table:
		var item: Dictionary = item_table[id]
		assert_true(item.has("default"), "配置项 %s 缺少 default 字段" % [id])

func test_default_value_conversion() -> void:
	var importer = DataImporter.new()
	assert_eq(importer.get_setting_default("export_path"), "res://data", "export_path 默认值应保持 String")
	assert_eq(importer.get_setting_default("resource_path"), "res://res", "resource_path 默认值应保持 String")
	assert_true(importer.get_setting_default("pic_bg_color") is Color, "pic_bg_color 默认值应转换为 Color")
	assert_true(importer.get_setting_default("audio_bg_color") is Color, "audio_bg_color 默认值应转换为 Color")
	assert_true(importer.get_setting_default("res_bg_color") is Color, "res_bg_color 默认值应转换为 Color")
	importer.free()

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
