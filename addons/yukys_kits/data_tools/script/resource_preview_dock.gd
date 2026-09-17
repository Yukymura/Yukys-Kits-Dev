# ================================================================================
# ResourcePreviewDock —— 资源库预览面板（编辑器）
#
# 参照数据预览（PreviewDock）：
#   - 中部：资源文件树，不同种类资源用不同背景颜色区分（配色可在「设置」页配置）：
#       图片 / 音频 / Godot 资源。
#   - 点击文件：场景用场景编辑器、脚本用脚本编辑器；图片/音频/Godot 资源用
#     Inspector 打开（图片/音频显示预览）。
#   - 文件图标与文件系统 Dock 对齐（按资源类型取编辑器主题图标）。
#   - 资源库路径在「设置」页配置，路径变更时自动刷新文件树。
#   - 定时监听目录变更，自动刷新文件树。
# ================================================================================

@tool
extends Control

const IMAGE_EXTS: Array = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx"]
const AUDIO_EXTS: Array = ["wav", "ogg", "mp3", "flac", "aac"]
const GODOT_EXTS: Array = ["tres", "res", "tscn", "gdshader", "gd", "cs"]

@onready var path_label: Label = $Scroll/VBox/Header/PathLabel
@onready var resource_tree: Tree = $Scroll/VBox/ResourceTree
@onready var search_button: Button = $Scroll/VBox/SearchBar/SearchButton
@onready var whole_word_check: CheckBox = $Scroll/VBox/SearchBar/WholeWordCheck
@onready var case_sensitive_check: CheckBox = $Scroll/VBox/SearchBar/CaseSensitiveCheck
@onready var result_tree: Tree = $Scroll/VBox/ResultTree
@onready var result_header: Label = $Scroll/VBox/ResultHeader

var _watch_timer: Timer
var _dir_snapshot: Dictionary = {}
var _importer: Variant
# 图片缩略图（与文件系统 Dock 一致）——异步回调时用代际号避免错位刷新到旧 item。
var _preview_gen: int = 0
var _preview_items: Dictionary = {}  # full_path -> TreeItem

func set_importer(importer) -> void:
	_importer = importer
	if is_node_ready():
		_connect_importer_signals()
		_refresh_resource_path()

func _ready() -> void:
	_setup()
	_connect_signals()
	_connect_importer_signals()
	_refresh_resource_path()

func _setup() -> void:
	_watch_timer = Timer.new()
	_watch_timer.wait_time = 1.0
	_watch_timer.autostart = true
	_watch_timer.timeout.connect(_on_watch_timeout)
	add_child(_watch_timer)
	_setup_result_tree()

func _setup_result_tree() -> void:
	# 搜索结果看板：3 列（文件 / 引用位置 / 路径），隐藏根节点。
	result_tree.hide_root = true
	result_tree.allow_reselect = true
	result_tree.column_titles_visible = true
	result_tree.columns = 3
	result_tree.set_column_title(0, "文件")
	result_tree.set_column_title(1, "引用")
	result_tree.set_column_title(2, "路径")
	result_tree.set_column_expand(0, true)
	result_tree.set_column_expand(1, true)
	result_tree.set_column_expand(2, true)
	# 未搜索时隐藏「搜索结果」标题与表格，搜索后再显示。
	_set_results_visible(false)

func _set_results_visible(v: bool) -> void:
	result_header.visible = v
	result_tree.visible = v

func _connect_signals() -> void:
	resource_tree.item_selected.connect(_on_tree_item_selected)
	resource_tree.item_activated.connect(_on_tree_item_activated)
	search_button.pressed.connect(_search_references)
	whole_word_check.toggled.connect(_on_search_option_changed)
	case_sensitive_check.toggled.connect(_on_search_option_changed)
	result_tree.item_selected.connect(_on_result_item_selected)

func _connect_importer_signals() -> void:
	if _importer == null:
		return
	if not _importer.resource_path_changed.is_connected(_refresh_resource_path):
		_importer.resource_path_changed.connect(_refresh_resource_path)
	# 配色变化时重建文件树，让新颜色立即生效。
	if not _importer.resource_colors_changed.is_connected(_refresh_tree):
		_importer.resource_colors_changed.connect(_refresh_tree)

# ================================================================================
# 文件树

func _refresh_resource_path() -> void:
	if _importer == null:
		return
	_refresh_tree()

func _refresh_tree() -> void:
	var path: String = _importer.get_resource_path()
	_load_tree(path)
	_dir_snapshot = _dir_signature(path)

func _load_tree(path: String) -> void:
	resource_tree.clear()
	_preview_gen += 1
	_preview_items.clear()
	if path.is_empty():
		return
	var root := resource_tree.create_item()
	# 树根直接显示完整配置路径（如 res://res），与「设置」页 / config.json 的
	# resource_path 保持一致，避免只显示 basename（"res"）被误读为项目根目录。
	root.set_text(0, path)
	_populate(root, path)

func _populate(parent: TreeItem, dir_path: String) -> void:
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
		if dir.current_is_dir():
			var folder_item := resource_tree.create_item(parent)
			folder_item.set_text(0, item)
			folder_item.set_icon(0, get_theme_icon("folder", "FileDialog"))
			_populate(folder_item, full)
		else:
			var ext := item.get_extension().to_lower()
			if _is_supported(ext):
				var file_item := resource_tree.create_item(parent)
				file_item.set_text(0, item)
				file_item.set_icon(0, _icon_for(full, ext))
				# 图片：文件系统 Dock 显示的是缩略图而非类型图标，这里同样异步取缩略图。
				if ext in IMAGE_EXTS:
					_preview_items[full] = file_item
					EditorInterface.get_resource_previewer().queue_resource_preview(
						full, self, "_on_preview_ready", {"gen": _preview_gen})
				file_item.set_meta("full_path", full)
				file_item.set_custom_bg_color(0, _color_for(ext))
		item = dir.get_next()
	dir.list_dir_end()

# ================================================================================
# 分类

func _is_supported(ext: String) -> bool:
	return ext in IMAGE_EXTS or ext in AUDIO_EXTS or ext in GODOT_EXTS

func _color_for(ext: String) -> Color:
	# 分类背景色改由 DataImporter 提供（可在「设置」页配置并持久化到 config.json）。
	if ext in IMAGE_EXTS:
		return _importer.get_resource_color("image")
	if ext in AUDIO_EXTS:
		return _importer.get_resource_color("audio")
	return _importer.get_resource_color("godot")

func _icon_for(full: String, ext: String) -> Texture2D:
	# 与文件系统 Dock 对齐：按资源类型（get_file_type）取编辑器主题图标。
	# get_file_type 返回具体类型（如 AudioStreamMP3、CompressedTexture2D、Theme）；
	# 若该类型没有独立图标（如 Resource），沿继承链回退到基类图标，与 FileSystemDock 一致。
	var type := EditorInterface.get_resource_filesystem().get_file_type(full)
	if type.is_empty():
		type = _type_for_ext(ext)
	return _editor_icon(type)

func _editor_icon(type: String) -> Texture2D:
	var editor_theme := EditorInterface.get_editor_theme()
	var cls := type
	while not cls.is_empty():
		if editor_theme.has_icon(cls, "EditorIcons"):
			return editor_theme.get_icon(cls, "EditorIcons")
		cls = ClassDB.get_parent_class(cls)
	# 兜底：通用文件图标。
	return get_theme_icon("file", "FileDialog")

func _type_for_ext(ext: String) -> String:
	match ext:
		"png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx":
			return "Texture2D"
		"wav", "ogg", "mp3", "flac", "aac":
			return "AudioStream"
		"tscn":
			return "PackedScene"
		"gd":
			return "GDScript"
		"cs":
			return "CSharpScript"
		"gdshader":
			return "Shader"
		"tres", "res":
			return "Resource"
	return ""

# 图片缩略图异步回调：由 EditorResourcePreview 触发，与文件系统 Dock 共用预览缓存。
func _on_preview_ready(path: String, _preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	if thumbnail == null:
		return
	# 代际校验：树重建后旧回调失效，避免把缩略图写到已清空的旧 item。
	if int(userdata.get("gen", -1)) != _preview_gen:
		return
	var item: TreeItem = _preview_items.get(path)
	if item != null:
		item.set_icon(0, thumbnail)

# ================================================================================
# 文件监听（资源库目录变更时自动刷新文件树）

func _on_watch_timeout() -> void:
	if _importer == null:
		return
	var path: String = _importer.get_resource_path()
	var sig := _dir_signature(path)
	if sig != _dir_snapshot:
		_dir_snapshot = sig
		_refresh_tree()

func _dir_signature(path: String) -> Dictionary:
	var sig: Dictionary = {}
	_scan_dir(path, sig)
	return sig

func _scan_dir(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		var full := path.path_join(item)
		if dir.current_is_dir():
			out[full] = "dir"
			_scan_dir(full, out)
		else:
			out[full] = FileAccess.get_modified_time(full)
		item = dir.get_next()
	dir.list_dir_end()

# ================================================================================
# 点击资源 → 跳转 / 打开 Godot 自身对应界面
#
# 单击仅选中并刷新路径标签；Godot 资源（场景/脚本/tres/着色器等）的跳转会切换
# 底部面板（场景编辑器/脚本编辑器/Inspector），改为双击才触发。图片/音频的预览
# 不切换主面板，保留单击即时预览。

func _on_tree_item_selected() -> void:
	var item := resource_tree.get_selected()
	if item == null:
		return
	var path: String = item.get_meta("full_path", "")
	if path.is_empty():
		return
	path_label.text = path
	# Godot 资源：仅选中，双击再跳转；图片/音频：单击即预览。
	if path.get_extension().to_lower() in GODOT_EXTS:
		return
	_open_resource(path)

func _on_tree_item_activated() -> void:
	var item := resource_tree.get_selected()
	if item == null:
		return
	var path: String = item.get_meta("full_path", "")
	if path.is_empty():
		return
	path_label.text = path
	_open_resource(path)

func _open_resource(path: String) -> void:
	if not Engine.is_editor_hint():
		return
	var ext := path.get_extension().to_lower()
	# 场景：用场景编辑器打开
	if ext == "tscn":
		EditorInterface.open_scene_from_path(path)
		return
	# 脚本：用脚本编辑器打开
	if ext == "gd" or ext == "cs":
		var s = load(path)
		if s is Script:
			EditorInterface.edit_script(s)
			return
	# 图片 / 音频 / Godot 资源（主题/样式/着色器等）：
	# 在 Inspector 打开对应资源，图片与音频会显示预览（缩略图 / 音频播放器）。
	var res = load(path)
	if res != null:
		EditorInterface.edit_resource(res)
		return
	# 兜底（无法 load 的资源）：跳转到文件系统 Dock 并选中
	_navigate_to_path(path)

func _navigate_to_path(path: String) -> void:
	var fs := EditorInterface.get_file_system_dock()
	if fs:
		fs.navigate_to_path(path)

# ================================================================================
# 搜索引用 —— 在数据库中搜索当前选中资源被哪些数据项引用。
# 搜索词为资源的相对路径（相对资源库）与完整 res:// 路径；「全字」= 整值相等，
# 「区分大小写」= 大小写敏感。结果以 列表（文件 / 引用位置 / 路径）显示在看板中。

func _selected_resource_path() -> String:
	var item := resource_tree.get_selected()
	if item == null:
		return ""
	return str(item.get_meta("full_path", ""))

func _on_search_option_changed(_v: bool) -> void:
	# 开关变化时若已有搜索结果，实时重搜。
	if result_tree.get_root() != null:
		_search_references()

func _search_references() -> void:
	var full := _selected_resource_path()
	_clear_results()
	if full.is_empty():
		_set_results_visible(false)
		return
	var terms := _search_terms(full)
	if terms.is_empty():
		_set_results_visible(false)
		return
	var whole := whole_word_check.button_pressed
	var case_sensitive := case_sensitive_check.button_pressed
	var results: Array = []
	for json_path in _collect_json_files(_importer.get_export_path()):
		var r = _importer.load_data_file(json_path)
		if not r.get("ok", false):
			continue
		var rows: Dictionary = r.get("data", {}).get("data", {})
		for id in rows:
			var row: Dictionary = rows[id]
			for field in row:
				var value = row[field]
				if value is String and _value_matches(value, terms, whole, case_sensitive):
					results.append({
						"file": json_path,
						"id": str(id),
						"field": str(field),
					})
	_display_results(results)

# 相对资源库路径 + 完整路径（去重），作为搜索词。
func _search_terms(full: String) -> Array:
	var lib := String(_importer.get_resource_path()).trim_suffix("/") + "/"
	var rel := full
	if full.begins_with(lib):
		rel = full.trim_prefix(lib)
	var out: Array = []
	for term in [rel, full]:
		if not out.has(term):
			out.append(term)
	return out

func _value_matches(value: String, terms: Array, whole: bool, case_sensitive: bool) -> bool:
	var hay: String = value.to_lower() if not case_sensitive else value
	for term in terms:
		var needle: String = str(term).to_lower() if not case_sensitive else str(term)
		if whole:
			if hay == needle:
				return true
		elif hay.contains(needle):
			return true
	return false

# 递归收集导出目录下所有 .json（数据库数据文件）。
func _collect_json_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	_collect_json_recursive(dir_path, out)
	return out

func _collect_json_recursive(dir_path: String, out: Array[String]) -> void:
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
		if dir.current_is_dir():
			_collect_json_recursive(full, out)
		elif full.get_extension().to_lower() == "json":
			out.append(full)
		item = dir.get_next()
	dir.list_dir_end()

func _clear_results() -> void:
	result_tree.clear()

func _display_results(results: Array) -> void:
	_set_results_visible(true)
	var root := result_tree.create_item()
	if results.is_empty():
		var empty := result_tree.create_item(root)
		empty.set_text(0, "未找到引用")
		empty.set_icon(0, get_theme_icon("file", "FileDialog"))
		return
	for res in results:
		var json_path: String = res["file"]
		var item := result_tree.create_item(root)
		item.set_icon(0, get_theme_icon("file", "FileDialog"))
		item.set_text(0, json_path.get_file())
		item.set_text(1, str(res["id"]) + "." + str(res["field"]))
		item.set_text(2, json_path)
		# 记录跳转目标：数据文件路径 + 数据项 key。
		item.set_meta("_file", json_path)
		item.set_meta("_key", str(res["id"]))

# 点击搜索结果 → 请求跳转到数据库页并选中对应文件与数据项。
func _on_result_item_selected() -> void:
	if _importer == null:
		return
	# 「关联数据跳转」设置项关闭时不跳转。
	if not bool(_importer.get_setting("resource_data_linked")):
		return
	var item := result_tree.get_selected()
	if item == null:
		return
	var file: String = str(item.get_meta("_file", ""))
	if file.is_empty():
		return
	var key: String = str(item.get_meta("_key", ""))
	_importer.request_navigate_data_item(file, key)

# ================================================================================
# 跳转：从数据预览点击资源路径后，选中资源库中对应文件并滚动到可见。
# path 为资源库下的完整 res:// 路径（与文件树 item 的 full_path 一致）。

func select_resource(path: String) -> void:
	var target := path.simplify_path()
	if target.is_empty():
		return
	var item := _find_item_by_path(resource_tree.get_root(), target)
	if item == null:
		return
	# 展开所有祖先文件夹，让目标项可见
	var p := item.get_parent()
	while p != null:
		p.set_collapsed(false)
		p = p.get_parent()
	item.select(0)
	resource_tree.scroll_to_item(item, true)

func _find_item_by_path(item: TreeItem, target: String) -> TreeItem:
	if item == null:
		return null
	var meta: String = str(item.get_meta("full_path", ""))
	if not meta.is_empty() and meta.simplify_path() == target:
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _find_item_by_path(child, target)
		if found != null:
			return found
		child = child.get_next()
	return null

# ================================================================================
