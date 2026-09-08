# ================================================================================
# DataPreview —— JSON 数据可视化预览（编辑器主面板，只读）
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
	var r := DataImporter.load_data_file(path)
	if not r.ok:
		preview_tree.columns = 1
		preview_tree.set_column_title(0, "id")
		var err_item := preview_tree.create_item()
		err_item.set_text(0, "加载失败: %s" % str(r.error))
		return
	var info: Dictionary = r.data
	var rows: Dictionary = info.get("data", {})
	var columns: Array = []
	var ids := rows.keys()
	ids.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for id in ids:
		var row: Dictionary = rows[id]
		for field in row:
			if not columns.has(field):
				columns.append(field)
	preview_tree.columns = 1 + columns.size()
	preview_tree.set_column_title(0, "id")
	preview_tree.set_column_expand(0, false)
	for i in columns.size():
		preview_tree.set_column_title(i + 1, str(columns[i]))
	var root := preview_tree.create_item()
	for id in ids:
		var row_item := preview_tree.create_item(root)
		row_item.set_text(0, str(id))
		var row_dict: Dictionary = rows[id]
		for i in columns.size():
			row_item.set_text(i + 1, _value_to_text(row_dict.get(columns[i], "")))

func _value_to_text(value) -> String:
	if value is Array:
		var parts: Array = []
		for e in value:
			parts.append(_value_to_text(e))
		return ";".join(parts)
	return str(value)
