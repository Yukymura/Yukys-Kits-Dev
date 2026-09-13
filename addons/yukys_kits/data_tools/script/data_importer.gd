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
signal resource_colors_changed

const CONFIG_PATH := "res://addons/yukys_kits/data_tools/config.json"

const CsvParser := preload("res://addons/yukys_kits/data_tools/tool/csv_parser.gd")
const JsonData := preload("res://addons/yukys_kits/runtime/json_data_tool.gd")
const Config := preload("res://addons/yukys_kits/data_tools/tool/config_tool.gd")
const Log := preload("res://addons/yukys_kits/data_tools/tool/logger.gd")

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

# 资源库分类背景色（图片/音频/Godot 资源），可在「设置」页修改并持久化到 config.json。
# resource_colors 只存用户改动过的 key -> Color；未设置的 key 回退到 DEFAULT_RESOURCE_COLORS。
const RESOURCE_COLOR_KEYS: Array = ["image", "audio", "godot"]
const DEFAULT_RESOURCE_COLORS := {
	"image": Color(0.27, 0.52, 1.0, 0.25),   # 图片 —— 蓝
	"audio": Color(0.22, 0.80, 0.45, 0.25),  # 音频 —— 绿
	"godot": Color(1.0, 0.66, 0.22, 0.25),   # Godot 资源 —— 橙
}

var resource_colors: Dictionary = {}  # key -> Color

# 配置在 _init() 里同步加载（而非 _ready()）。plugin.gd 在 new() 之后、把 importer
# 注入 dock 之前就完成了加载，保证 resource_path 等字段立刻是最新值——否则资源库
# 面板在启动瞬间会先读到字段默认值 "res://assets"，出现「配置是 res://res，显示却
# 是 res://assets」的竞态。
func _init() -> void:
	_load_settings()

func _ready() -> void:
	_sync_data_dir_setting()
	Log.set_log_path(log_path)
	Log.info("DataImporter 初始化完成，导出路径: %s" % export_path)

func _load_settings() -> void:
	var cfg := Config.load_config(CONFIG_PATH)
	if cfg.ok:
		var data: Dictionary = cfg.data
		export_path = data.get("export_path", JsonData.DEFAULT_DATA_DIR)
		log_path = data.get("log_path", "")
		resource_path = data.get("resource_path", "res://assets")
		resource_colors = _parse_resource_colors(data.get("resource_colors", {}))

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

func get_resource_color(key: String) -> Color:
	if resource_colors.has(key):
		return resource_colors[key]
	return DEFAULT_RESOURCE_COLORS.get(key, Color.WHITE)

func set_resource_color(key: String, color: Color) -> void:
	resource_colors[key] = color
	_save_config()
	resource_colors_changed.emit()

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
	data["resource_colors"] = _serialize_resource_colors()
	Config.save_config(CONFIG_PATH, data)

# config.json 里存十六进制颜色字符串（#rrggbbaa），读入时转回 Color；非法/缺失回退默认色。
func _parse_resource_colors(raw) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for key in RESOURCE_COLOR_KEYS:
		var v = raw.get(key, "")
		if v is String and not v.is_empty():
			out[key] = Color.from_string(v, DEFAULT_RESOURCE_COLORS[key])
	return out

func _serialize_resource_colors() -> Dictionary:
	var out: Dictionary = {}
	for key in resource_colors:
		out[key] = (resource_colors[key] as Color).to_html(true)
	return out

func _refresh_filesystem(path: String) -> void:
	files_changed.emit()
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.update_file(path)
		fs.scan()

# ================================================================================
