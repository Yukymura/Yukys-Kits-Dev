@tool
extends EditorPlugin

const IMPORT_DOCK := preload("res://addons/yukys_kits/excel_import_tools/scene/import_dock.tscn")
const DATA_PREVIEW := preload("res://addons/yukys_kits/excel_import_tools/scene/data_preview.tscn")
const CONFIG_PATH := "res://addons/yukys_kits/excel_import_tools/config.json"
const ConfigTool := preload("res://addons/yukys_kits/excel_import_tools/tool/config_tool.gd")
const DataImporterScript := preload("res://addons/yukys_kits/excel_import_tools/script/data_importer.gd")

const DEFAULT_DOCK_NAME := "导表工具"
const PREVIEW_SCREEN_NAME := "数据预览"

var _dock: Control
var _preview: Control

# DataImporter / GameDB 由 project.godot 的 [autoload] 静态注册，插件不再动态增删（静态 autoload）。
# EditorPlugin 脚本的解析时机早于 autoload，故这里用 /root 节点查找而非裸标识符，
# 避免「Identifier not declared」解析死锁。
func _enter_tree() -> void:
	_dock = IMPORT_DOCK.instantiate()
	_dock.name = _get_dock_name()
	add_control_to_dock(DOCK_SLOT_LEFT_BL, _dock)

	_preview = DATA_PREVIEW.instantiate()
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

func _connect_preview() -> void:
	var importer: Node = _get_importer()
	if importer is DataImporterScript:
		if not importer.preview_requested.is_connected(_on_preview_requested):
			importer.preview_requested.connect(_on_preview_requested)

func _disconnect_preview() -> void:
	var importer: Node = _get_importer()
	if importer is DataImporterScript:
		if importer.preview_requested.is_connected(_on_preview_requested):
			importer.preview_requested.disconnect(_on_preview_requested)

func _get_importer() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DataImporter")

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
