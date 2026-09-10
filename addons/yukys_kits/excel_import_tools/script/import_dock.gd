# ================================================================================
# ImportDock —— 导表面板
# ================================================================================

@tool
extends Control

@onready var csv_path_edit: LineEdit = $Scroll/VBox/HBox1/CsvPathEdit
@onready var output_path_edit: LineEdit = $Scroll/VBox/HBox2/OutputPathEdit
@onready var data_path_edit: LineEdit = $Scroll/VBox/HBox3/DataPathEdit
@onready var status_label: Label = $Scroll/VBox/StatusLabel
@onready var data_tree: Tree = $Scroll/VBox/DataTree
@onready var select_csv_button: Button = $Scroll/VBox/HBox1/SelectCsvButton
@onready var select_output_button: Button = $Scroll/VBox/HBox2/SelectOutputButton
@onready var select_data_button: Button = $Scroll/VBox/HBox3/SelectDataButton
@onready var import_button: Button = $Scroll/VBox/ImportButton
@onready var csv_file_dialog: FileDialog = $CsvFileDialog
@onready var output_dir_dialog: FileDialog = $OutputDirDialog
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
	data_path_edit.editable = false

	csv_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	csv_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	csv_file_dialog.clear_filters()
	csv_file_dialog.add_filter("*.csv", "CSV 表格 (*.csv)")

	output_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	output_dir_dialog.access = FileDialog.ACCESS_RESOURCES

	data_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	data_dir_dialog.access = FileDialog.ACCESS_RESOURCES

	_watch_timer = Timer.new()
	_watch_timer.wait_time = 1.0
	_watch_timer.autostart = true
	_watch_timer.timeout.connect(_on_watch_timeout)
	add_child(_watch_timer)

func _connect_signals() -> void:
	select_csv_button.pressed.connect(_on_select_csv_pressed)
	select_output_button.pressed.connect(_on_select_output_pressed)
	select_data_button.pressed.connect(_on_select_data_pressed)
	import_button.pressed.connect(_on_import_pressed)

	csv_file_dialog.file_selected.connect(_on_csv_selected)
	output_dir_dialog.dir_selected.connect(_on_output_selected)
	data_dir_dialog.dir_selected.connect(_on_data_dir_selected)

	data_tree.item_selected.connect(_on_tree_item_selected)

func _connect_importer_signals() -> void:
	if _importer == null:
		return
	if not _importer.export_path_changed.is_connected(_refresh_data_path):
		_importer.export_path_changed.connect(_refresh_data_path)
		_importer.files_changed.connect(_refresh_tree)

# ================================================================================
# 交互

func _on_select_csv_pressed() -> void:
	csv_file_dialog.popup_centered_ratio(0.6)

func _on_select_output_pressed() -> void:
	output_dir_dialog.popup_centered_ratio(0.6)

func _on_select_data_pressed() -> void:
	data_dir_dialog.popup_centered_ratio(0.6)

func _on_csv_selected(path: String) -> void:
	csv_path_edit.text = path

func _on_output_selected(path: String) -> void:
	output_path_edit.text = path + "/"

func _on_data_dir_selected(path: String) -> void:
	_importer.set_export_path(path)

func _on_import_pressed() -> void:
	var r: Dictionary = _importer.import_csv(csv_path_edit.text.strip_edges(), output_path_edit.text.strip_edges())
	_set_status(r["message"], r["ok"])

# ================================================================================
# 显示

func _set_status(text: String, ok: bool) -> void:
	status_label.text = text
	status_label.modulate = Color(0.4, 0.9, 0.4) if ok else Color(1.0, 0.4, 0.4)

func _refresh_data_path() -> void:
	if _importer == null:
		return
	data_path_edit.text = _importer.get_export_path()
	_refresh_tree()

func _refresh_tree() -> void:
	var path: String = _importer.get_export_path()
	_load_tree(path)
	_dir_snapshot = _dir_signature(path)

# ================================================================================
# 数据树

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
# 可视化预览（点击数据树 JSON → 主面板预览）

func _on_tree_item_selected() -> void:
	var item := data_tree.get_selected()
	if item == null:
		return
	var path: String = item.get_meta("full_path", "")
	if path.is_empty() or path.get_extension().to_lower() != "json":
		return
	_importer.request_preview(path)
