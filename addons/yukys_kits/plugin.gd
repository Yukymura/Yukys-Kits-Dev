@tool
extends EditorPlugin

const MAIN_PANEL := preload("res://addons/yukys_kits/excel_import_tools/scene/main_panel.tscn")
const DataImporterScript := preload("res://addons/yukys_kits/excel_import_tools/script/data_importer.gd")
const ConfigToolScript := preload("res://addons/yukys_kits/excel_import_tools/tool/config_tool.gd")
const McpCustomToolSpec := preload("res://addons/godot_ai/custom_tools/mcp_custom_tool_spec.gd")
const McpToolRegistry := preload("res://addons/godot_ai/custom_tools/mcp_tool_registry.gd")
const JsonData := preload("res://addons/yukys_kits/runtime/json_data_tool.gd")

const CONFIG_PATH := "res://addons/yukys_kits/excel_import_tools/config.json"
const DEFAULT_DOCK_NAME := "导表工具"

const PAGE_PREVIEW := "PreviewDock"
const PAGE_IMPORT := "ImportDock"
const EXPORT_TOOL_NAME := "yukys_export_csv"
const EXPORT_TOOL_SCRIPT := "res://addons/yukys_kits/excel_import_tools/script/mcp_export_tool.gd"

var _main_panel: Variant
var _importer: DataImporterScript

# 「AI 导表」自定义 MCP 工具（见 McpExportTool）需要访问当前插件实例的
# importer / 主面板。处理器是通过 script_path 惰性 new() 出来的 RefCounted，
# 与插件实例无引用关系，故用静态引用桥接（_enter_tree 写入、_exit_tree 清空）。
static var _importer_ref: Variant = null
static var _main_panel_ref: Variant = null

static func get_importer() -> Variant:
	return _importer_ref

static func get_main_panel() -> Variant:
	return _main_panel_ref

# GameDB 是运行时 autoload，由 project.godot 静态注册（随游戏导出）。
# DataImporter 是编辑器专用实例（挂在本插件节点下，而非 autoload），
# 因此它只存在于编辑器内：不写入 project.godot、不参与导出。
#
# 导表/预览页面已在 main_panel.tscn 中实例化（TabContainer 的两个 tab），
# 整个主面板用标准方式挂载为编辑器 Dock。
func _enter_tree() -> void:
	_register_project_settings()

	_importer = DataImporterScript.new()
	_importer.name = "DataImporter"
	add_child(_importer)
	_importer_ref = _importer

	var config := _load_config()

	_main_panel = MAIN_PANEL.instantiate()
	_main_panel.set_importer(_importer)
	# Dock 标签名取自主面板节点名，子面板 tab 标题取自 config.panel_names。
	_main_panel.name = str(config.get("dock_name", DEFAULT_DOCK_NAME))
	_main_panel.apply_tab_names(config.get("panel_names", {}))
	add_control_to_dock(DOCK_SLOT_BOTTOM, _main_panel)
	_main_panel_ref = _main_panel

	_connect_preview()
	_register_export_tool()

func _exit_tree() -> void:
	_unregister_export_tool()
	_disconnect_preview()
	remove_control_from_docks(_main_panel)
	if _main_panel:
		_main_panel.queue_free()
	if _importer:
		_importer.queue_free()
	_importer_ref = null
	_main_panel_ref = null

# 注册 ProjectSettings 键：数据库目录。编辑器侧 DataImporter 写入、运行时 GameDB 读取，
# 使 GameDB 不必写死 res://data。仅在键不存在时注册（避免覆盖用户已改的值）。
func _register_project_settings() -> void:
	if ProjectSettings.has_setting(JsonData.SETTING_DATA_DIR):
		return
	ProjectSettings.set_setting(JsonData.SETTING_DATA_DIR, JsonData.DEFAULT_DATA_DIR)
	ProjectSettings.add_property_info({
		"name": JsonData.SETTING_DATA_DIR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"hint_string": "res://",
	})

func _load_config() -> Dictionary:
	var r: Dictionary = ConfigToolScript.load_config(CONFIG_PATH)
	if not r.get("ok", false):
		return {}
	return r.get("data", {})

func _connect_preview() -> void:
	if _importer and not _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.connect(_on_preview_requested)

func _disconnect_preview() -> void:
	if _importer and _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.disconnect(_on_preview_requested)

# ================================================================================
# AI 导表 —— 注册自定义 MCP 工具「yukys_export_csv」
#
# 依赖 godot_ai 的 McpToolRegistry；project.godot 里 godot_ai 排在 yukys_kits
# 之前加载，故此处 get_instance() 应已就绪。若未加载则静默跳过（AI 导表功能
# 本身就需要 godot_ai，未加载时不提供该工具是合理的）。
# ================================================================================

func _register_export_tool() -> void:
	var registry = McpToolRegistry.get_instance()
	if registry == null:
		return
	var spec := McpCustomToolSpec.new()
	spec.name = EXPORT_TOOL_NAME
	spec.description = "单表导出：切换到导表页并调用 DataImporter.import_csv 把指定 CSV 导出为 JSON。参数 csv_path（res:// 或用户绝对路径）必填；output_dir 可选，缺省用 config.json 的 export_path。"
	spec.params_schema = {
		"type": "object",
		"properties": {
			"csv_path": {"type": "string", "description": "CSV 文件路径（res:// 或用户绝对路径）"},
			"output_dir": {"type": "string", "description": "可选：导出目录，缺省用 config.json 的 export_path"},
		},
		"required": ["csv_path"],
	}
	spec.script_path = EXPORT_TOOL_SCRIPT
	spec.method = &"export_csv"
	spec.source_path = "res://addons/yukys_kits/plugin.cfg"
	spec.requires_writable = true
	registry.register(spec)

func _unregister_export_tool() -> void:
	var registry = McpToolRegistry.get_instance()
	if registry != null:
		registry.unregister(EXPORT_TOOL_NAME)

# 点击数据树 JSON 后：渲染预览并切到预览 tab。
func _on_preview_requested(path: String) -> void:
	if _main_panel and _main_panel.has_method("get_page"):
		var preview: Variant = _main_panel.get_page(PAGE_PREVIEW)
		if preview and preview.has_method("show_preview"):
			preview.show_preview(path)
		if _main_panel.has_method("show_page"):
			_main_panel.show_page(PAGE_PREVIEW)
