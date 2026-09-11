# ================================================================================
# McpExportTool —— 「AI 导表」自定义 MCP 工具处理器（编辑器专用，不随游戏导出）
#
# 通过 godot_ai 的 McpToolRegistry 注册为自定义工具（注册代码在 plugin.gd），
# 让 AI 助手收到「单表导出xxx」指令时，能切换到导表页并调用现有接口
# DataImporter.import_csv() 完成导出。
#
# 处理器方法签名（McpCustomToolSpec 约定，由 custom_tool_wrapper 调用）：
#   func export_csv(params: Dictionary, ctx) -> Dictionary
#   params.csv_path    CSV 路径（res:// 或用户绝对路径），必填
#   params.output_dir  导出目录，可选（缺省用 config.json 的 export_path）
#
# 返回值遵循 dispatcher 的 MCP 信封约定：
#   成功 → { "data": { ok, message } }
#   失败 → { "status":"error", "error": { code, message } }（ErrorCodes.make）
# ================================================================================

@tool
extends RefCounted

# 通过 plugin.gd 上的静态访问器拿到当前插件实例的 importer / 主面板。
const PluginScript := preload("res://addons/yukys_kits/plugin.gd")
const ErrorCodes := preload("res://addons/godot_ai/utils/error_codes.gd")

# config.json panel_names 里「导表」页对应的节点名。
const PAGE_IMPORT := "ImportDock"


func export_csv(params: Dictionary, _ctx) -> Dictionary:
	var csv_path := str(params.get("csv_path", "")).strip_edges()
	if csv_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "未指定 CSV 路径（参数 csv_path）")

	csv_path = _resolve_path(csv_path)

	var importer = PluginScript.get_importer()
	if importer == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "导表工具未就绪（DataImporter 不存在，请确认插件已启用）")

	# 切换到导表页（与「导表」tab 对应），让用户在编辑器里看到本次导出。
	var panel = PluginScript.get_main_panel()
	if panel != null and panel.has_method("show_page"):
		panel.show_page(PAGE_IMPORT)

	# 导出目录：优先用显式传入的 output_dir，否则用 importer 当前 export_path。
	var output_dir := str(params.get("output_dir", "")).strip_edges()
	if output_dir.is_empty():
		output_dir = importer.get_export_path()

	var r: Dictionary = importer.import_csv(csv_path, output_dir)
	if not bool(r.get("ok", false)):
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, str(r.get("message", "导表失败")))
	return {"data": {"ok": true, "message": str(r.get("message", ""))}}


# 用户绝对路径 → res://；已是 res:// / user:// 则原样返回。
# import_csv 内部用 FileAccess 打开，绝对路径也能直接读；这里统一成 res://
# 让导出的 JSON 记录相对路径，避免泄露本机绝对路径。
func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	if path.is_absolute_path():
		var localized := ProjectSettings.localize_path(path)
		if not localized.is_empty() and localized != path:
			return localized
	return path
