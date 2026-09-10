# ================================================================================
# ImportDock —— 导表面板（只负责导入：CSV / 导出路径 / 导表按钮）
# 数据树与数据库路径已移至 PreviewDock 页。
# ================================================================================

@tool
extends Control

@onready var csv_path_edit: LineEdit = $Scroll/VBox/HBox1/CsvPathEdit
@onready var output_path_edit: LineEdit = $Scroll/VBox/HBox2/OutputPathEdit
@onready var status_label: Label = $Scroll/VBox/StatusLabel
@onready var select_csv_button: Button = $Scroll/VBox/HBox1/SelectCsvButton
@onready var select_output_button: Button = $Scroll/VBox/HBox2/SelectOutputButton
@onready var import_button: Button = $Scroll/VBox/ImportButton
@onready var csv_file_dialog: FileDialog = $CsvFileDialog
@onready var output_dir_dialog: FileDialog = $OutputDirDialog

var _importer: Variant

func set_importer(importer) -> void:
	_importer = importer

func _ready() -> void:
	_setup()
	_connect_signals()

func _setup() -> void:
	csv_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	csv_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	csv_file_dialog.clear_filters()
	csv_file_dialog.add_filter("*.csv", "CSV 表格 (*.csv)")

	output_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	output_dir_dialog.access = FileDialog.ACCESS_RESOURCES

func _connect_signals() -> void:
	select_csv_button.pressed.connect(_on_select_csv_pressed)
	select_output_button.pressed.connect(_on_select_output_pressed)
	import_button.pressed.connect(_on_import_pressed)

	csv_file_dialog.file_selected.connect(_on_csv_selected)
	output_dir_dialog.dir_selected.connect(_on_output_selected)

# ================================================================================
# 交互

func _on_select_csv_pressed() -> void:
	csv_file_dialog.popup_centered_ratio(0.6)

func _on_select_output_pressed() -> void:
	output_dir_dialog.popup_centered_ratio(0.6)

func _on_csv_selected(path: String) -> void:
	csv_path_edit.text = path

func _on_output_selected(path: String) -> void:
	output_path_edit.text = path + "/"

func _on_import_pressed() -> void:
	var r: Dictionary = _importer.import_csv(csv_path_edit.text.strip_edges(), output_path_edit.text.strip_edges())
	_set_status(r["message"], r["ok"])

# ================================================================================
# 显示

func _set_status(text: String, ok: bool) -> void:
	status_label.text = text
	status_label.modulate = Color(0.4, 0.9, 0.4) if ok else Color(1.0, 0.4, 0.4)

# ================================================================================
