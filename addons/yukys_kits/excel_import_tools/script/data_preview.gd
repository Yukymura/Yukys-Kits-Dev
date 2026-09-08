# ================================================================================
# DataPreview —— JSON 数据可视化预览（编辑器主面板，只读；含行号、字段名列表头）
# ================================================================================

@tool
extends Control

@onready var path_label: Label = $VBox/Header/PathLabel
@onready var preview_tree: Tree = $VBox/PreviewTree

func show_preview(path: String) -> void:
	path_label.text = path
	_render(path)

func _render(path: String) -> void:
	preview_tree.clear()
	preview_tree.hide_root = true
	var r := DataImporter.load_data_file(path)
	if not r.ok:
		preview_tree.columns = 1
		preview_tree.set_column_title(0, "错误")
		var _root := preview_tree.create_item()
		var err_item := preview_tree.create_item(_root)
		err_item.set_text(0, "加载失败: %s" % str(r.error))
		return
	var info: Dictionary = r.data
	var rows: Dictionary = info.get("data", {})
	var types: Dictionary = info.get("types", {})
	# 字段列顺序以 JSON 的 types 键序为准（= 原 CSV 字段顺序），
	# 再兜底补充数据行里出现但 types 缺失的字段。
	var fields: Array = []
	for f in types.keys():
		if not fields.has(f):
			fields.append(f)
	var ids := rows.keys()
	ids.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for id in ids:
		for field in rows[id]:
			if not fields.has(field):
				fields.append(field)
	# 列布局：0=行号，1=id，2..=字段（与原表列顺序一致）
	preview_tree.columns = 2 + fields.size()
	preview_tree.set_column_title(0, "行号")
	preview_tree.set_column_expand(0, false)
	preview_tree.set_column_custom_minimum_width(0, 50)
	preview_tree.set_column_title(1, "id")
	preview_tree.set_column_expand(1, false)
	preview_tree.set_column_custom_minimum_width(1, 50)
	for i in fields.size():
		preview_tree.set_column_title(i + 2, str(fields[i]))
		preview_tree.set_column_expand(i + 2, true)
	var root := preview_tree.create_item()
	var index := 0
	for id in ids:
		index += 1
		var row_item := preview_tree.create_item(root)
		row_item.set_text(0, str(index))
		row_item.set_text(1, str(id))
		var row_dict: Dictionary = rows[id]
		for i in fields.size():
			row_item.set_text(i + 2, _value_to_text(row_dict.get(fields[i], "")))

func _value_to_text(value) -> String:
	if value is Array:
		var parts: Array = []
		for e in value:
			parts.append(_value_to_text(e))
		return ";".join(parts)
	return str(value)
