# ================================================================================
# ImportDock —— 导表面板（导入文件 / 导出路径 / 导表按钮 / 单表预览 / 重复提醒）
#
# 单表导表：
#   - 选择 CSV 后，底部预览该表数据（显示真实字段名）。
#   - 若该表在导出目录已有同名 JSON，在状态栏显示提示文字。
# ================================================================================

@tool
extends Control

const COLOR_NEUTRAL := Color(1, 1, 1)
const COLOR_OK := Color(0.4, 0.9, 0.4)
const COLOR_ERR := Color(1, 0.4, 0.4)
const COLOR_WARN := Color(1, 0.62, 0.3)

@onready var csv_path_edit: LineEdit = $Scroll/VBox/HBox1/CsvPathEdit
@onready var output_path_edit: LineEdit = $Scroll/VBox/HBox2/OutputPathEdit
@onready var status_label: Label = $Scroll/VBox/StatusLabel
@onready var select_csv_button: Button = $Scroll/VBox/HBox1/SelectCsvButton
@onready var select_output_button: Button = $Scroll/VBox/HBox2/SelectOutputButton
@onready var import_button: Button = $Scroll/VBox/ImportButton
@onready var preview_tree: Tree = $Scroll/VBox/PreviewTree
@onready var csv_file_dialog: FileDialog = $CsvFileDialog
@onready var output_dir_dialog: FileDialog = $OutputDirDialog

var _importer: Variant
var _table: Dictionary = {}  # 当前 CSV 解析出的单表 { header, keys, types, values }

func set_importer(importer) -> void:
	_importer = importer

func _ready() -> void:
	_setup()
	_connect_signals()
	# 导出路径默认取 importer 的 export_path，使「已存在同名 JSON」提示与数据库路径一致。
	if _importer != null:
		output_path_edit.text = _importer.get_export_path()

func _setup() -> void:
	csv_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	csv_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	csv_file_dialog.clear_filters()
	csv_file_dialog.add_filter("*.csv", "CSV 表格 (*.csv)")

	output_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	output_dir_dialog.access = FileDialog.ACCESS_RESOURCES

	preview_tree.hide_root = true

func _connect_signals() -> void:
	select_csv_button.pressed.connect(_on_select_csv_pressed)
	select_output_button.pressed.connect(_on_select_output_pressed)
	import_button.pressed.connect(_on_import_pressed)

	csv_file_dialog.file_selected.connect(_on_csv_selected)
	output_dir_dialog.dir_selected.connect(_on_output_selected)

	csv_path_edit.text_submitted.connect(_on_csv_text_submitted)
	output_path_edit.text_changed.connect(_on_output_text_changed)

# ================================================================================
# 交互

func _on_select_csv_pressed() -> void:
	csv_file_dialog.popup_centered_ratio(0.6)

func _on_select_output_pressed() -> void:
	output_dir_dialog.popup_centered_ratio(0.6)

func _on_csv_selected(path: String) -> void:
	csv_path_edit.text = path
	_load_table(path)

func _on_csv_text_submitted(path: String) -> void:
	_load_table(path.strip_edges())

func _on_output_selected(path: String) -> void:
	output_path_edit.text = path + "/"
	# 注：程序化设置 .text 不会触发 LineEdit.text_changed，故这里手动刷新状态。
	_refresh_status()

func _on_output_text_changed(_text: String) -> void:
	_refresh_status()

func _on_import_pressed() -> void:
	var r: Dictionary = _importer.import_csv(csv_path_edit.text.strip_edges(), output_path_edit.text.strip_edges())
	_set_status(str(r["message"]), COLOR_OK if r["ok"] else COLOR_ERR)

# ================================================================================
# 预览 / 状态

func _load_table(path: String) -> void:
	_table = {}
	_clear_preview()
	_refresh_status()
	if path.is_empty() or _importer == null:
		return
	var r: Dictionary = _importer.read_table(path)
	if not r.ok:
		_set_status("解析失败: %s" % str(r.error), COLOR_ERR)
		return
	_table = r.data
	_refresh_status()
	_render_preview()

# 刷新状态栏：空闲时显示「就绪」；表在导出目录已有同名 JSON 时显示重复提醒。
func _refresh_status() -> void:
	if _table.is_empty():
		_set_status("就绪", COLOR_NEUTRAL)
		return
	var tname := str(_table["header"])
	var out_dir := output_path_edit.text.strip_edges()
	var exists: bool = _importer != null and _importer.table_exists(out_dir, tname)
	if exists:
		_set_status("⚠ 数据库中已存在同名 JSON「%s.json」，导出将覆盖" % tname, COLOR_WARN)
	else:
		_set_status("就绪", COLOR_NEUTRAL)

func _render_preview() -> void:
	preview_tree.clear()
	if _table.is_empty():
		preview_tree.visible = false
		return
	var keys: Array = _table["keys"]
	var values: Array = _table["values"]
	if values.is_empty():
		preview_tree.visible = false
		return
	preview_tree.visible = true
	preview_tree.columns = 2 + keys.size()
	preview_tree.set_column_title(0, "行号")
	preview_tree.set_column_expand(0, false)
	preview_tree.set_column_custom_minimum_width(0, 50)
	preview_tree.set_column_title(1, "key")
	preview_tree.set_column_expand(1, false)
	preview_tree.set_column_custom_minimum_width(1, 50)
	for i in keys.size():
		preview_tree.set_column_title(i + 2, str(keys[i]))
		preview_tree.set_column_expand(i + 2, true)
	var root := preview_tree.create_item()
	var index := 0
	for row in values:
		index += 1
		var item := preview_tree.create_item(root)
		item.set_text(0, str(index))
		item.set_text(1, str(row[0]))
		for i in keys.size():
			item.set_text(i + 2, str(row[i + 1]))

func _clear_preview() -> void:
	preview_tree.clear()
	preview_tree.visible = false

# ================================================================================
# 显示

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.modulate = color

# ================================================================================
