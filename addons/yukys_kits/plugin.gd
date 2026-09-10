@tool
extends EditorPlugin

const MAIN_PANEL := preload("res://addons/yukys_kits/excel_import_tools/scene/main_panel.tscn")
const DataImporterScript := preload("res://addons/yukys_kits/excel_import_tools/script/data_importer.gd")

const PAGE_PREVIEW := "DataPreview"

var _main_panel: Variant
var _importer: DataImporterScript

# GameDB 是运行时 autoload，由 project.godot 静态注册（随游戏导出）。
# DataImporter 是编辑器专用实例（挂在本插件节点下，而非 autoload），
# 因此它只存在于编辑器内：不写入 project.godot、不参与导出。
#
# 导表/预览页面已在 main_panel.tscn 中实例化（TabContainer 的两个 tab），
# 整个主面板用标准方式挂载为编辑器 Dock。
func _enter_tree() -> void:
	_importer = DataImporterScript.new()
	_importer.name = "DataImporter"
	add_child(_importer)

	_main_panel = MAIN_PANEL.instantiate()
	_main_panel.set_importer(_importer)
	add_control_to_dock(DOCK_SLOT_BOTTOM, _main_panel)

	_connect_preview()

func _exit_tree() -> void:
	_disconnect_preview()
	remove_control_from_docks(_main_panel)
	if _main_panel:
		_main_panel.queue_free()
	if _importer:
		_importer.queue_free()

func _connect_preview() -> void:
	if _importer and not _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.connect(_on_preview_requested)

func _disconnect_preview() -> void:
	if _importer and _importer.preview_requested.is_connected(_on_preview_requested):
		_importer.preview_requested.disconnect(_on_preview_requested)

# 点击数据树 JSON 后：渲染预览并切到预览 tab。
func _on_preview_requested(path: String) -> void:
	if _main_panel and _main_panel.has_method("get_page"):
		var preview: Variant = _main_panel.get_page(PAGE_PREVIEW)
		if preview and preview.has_method("show_preview"):
			preview.show_preview(path)
		if _main_panel.has_method("show_page"):
			_main_panel.show_page(PAGE_PREVIEW)
