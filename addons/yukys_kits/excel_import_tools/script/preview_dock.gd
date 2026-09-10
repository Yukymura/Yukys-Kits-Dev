# ================================================================================
# PreviewDock —— JSON 数据可视化预览（编辑器主面板，只读；含行号、字段名列表头）
# 同时承担「数据库路径」设置与「数据树」浏览（点击数据树 JSON → 预览）。
# ================================================================================

@tool
extends Control

@onready var path_label: Label = $Scroll/VBox/Header/PathLabel
@onready var preview_tree: Tree = $Scroll/VBox/PreviewTree
@onready var data_path_edit: LineEdit = $Scroll/VBox/HBox3/DataPathEdit
@onready var data_tree: Tree = $Scroll/VBox/DataTree
@onready var select_data_button: Button = $Scroll/VBox/HBox3/SelectDataButton
@onready var data_dir_dialog: FileDialog = $DataDirDialog

const TREE_ALLOWED_EXTENSIONS: Array = ["json"]

var _watch_timer: Timer
var _dir_snapshot: Dictionary = {}
var _importer: Variant

func set_importer(importer) -> void:
	_importer = importer
	if is_node_ready():
		_connect_importer_signals()
		_refresh_data_path()

func _ready() -> void:
	_setup()
	_connect_signals()
	_connect_importer_signals()
	_refresh_data_path()

func _setup() -> void:
	preview_tree.visible = false
	data_path_edit.editable = false

	data_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	data_dir_dialog.access = FileDialog.ACCESS_RESOURCES

	_watch_timer = Timer.new()
	_watch_timer.wait_time = 1.0
	_watch_timer.autostart = true
	_watch_timer.timeout.connect(_on_watch_timeout)
	add_child(_watch_timer)

func _connect_signals() -> void:
	select_data_button.pressed.connect(_on_select_data_pressed)
	data_dir_dialog.dir_selected.connect(_on_data_dir_selected)
	data_tree.item_selected.connect(_on_tree_item_selected)

func _connect_importer_signals() -> void:
	if _importer == null:
		return
	if not _importer.export_path_changed.is_connected(_refresh_data_path):
		_importer.export_path_changed.connect(_refresh_data_path)
		_importer.files_changed.connect(_refresh_tree)

# ================================================================================
# 预览

func show_preview(path: String) -> void:
	path_label.text = path
	_render(path)

func _render(path: String) -> void:
	if _importer == null:
		return
	preview_tree.clear()
	preview_tree.hide_root = true
	var r: Dictionary = _importer.load_data_file(path)
	if not r.ok:
		preview_tree.visible = true
		preview_tree.columns = 1
		preview_tree.set_column_title(0, "错误")
		var _root := preview_tree.create_item()
		var err_item := preview_tree.create_item(_root)
		err_item.set_text(0, "加载失败: %s" % str(r.error))
		return
	var info: Dictionary = r.data
	var rows: Dictionary = info.get("data", {})
	var types: Dictionary = info.get("types", {})
	# 没有数据行时隐藏表格
	if rows.is_empty():
		preview_tree.visible = false
		return
	preview_tree.visible = true
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
	preview_tree.set_column_title(1, "key")
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

# ================================================================================
# 数据库路径 + 数据树

func _on_select_data_pressed() -> void:
	data_dir_dialog.popup_centered_ratio(0.6)

func _on_data_dir_selected(path: String) -> void:
	_importer.set_export_path(path)

func _refresh_data_path() -> void:
	if _importer == null:
		return
	data_path_edit.text = _importer.get_export_path()
	_refresh_tree()

func _refresh_tree() -> void:
	var path: String = _importer.get_export_path()
	_load_tree(path)
	_dir_snapshot = _dir_signature(path)

func _load_tree(path: String) -> void:
	data_tree.clear()
	if path.is_empty():
		return
	var root := data_tree.create_item()
	var root_name := path.get_file()
	root.set_text(0, root_name if not root_name.is_empty() else path)
	_populate(root, path)

func _populate(parent: TreeItem, dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		var full := dir_path.path_join(item)
		if dir.current_is_dir():
			var folder_item := data_tree.create_item(parent)
			folder_item.set_text(0, item)
			folder_item.set_icon(0, get_theme_icon("folder", "FileDialog"))
			_populate(folder_item, full)
		elif item.get_extension().to_lower() in TREE_ALLOWED_EXTENSIONS:
			var file_item := data_tree.create_item(parent)
			file_item.set_text(0, item)
			file_item.set_icon(0, get_theme_icon("file", "FileDialog"))
			file_item.set_meta("full_path", full)
		item = dir.get_next()
	dir.list_dir_end()

# ================================================================================
# 文件监听（数据目录变更时自动刷新数据树）

func _on_watch_timeout() -> void:
	if _importer == null:
		return
	var path: String = _importer.get_export_path()
	var sig := _dir_signature(path)
	if sig != _dir_snapshot:
		_dir_snapshot = sig
		_refresh_tree()

func _dir_signature(path: String) -> Dictionary:
	var sig: Dictionary = {}
	_scan_dir(path, sig)
	return sig

func _scan_dir(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		var full := path.path_join(item)
		if dir.current_is_dir():
			out[full] = "dir"
			_scan_dir(full, out)
		else:
			out[full] = FileAccess.get_modified_time(full)
		item = dir.get_next()
	dir.list_dir_end()

# ================================================================================
# 点击数据树 JSON → 预览

func _on_tree_item_selected() -> void:
	var item := data_tree.get_selected()
	if item == null:
		return
	var path: String = item.get_meta("full_path", "")
	if path.is_empty() or path.get_extension().to_lower() != "json":
		return
	_importer.request_preview(path)

# ================================================================================
