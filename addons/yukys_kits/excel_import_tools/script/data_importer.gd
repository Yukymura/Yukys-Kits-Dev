# ================================================================================
# DataImporter —— 导表工具（编辑器专用实例，由 plugin.gd 创建并注入 dock/preview）
#
# 职责：
#   - 读取/保存 config.json（导出路径、日志路径）。
#   - 提供 CSV → JSON 的导表流程。
#   - 提供预览所需的单文件读取 load_data_file() 与 CSV 解析 read_table()。
#
# 注：运行时加载全部数据的能力已移交 GameDB（见 runtime/game_db.gd），
#     本单例仅供编辑器使用，不参与导出。
# ================================================================================

@tool
extends Node

signal export_path_changed
signal files_changed
signal preview_requested(path)
signal resource_path_changed

const CONFIG_PATH := "res://addons/yukys_kits/excel_import_tools/config.json"

const CsvParser := preload("res://addons/yukys_kits/excel_import_tools/tool/csv_parser.gd")
const JsonData := preload("res://addons/yukys_kits/runtime/json_data_tool.gd")
const Config := preload("res://addons/yukys_kits/excel_import_tools/tool/config_tool.gd")
const Log := preload("res://addons/yukys_kits/excel_import_tools/tool/logger.gd")

var export_path: String = "res://data":
	set(v):
		export_path = v
		export_path_changed.emit()

var log_path: String = ""

# 资源库目录（编辑器专用，供 ResourcePreviewDock 浏览图片/音频/Godot 资源）。
var resource_path: String = "res://assets":
	set(v):
		resource_path = v
		resource_path_changed.emit()

func _ready() -> void:
	var cfg := Config.load_config(CONFIG_PATH)
	if cfg.ok:
		var data: Dictionary = cfg.data
		export_path = data.get("export_path", JsonData.DEFAULT_DATA_DIR)
		log_path = data.get("log_path", "")
		resource_path = data.get("resource_path", "res://assets")
	_sync_data_dir_setting()
	Log.set_log_path(log_path)
	Log.info("DataImporter 初始化完成，导出路径: %s" % export_path)

# ================================================================================
# 导表

# 返回 { ok: bool, message: String }
func import_csv(csv_path: String, output_dir: String) -> Dictionary:
	if csv_path.is_empty():
		var m := "未指定 CSV 文件"
		Log.error("导表失败: " + m)
		return {"ok": false, "message": m}
	if output_dir.is_empty():
		var m := "未指定导出路径"
		Log.error("导表失败: " + m)
		return {"ok": false, "message": m}

	Log.info("开始导表: %s -> %s" % [csv_path, output_dir])

	var r := CsvParser.read_csv(csv_path)
	if not r.ok:
		Log.error("导表失败: %s" % r.error)
		return {"ok": false, "message": str(r.error)}

	var csv_data: Dictionary = r.data
	var table_name: String = csv_data["header"]
	var out_path := output_dir.trim_suffix("/").path_join(table_name + ".json")

	var w := JsonData.create_json(out_path, csv_path, csv_data)
	if not w.ok:
		Log.error("导表失败: %s" % w.error)
		return {"ok": false, "message": str(w.error)}

	_refresh_filesystem(out_path)
	var msg := "导表成功: %s（%d 行）" % [out_path, (csv_data["values"] as Array).size()]
	Log.done(msg)
	return {"ok": true, "message": msg}

# ================================================================================
# 数据访问

func get_export_path() -> String:
	return export_path

func set_export_path(path: String) -> void:
	export_path = path
	_save_config()
	_sync_data_dir_setting()

func get_resource_path() -> String:
	return resource_path

func set_resource_path(path: String) -> void:
	resource_path = path
	_save_config()

func load_data_file(path: String) -> Dictionary:
	return JsonData.load_file(path)

# 解析 CSV，返回 { ok, data: { header, keys, types, values } / error }。
# 供导表面板在选中导入文件后预览单表数据（真实字段名）。
func read_table(csv_path: String) -> Dictionary:
	return CsvParser.read_csv(csv_path)

# 导出目录下是否已存在同名 JSON（供导表面板显示「已存在同名 json」提示）。
func table_exists(output_dir: String, table_name: String) -> bool:
	if output_dir.is_empty() or table_name.is_empty():
		return false
	var p := output_dir.trim_suffix("/").path_join(table_name + ".json")
	return FileAccess.file_exists(p)

func request_preview(path: String) -> void:
	preview_requested.emit(path)

# ================================================================================
# 内部

# 把导出路径同步到 ProjectSettings（键 JsonData.SETTING_DATA_DIR），供运行时 GameDB 读取。
# 值变化时才写，并落盘 project.godot，保证导出后的游戏也能读到同一路径。
func _sync_data_dir_setting() -> void:
	if ProjectSettings.get_setting(JsonData.SETTING_DATA_DIR, "") == export_path:
		return
	ProjectSettings.set_setting(JsonData.SETTING_DATA_DIR, export_path)
	if Engine.is_editor_hint():
		ProjectSettings.save()

func _save_config() -> void:
	# 合并写入：先读旧配置，再只更新 export_path/log_path，
	# 避免覆盖掉 config.json 里的其它字段（dock_name、panel_names 等）。
	var cfg := Config.load_config(CONFIG_PATH)
	var data: Dictionary = cfg.data if cfg.ok else {}
	data["export_path"] = export_path
	data["log_path"] = log_path
	data["resource_path"] = resource_path
	Config.save_config(CONFIG_PATH, data)

func _refresh_filesystem(path: String) -> void:
	files_changed.emit()
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.update_file(path)
		fs.scan()

# ================================================================================
