# ================================================================================
# ResourcePreviewDock —— 资源库预览面板（编辑器）
#
# 参照数据预览（PreviewDock）：
#   - 顶部：资源库路径输入框 + 「设置」按钮（选择目录）。
#   - 中部：资源文件树，不同种类资源用不同背景颜色区分：
#       图片（蓝）/ 音频（绿）/ Godot 资源（橙）。
#   - 点击文件：场景用场景编辑器、脚本用脚本编辑器；图片/音频/Godot 资源用
#     Inspector 打开（图片/音频显示预览）。
#   - 文件图标与文件系统 Dock 对齐（按资源类型取编辑器主题图标）。
#   - 定时监听目录变更，自动刷新文件树。
# ================================================================================

@tool
extends Control

const IMAGE_EXTS: Array = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx"]
const AUDIO_EXTS: Array = ["wav", "ogg", "mp3", "flac", "aac"]
const GODOT_EXTS: Array = ["tres", "res", "tscn", "gdshader", "gd", "cs"]

const COLOR_IMAGE := Color(0.27, 0.52, 1.0, 0.25)   # 图片 —— 蓝
const COLOR_AUDIO := Color(0.22, 0.80, 0.45, 0.25)  # 音频 —— 绿
const COLOR_GODOT := Color(1.0, 0.66, 0.22, 0.25)   # Godot 资源 —— 橙

@onready var path_label: Label = $Scroll/VBox/Header/PathLabel
@onready var resource_path_edit: LineEdit = $Scroll/VBox/HBox3/ResourcePathEdit
@onready var resource_tree: Tree = $Scroll/VBox/ResourceTree
@onready var select_resource_button: Button = $Scroll/VBox/HBox3/SelectResourceButton
@onready var resource_dir_dialog: FileDialog = $ResourceDirDialog

var _watch_timer: Timer
var _dir_snapshot: Dictionary = {}
var _importer: Variant

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
	resource_path_edit.editable = false

	resource_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	resource_dir_dialog.access = FileDialog.ACCESS_RESOURCES

	_watch_timer = Timer.new()
	_watch_timer.wait_time = 1.0
	_watch_timer.autostart = true
	_watch_timer.timeout.connect(_on_watch_timeout)
	add_child(_watch_timer)

func _connect_signals() -> void:
	select_resource_button.pressed.connect(_on_select_resource_pressed)
	resource_dir_dialog.dir_selected.connect(_on_resource_dir_selected)
	resource_tree.item_selected.connect(_on_tree_item_selected)

func _connect_importer_signals() -> void:
	if _importer == null:
		return
	if not _importer.resource_path_changed.is_connected(_refresh_resource_path):
		_importer.resource_path_changed.connect(_refresh_resource_path)

# ================================================================================
# 路径 + 文件树

func _on_select_resource_pressed() -> void:
	resource_dir_dialog.popup_centered_ratio(0.6)

func _on_resource_dir_selected(path: String) -> void:
	_importer.set_resource_path(path)

func _refresh_resource_path() -> void:
	if _importer == null:
		return
	resource_path_edit.text = _importer.get_resource_path()
	_refresh_tree()

func _refresh_tree() -> void:
	var path: String = _importer.get_resource_path()
	_load_tree(path)
	_dir_snapshot = _dir_signature(path)

func _load_tree(path: String) -> void:
	resource_tree.clear()
	if path.is_empty():
		return
	var root := resource_tree.create_item()
	var root_name := path.get_file()
	root.set_text(0, root_name if not root_name.is_empty() else path)
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
				file_item.set_meta("full_path", full)
				file_item.set_custom_bg_color(0, _color_for(ext))
		item = dir.get_next()
	dir.list_dir_end()

# ================================================================================
# 分类

func _is_supported(ext: String) -> bool:
	return ext in IMAGE_EXTS or ext in AUDIO_EXTS or ext in GODOT_EXTS

func _color_for(ext: String) -> Color:
	if ext in IMAGE_EXTS:
		return COLOR_IMAGE
	if ext in AUDIO_EXTS:
		return COLOR_AUDIO
	return COLOR_GODOT

func _icon_for(full: String, ext: String) -> Texture2D:
	# 与文件系统 Dock 对齐：按资源类型取编辑器主题图标（同一套图标来源）
	var type := EditorInterface.get_resource_filesystem().get_file_type(full)
	if type.is_empty():
		type = _type_for_ext(ext)
	if type.is_empty():
		return get_theme_icon("file", "FileDialog")
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme.has_icon(type, "EditorIcons"):
		return editor_theme.get_icon(type, "EditorIcons")
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

func _on_tree_item_selected() -> void:
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
