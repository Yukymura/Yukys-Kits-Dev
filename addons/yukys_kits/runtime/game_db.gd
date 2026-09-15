# ================================================================================
# GameDB —— 游戏内数据访问（autoload，仅运行时）
#
# 数据访问：
#   GameDB.get_table_names()   -> Array[String]          所有数据表名（已排序）
#   GameDB.get_table("表名")   -> { id: { 字段: 值, ... }, ... }
#   GameDB.get_row("表名", id) -> { 字段: 值, ... }
#
# 资源加载（从资源库加载外部导入资源）：
#   GameDB.get_resource_dir()      -> String      资源库目录
#   GameDB.resolve_resource_path() -> String      把相对路径解析成资源库下的完整路径
#   GameDB.load_sprite(path)       -> Texture2D   加载图片
#   GameDB.load_audio(path)        -> AudioStream 加载音频
#   GameDB.load_resource(path)     -> Resource    加载 Godot 资源（.tres/.res/.tscn 等）
#   GameDB.clear_resource_cache()                 清空资源缓存
#
# 运行时不依赖编辑器的 DataImporter/config/log，从 ProjectSettings 读取数据库与
# 资源库路径后加载 JSON / 资源。
#
# 「导出后 res:// 路径变化找不到资源」的解法：
#   编辑器里 res:// 指向项目根目录；导出后 res:// 指向 .pck。资源库里的外部资源
#   若按「保留文件」方式导出到 exe 旁（而非打进 pck），res:// 路径就会失效。因此
#   加载按「资源加载器 → 全局化路径 → exe 相对路径」依次回退，并缓存结果（性能）。
# ================================================================================

extends Node

const JsonData := preload("res://addons/yukys_kits/runtime/json_data_tool.gd")

# 资源库支持的扩展名分类（与编辑器 ResourcePreviewDock 的分类一致）。
const IMAGE_EXTS: Array = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx"]
const AUDIO_EXTS: Array = ["wav", "ogg", "mp3", "flac", "aac"]
const GODOT_EXTS: Array = ["tres", "res", "tscn", "gdshader", "gd", "cs"]

var _data: Dictionary = {}
# 资源缓存：resolved_path -> 已加载资源（Texture2D / AudioStream / 其它 Resource）。
var _resource_cache: Dictionary = {}

func _ready() -> void:
	# 数据库路径取自 ProjectSettings（编辑器侧 DataImporter 在用户设置导出路径时写入），
	# 不再写死；缺省 res://data。
	var data_dir: String = ProjectSettings.get_setting(JsonData.SETTING_DATA_DIR, JsonData.DEFAULT_DATA_DIR)
	_data = JsonData.load_all(data_dir)

# ================================================================================
# 数据表访问

# 所有数据表名（已排序），供下拉列表等场景枚举。
func get_table_names() -> Array:
	var names: Array = _data.keys()
	names.sort()
	return names

func get_table(table_name: String) -> Dictionary:
	return _data.get(table_name, {})

func get_row(table_name: String, id) -> Dictionary:
	var table: Dictionary = get_table(table_name)
	return table.get(id, {})

# ================================================================================
# 资源库路径

# 资源库目录（取自 ProjectSettings，键 JsonData.SETTING_RESOURCE_DIR，缺省 res://res）。
# 编辑器侧 DataImporter 在用户设置资源库路径时同步写入，运行时跟随配置、不写死。
func get_resource_dir() -> String:
	return ProjectSettings.get_setting(JsonData.SETTING_RESOURCE_DIR, JsonData.DEFAULT_RESOURCE_DIR)

# 把传入路径解析成资源库下的完整路径：
#   - 相对路径（"pic/啤酒.png"）→ 拼上资源库目录；
#   - res:// / user:// / 绝对路径 → 原样返回。
func resolve_resource_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return get_resource_dir().trim_suffix("/").path_join(path)

# ================================================================================
# 资源库枚举

# 资源分类：image（图片）/ audio（音频）/ godot（Godot 资源）/ ""（其它）。
func get_resource_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in IMAGE_EXTS:
		return "image"
	if ext in AUDIO_EXTS:
		return "audio"
	if ext in GODOT_EXTS:
		return "godot"
	return ""

# 路径是否为资源库支持的资源文件（图片/音频/Godot 资源）。
func is_resource_file(path: String) -> bool:
	return get_resource_type(path) != ""

# 列出资源库下所有受支持的资源文件（返回相对资源库目录的路径，已排序）。
func list_resource_files() -> Array[String]:
	var out: Array[String] = []
	_collect_resource_files(get_resource_dir(), "", out)
	out.sort()
	return out

# ================================================================================
# 资源加载

# 加载图片（返回 Texture2D）。path 支持相对资源库路径或完整 res:// 路径，已加载走缓存。
func load_sprite(path: String) -> Texture2D:
	return _load(path) as Texture2D

# 加载音频（返回 AudioStream）。path 同 load_sprite。
func load_audio(path: String) -> AudioStream:
	return _load(path) as AudioStream

# 加载 Godot 资源（.tres/.res/.tscn/.gdshader 等）。path 同 load_sprite。
func load_resource(path: String) -> Resource:
	return _load(path) as Resource

# 清空资源缓存（需要重新加载资源或主动释放内存时调用）。
func clear_resource_cache() -> void:
	_resource_cache.clear()

# ================================================================================
# 内部

func _load(path: String) -> Resource:
	var full := resolve_resource_path(path)
	if full.is_empty():
		return null
	if _resource_cache.has(full):
		return _resource_cache[full]
	var res := _load_internal(full)
	if res != null:
		_resource_cache[full] = res
	return res

func _load_internal(full: String) -> Resource:
	# 1) 优先走 Godot 资源加载器（编辑器内、或已按导入方式打进 pck 的资源）。
	if ResourceLoader.exists(full):
		return ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_REUSE)
	# 2) 导出后 res:// 指向 pck，资源库外部文件回退到文件系统：按「全局化路径 →
	#    exe 相对路径」依次尝试，命中后按扩展名直接读文件。
	for os_path in _filesystem_candidates(full):
		if not FileAccess.file_exists(os_path):
			continue
		return _load_from_file(os_path)
	return null

# 候选文件系统路径（依次尝试）。导出后 res:// 内容若以「保留文件」方式放在 exe 旁，
# globalize_path 通常给出 exe 相对路径；这里再兜底 exe 目录 + res:// 相对部分。
func _filesystem_candidates(full: String) -> Array:
	var out: Array = []
	var global := ProjectSettings.globalize_path(full)
	if not global.is_empty() and not global.begins_with("res://") and not global.begins_with("user://"):
		out.append(global)
	if full.begins_with("res://"):
		out.append(OS.get_executable_path().get_base_dir().path_join(full.trim_prefix("res://")))
	return out

# 递归收集资源库目录下的受支持资源文件，写入 out（相对资源库目录的路径）。
func _collect_resource_files(dir_path: String, rel: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		var full := dir_path.path_join(item)
		var rel_full := rel.path_join(item)
		if dir.current_is_dir():
			_collect_resource_files(full, rel_full, out)
		elif is_resource_file(full):
			out.append(rel_full)
		item = dir.get_next()
	dir.list_dir_end()

# 从文件系统直接加载外部资源文件（未走 Godot 导入），按资源分类分发。
func _load_from_file(os_path: String) -> Resource:
	match get_resource_type(os_path):
		"image":
			return _load_image_file(os_path)
		"audio":
			return _load_audio_file(os_path)
		"godot":
			# .tres/.res 等：尝试用 ResourceLoader 按文件系统路径加载。
			if ResourceLoader.exists(os_path):
				return ResourceLoader.load(os_path, "", ResourceLoader.CACHE_MODE_REUSE)
	return null

func _load_image_file(os_path: String) -> Texture2D:
	# Image.load_from_file 为静态方法，返回 Image 或 null（失败时）。
	var img := Image.load_from_file(os_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

func _load_audio_file(os_path: String) -> AudioStream:
	# AudioStream 各子类的 load_from_file 均为静态方法，返回资源或 null（失败时）。
	match os_path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(os_path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(os_path)
		"mp3":
			return AudioStreamMP3.load_from_file(os_path)
		# flac/aac 无独立加载类，交给通用 ResourceLoader 兜底。
		_:
			if ResourceLoader.exists(os_path):
				return ResourceLoader.load(os_path, "", ResourceLoader.CACHE_MODE_REUSE)
	return null

# ================================================================================
