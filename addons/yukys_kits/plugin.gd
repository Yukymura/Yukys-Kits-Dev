@tool
extends EditorPlugin

const IMPORT_DOCK := preload("res://addons/yukys_kits/excel_import_tools/scene/import_dock.tscn")
const DATA_PREVIEW := preload("res://addons/yukys_kits/excel_import_tools/scene/data_preview.tscn")
const CONFIG_PATH := "res://addons/yukys_kits/excel_import_tools/config.json"
const ConfigTool := preload("res://addons/yukys_kits/excel_import_tools/tool/config_tool.gd")
const DataImporterScript := preload("res://addons/yukys_kits/excel_import_tools/script/data_importer.gd")

const DEFAULT_DOCK_NAME := "导表工具"
const PREVIEW_SCREEN_NAME := "数据预览"

var _dock: Variant
var _preview: Variant
var _importer: DataImporterScript

# GameDB 是运行时 autoload，由 project.godot 静态注册（随游戏导出）。
# DataImporter 是编辑器专用实例（挂在本插件节点下，而非 autoload），
# 因此它只存在于编辑器内：不写入 project.godot、不参与导出。
func _enter_tree() -> void:
	_importer = DataImporterScript.new()
	_importer.name = "DataImporter"
	add_child(_importer)

	_dock = IMPORT_DOCK.instantiate()
	_dock.name = _get_dock_name()
	_dock.set_importer(_importer)
	add_control_to_dock(DOCK_SLOT_LEFT_BL, _dock)

	_preview = DATA_PREVIEW.instantiate()
	_preview.set_importer(_importer)
	get_editor_interface().get_editor_main_screen().add_child(_preview)
	_make_visible(false)

	_connect_preview()

func _exit_tree() -> void:
	_disconnect_preview()
	remove_control_from_docks(_dock)
	if _dock:
		_dock.queue_free()
	if _preview:
		_preview.queue_free()
	if _importer:
		_importer.queue_free()

func _connect_preview() -> void:
	if _importer and not _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.connect(_on_preview_requested)

func _disconnect_preview() -> void:
	if _importer and _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.disconnect(_on_preview_requested)

# ================================================================================
# 主面板（数据预览）

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return PREVIEW_SCREEN_NAME

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func _make_visible(visible: bool) -> void:
	if _preview:
		_preview.visible = visible

func _on_preview_requested(path: String) -> void:
	if _preview and _preview.has_method("show_preview"):
		_preview.show_preview(path)
	get_editor_interface().set_main_screen_editor(PREVIEW_SCREEN_NAME)

func _get_dock_name() -> String:
	var cfg := ConfigTool.load_config(CONFIG_PATH)
	if cfg.ok:
		var name := str(cfg.data.get("dock_name", "")).strip_edges()
		if not name.is_empty():
			return name
	return DEFAULT_DOCK_NAME
