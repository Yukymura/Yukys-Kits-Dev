# ================================================================================
# SettingsDock —— 设置界面（排在 tab 页最后，按功能分区组织设置）
#
# 分区：
#   - 数据：数据库路径（DataImporter.export_path，也是运行时 GameDB 读取的数据目录）。
#   - 资源库：资源库路径（DataImporter.resource_path，供资源预览面板浏览）。
#   - 资源库：分类背景配色（DataImporter.get/set_resource_color，图片/音频/Godot 资源）。
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
@onready var image_color_picker: ColorPickerButton = $Scroll/VBox/ImageColorRow/ImageColorPicker
@onready var audio_color_picker: ColorPickerButton = $Scroll/VBox/AudioColorRow/AudioColorPicker
@onready var godot_color_picker: ColorPickerButton = $Scroll/VBox/GodotColorRow/GodotColorPicker

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
	image_color_picker.popup_closed.connect(_on_image_color_picker_closed)
	audio_color_picker.popup_closed.connect(_on_audio_color_picker_closed)
	godot_color_picker.popup_closed.connect(_on_godot_color_picker_closed)

func _refresh() -> void:
	if _importer == null:
		return
	db_path_edit.text = _importer.get_export_path()
	resource_path_edit.text = _importer.get_resource_path()
	image_color_picker.color = _importer.get_resource_color("image")
	audio_color_picker.color = _importer.get_resource_color("audio")
	godot_color_picker.color = _importer.get_resource_color("godot")

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

# 配色只在用户关闭取色器时保存一次（popup_closed），避免拖动取色时反复写盘。
func _on_image_color_picker_closed() -> void:
	_importer.set_resource_color("image", image_color_picker.color)

func _on_audio_color_picker_closed() -> void:
	_importer.set_resource_color("audio", audio_color_picker.color)

func _on_godot_color_picker_closed() -> void:
	_importer.set_resource_color("godot", godot_color_picker.color)

# ================================================================================
