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
const SETTING_CONFIG_PATH := "res://addons/yukys_kits/data_tools/datas/setting_config.json"

# 「设置项配置表」type 字段取值（与 setting_item.gd 的 TYPE_* 常量一致）。
# 默认值转换只需区分 bool / Color / 其余（String），故这里只定义用到的两个。
const TYPE_CHECKBOX := 1
const TYPE_COLOR := 5

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
# 字段名与「设置项配置表」的 data_name 对齐（pic_bg_color / audio_bg_color / res_bg_color），
# 直接作为 config.json 顶层字段持久化。默认值：图片蓝 / 音频绿 / Godot 资源橙。
var pic_bg_color: Color = Color(0.27, 0.52, 1.0, 0.25)     # 图片 —— 蓝
var audio_bg_color: Color = Color(0.22, 0.80, 0.45, 0.25)  # 音频 —— 绿
var res_bg_color: Color = Color(1.0, 0.66, 0.22, 0.25)     # Godot 资源 —— 橙

# 设置项默认值（data_name -> 已按类型转换的默认值），来自「设置项配置表」的 default 列。
# 两大用途：_load_settings() 里作为「用户未设置过」时的回退值；设置界面重置按钮读取。
var _setting_defaults: Dictionary = {}

# 配置在 _init() 里同步加载（而非 _ready()）。plugin.gd 在 new() 之后、把 importer
# 注入 dock 之前就完成了加载，保证 resource_path 等字段立刻是最新值——否则资源库
# 面板在启动瞬间会先读到字段默认值 "res://assets"，出现「配置是 res://res，显示却
# 是 res://assets」的竞态。
func _init() -> void:
	_load_settings()

func _ready() -> void:
	_sync_data_dir_setting()
	_sync_resource_dir_setting()
	Log.set_log_path(log_path)
	Log.info("DataImporter 初始化完成，导出路径: %s" % export_path)

func _load_settings() -> void:
	_load_setting_defaults()
	var cfg := Config.load_config(CONFIG_PATH)
	if cfg.ok:
		var data: Dictionary = cfg.data
		# 未设置过的字段回退到「设置项配置表」的默认值；配置表缺失时再回退到
		# 字段声明处的硬编码默认值。
		export_path = data.get("export_path", _setting_defaults.get("export_path", JsonData.DEFAULT_DATA_DIR))
		log_path = data.get("log_path", "")
		resource_path = data.get("resource_path", _setting_defaults.get("resource_path", "res://assets"))
		pic_bg_color = _parse_color(data.get("pic_bg_color", ""), _setting_defaults.get("pic_bg_color", pic_bg_color))
		audio_bg_color = _parse_color(data.get("audio_bg_color", ""), _setting_defaults.get("audio_bg_color", audio_bg_color))
		res_bg_color = _parse_color(data.get("res_bg_color", ""), _setting_defaults.get("res_bg_color", res_bg_color))

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
	_sync_resource_dir_setting()

# 资源库按分类（image/audio/godot）读取背景色。分类名是资源库自己的语义，
# 底层映射到「设置项配置表」的字段 pic_bg_color / audio_bg_color / res_bg_color。
func get_resource_color(category: String) -> Color:
	match category:
		"image":
			return pic_bg_color
		"audio":
			return audio_bg_color
		"godot":
			return res_bg_color
	return Color.WHITE

func set_resource_color(category: String, color: Color) -> void:
	match category:
		"image":
			pic_bg_color = color
		"audio":
			audio_bg_color = color
		"godot":
			res_bg_color = color
	_save_config()
	resource_colors_changed.emit()

# ================================================================================
# 设置项通用读写（供数据驱动的设置界面使用）
#
# 设置界面的每个配置项都由「设置项配置表」驱动，data_name 即其持久化字段名。
# 这里按 data_name 返回/接收「类型化」的值（颜色返回 Color、路径返回 String），
# 由界面控件直接消费；序列化（Color -> 十六进制）在 _save_config() 内统一处理。
# 新增设置项时：在配置表加一行，并在此处补一个 match 分支即可。
func get_setting(data_name: String) -> Variant:
	match data_name:
		"export_path":
			return export_path
		"resource_path":
			return resource_path
		"pic_bg_color":
			return pic_bg_color
		"audio_bg_color":
			return audio_bg_color
		"res_bg_color":
			return res_bg_color
	return null

func set_setting(data_name: String, value) -> void:
	match data_name:
		"export_path":
			set_export_path(value)
		"resource_path":
			set_resource_path(value)
		"pic_bg_color":
			set_resource_color("image", value)
		"audio_bg_color":
			set_resource_color("audio", value)
		"res_bg_color":
			set_resource_color("godot", value)

# 返回设置项的默认值（来自「设置项配置表」的 default 列，已按类型转换）。
# 供设置界面的「重置」按钮使用；配置表缺该字段时返回 null。
func get_setting_default(data_name: String) -> Variant:
	return _setting_defaults.get(data_name)

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

# 把资源库路径同步到 ProjectSettings（键 JsonData.SETTING_RESOURCE_DIR），供运行时
# GameDB.load_sprite/load_audio 读取。与 _sync_data_dir_setting 同理，解决「导出后
# res:// 路径变化」问题的基础：运行时经此键拿到用户配置的资源库路径，而非写死。
func _sync_resource_dir_setting() -> void:
	if ProjectSettings.get_setting(JsonData.SETTING_RESOURCE_DIR, "") == resource_path:
		return
	ProjectSettings.set_setting(JsonData.SETTING_RESOURCE_DIR, resource_path)
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
	data["pic_bg_color"] = pic_bg_color.to_html(true)
	data["audio_bg_color"] = audio_bg_color.to_html(true)
	data["res_bg_color"] = res_bg_color.to_html(true)
	data.erase("resource_colors")  # 清理旧版嵌套字段
	Config.save_config(CONFIG_PATH, data)

# config.json 里颜色存十六进制字符串（rrggbbaa，无 # 前缀），读入时转回 Color；
# 非法/缺失时回退到当前值（即字段默认值）。
func _parse_color(raw, default: Color) -> Color:
	if raw is String and not raw.is_empty():
		return Color.from_string(raw, default)
	return default

# 读取「设置项配置表」导出的 setting_config.json，把每行的 default（String）
# 按 type 转换成对应类型，缓存到 _setting_defaults（data_name -> 默认值）。
func _load_setting_defaults() -> void:
	var cfg := Config.load_config(SETTING_CONFIG_PATH)
	if not cfg.ok:
		return
	var items: Dictionary = (cfg.data as Dictionary).get("data", {})
	for _id in items:
		var item: Dictionary = items[_id]
		var data_name: String = str(item.get("data_name", ""))
		if data_name.is_empty():
			continue
		var raw: String = str(item.get("default", ""))
		var t: int = int(item.get("type", 0))
		_setting_defaults[data_name] = _convert_default(raw, t)

# 「设置项配置表」导出的 default 均为 String，按设置类型转换：
#   类型 5（颜色）-> Color；类型 1（勾选）-> bool；其余 -> String。
func _convert_default(raw: String, type: int) -> Variant:
	match type:
		TYPE_CHECKBOX:
			return raw.strip_edges().to_lower() in ["true", "1", "yes"]
		TYPE_COLOR:
			return Color.from_string(raw, Color.WHITE)
		_:
			return raw

func _refresh_filesystem(path: String) -> void:
	files_changed.emit()
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.update_file(path)
		fs.scan()

# ================================================================================
