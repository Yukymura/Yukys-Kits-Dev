@tool
extends EditorPlugin

const IMPORT_DOCK := preload("res://addons/yukys_kits/excel_import_tools/scene/import_dock.tscn")
const DATA_PREVIEW := preload("res://addons/yukys_kits/excel_import_tools/scene/data_preview.tscn")
const DATA_IMPORTER := "res://addons/yukys_kits/excel_import_tools/scene/data_importer.tscn"
const GAME_DB := "res://addons/yukys_kits/excel_import_tools/scene/game_db.tscn"
const CONFIG_PATH := "res://addons/yukys_kits/excel_import_tools/config.json"
const ConfigTool := preload("res://addons/yukys_kits/excel_import_tools/tool/config_tool.gd")

const DEFAULT_DOCK_NAME := "导表工具"
const PREVIEW_SCREEN_NAME := "数据预览"

var _dock: Control
var _preview: Control

func _enter_tree() -> void:
	add_autoload_singleton("DataImporter", DATA_IMPORTER)
	add_autoload_singleton("GameDB", GAME_DB)

	_dock = IMPORT_DOCK.instantiate()
	_dock.name = _get_dock_name()
	add_control_to_dock(DOCK_SLOT_LEFT_BL, _dock)

	_preview = DATA_PREVIEW.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(_preview)
	_make_visible(false)

	DataImporter.preview_requested.connect(_on_preview_requested)

func _exit_tree() -> void:
	if DataImporter.preview_requested.is_connected(_on_preview_requested):
		DataImporter.preview_requested.disconnect(_on_preview_requested)
	remove_control_from_docks(_dock)
	if _dock:
		_dock.queue_free()
	if _preview:
		_preview.queue_free()
	remove_autoload_singleton("DataImporter")
	remove_autoload_singleton("GameDB")

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
