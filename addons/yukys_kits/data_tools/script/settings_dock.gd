# ================================================================================
# SettingsDock —— 设置界面（排在 tab 页最后，按功能分区组织设置）
#
# 分区：
#   - 数据：数据库路径（DataImporter.export_path，也是运行时 GameDB 读取的数据目录）。
#   - 资源库：资源库路径（DataImporter.resource_path，供资源预览面板浏览）。
# 所有设置均通过 DataImporter 的 setter 持久化到 config.json（合并写入，保留其它字段）。
# ================================================================================

@tool
extends Control

@onready var db_path_edit: LineEdit = $Scroll/VBox/DataSection/DBPathEdit
@onready var select_db_button: Button = $Scroll/VBox/DataSection/SelectDBButton
@onready var resource_path_edit: LineEdit = $Scroll/VBox/ResourceSection/ResourcePathEdit
@onready var select_resource_button: Button = $Scroll/VBox/ResourceSection/SelectResourceButton
@onready var db_dir_dialog: FileDialog = $DBDirDialog
@onready var resource_dir_dialog: FileDialog = $ResourceDirDialog

var _importer: Variant

func set_importer(importer) -> void:
	_importer = importer
	if is_node_ready():
		_refresh()

func _ready() -> void:
	_setup()
	_connect_signals()
	_refresh()

func _setup() -> void:
	db_path_edit.editable = false
	resource_path_edit.editable = false
	db_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	db_dir_dialog.access = FileDialog.ACCESS_RESOURCES
	resource_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	resource_dir_dialog.access = FileDialog.ACCESS_RESOURCES

func _connect_signals() -> void:
	select_db_button.pressed.connect(_on_select_db_pressed)
	select_resource_button.pressed.connect(_on_select_resource_pressed)
	db_dir_dialog.dir_selected.connect(_on_db_dir_selected)
	resource_dir_dialog.dir_selected.connect(_on_resource_dir_selected)

func _refresh() -> void:
	if _importer == null:
		return
	db_path_edit.text = _importer.get_export_path()
	resource_path_edit.text = _importer.get_resource_path()

func _on_select_db_pressed() -> void:
	db_dir_dialog.popup_centered_ratio(0.6)

func _on_select_resource_pressed() -> void:
	resource_dir_dialog.popup_centered_ratio(0.6)

func _on_db_dir_selected(path: String) -> void:
	_importer.set_export_path(path)
	_refresh()

func _on_resource_dir_selected(path: String) -> void:
	_importer.set_resource_path(path)
	_refresh()

# ================================================================================
