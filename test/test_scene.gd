# ================================================================================
# TestScene —— 插件正确性测试场景（位于游戏目录，非插件目录）
#
# 仅通过插件暴露的接口 GameDB（autoload）访问导表数据与资源库，不调用任何插件内部接口：
#   - GameDB.get_table_names()  -> Array[String]      所有数据表名
#   - GameDB.get_table(name)    -> { id: {字段:值}, ... }
#   - GameDB.get_row(name, id)  -> {字段:值}
#   - GameDB.get_resource_dir() -> String             资源库目录
#   - GameDB.list_resource_files() -> Array           资源库下所有资源文件（相对路径）
#   - GameDB.get_resource_type(path) -> String        资源分类：image/audio/godot/""
#   - GameDB.load_sprite(path)  -> Texture2D          从资源库加载图片
#   - GameDB.load_audio(path)   -> AudioStream        从资源库加载音频
#   - GameDB.load_resource(path)-> Resource           从资源库加载 Godot 资源
#   - GameDB.resolve_resource_path(path) / clear_resource_cache()
#
# 页面：
#   「数据」tab：下拉列表列出所有数据表，选中后展示整张表；key 搜索框过滤数据行。
#   「资源」tab：资源文件树（图片/音频/Godot 资源按分类着色），选中后加载并预览。
# ================================================================================

extends Control

# 数据页
@onready var tabs: TabContainer = $Margin/Tabs
@onready var table_selector: OptionButton = $Margin/Tabs/DataTab/TableRow/TableSelector
@onready var search_box: LineEdit = $Margin/Tabs/DataTab/SearchRow/SearchBox
@onready var clear_button: Button = $Margin/Tabs/DataTab/SearchRow/ClearButton
@onready var status_label: Label = $Margin/Tabs/DataTab/StatusLabel
@onready var data_tree: Tree = $Margin/Tabs/DataTab/DataTree

# 资源页
@onready var res_title: Label = $Margin/Tabs/ResourceTab/ResHeader/ResTitle
@onready var clear_cache_button: Button = $Margin/Tabs/ResourceTab/ResHeader/ClearCacheButton
@onready var resource_tree: Tree = $Margin/Tabs/ResourceTab/ResourceTree
@onready var sprite_preview: TextureRect = $Margin/Tabs/ResourceTab/ResResultRow/SpritePreview
@onready var resource_status: Label = $Margin/Tabs/ResourceTab/ResResultRow/ResourceStatus
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

func _ready() -> void:
	tabs.set_tab_title(0, "数据")
	tabs.set_tab_title(1, "资源")

	table_selector.item_selected.connect(_on_table_selected)
	search_box.text_changed.connect(_on_search_changed)
	clear_button.pressed.connect(_on_clear_pressed)

	resource_tree.item_selected.connect(_on_resource_selected)
	clear_cache_button.pressed.connect(_on_clear_cache_pressed)

	res_title.text = "资源库：%s" % GameDB.get_resource_dir()

	_populate_tables()
	_refresh()
	_populate_resources()

# ================================================================================
# 数据页

# 把所有数据表填入下拉列表
func _populate_tables() -> void:
	table_selector.clear()
	for table_name in GameDB.get_table_names():
		table_selector.add_item(table_name)
	if table_selector.item_count > 0:
		table_selector.select(0)

func _current_table() -> String:
	if table_selector.item_count == 0:
		return ""
	return table_selector.get_item_text(table_selector.selected)

func _on_table_selected(_index: int) -> void:
	_refresh()

func _on_search_changed(_text: String) -> void:
	_refresh()

func _on_clear_pressed() -> void:
	search_box.clear()
	_refresh()

# 重绘数据表格：列 = key + 各字段，行 = 各数据行（可按 key 过滤）
func _refresh() -> void:
	data_tree.clear()

	var table_name := _current_table()
	if table_name.is_empty():
		status_label.text = "暂无数据表（请先在导表工具中导出数据）"
		return

	var table: Dictionary = GameDB.get_table(table_name)
	var keyword := search_box.text.strip_edges()

	# 字段名按 CSV 顺序取所有行的并集（各行列名一致）
	var fields: Array = []
	for id in table:
		for field in table[id]:
			if not fields.has(field):
				fields.append(field)

	# 列：key + 各字段
	data_tree.columns = fields.size() + 1
	data_tree.set_column_titles_visible(true)
	data_tree.set_column_title(0, "key")
	for i in range(fields.size()):
		data_tree.set_column_title(i + 1, str(fields[i]))

	# 显式创建一个隐藏根节点，数据行作为其子节点。
	# 注意：Godot 4.7 里 `create_item()`（不传父节点）会把首个 item 错当成根，
	# 导致第一行数据丢失，因此必须显式指定父节点。
	var root: TreeItem = data_tree.create_item()

	var ids: Array = table.keys()
	ids.sort_custom(_compare_ids)

	var shown := 0
	for id in ids:
		if not keyword.is_empty() and not str(id).contains(keyword):
			continue
		var row: Dictionary = table[id]
		var item: TreeItem = data_tree.create_item(root)
		item.set_text(0, str(id))
		for i in range(fields.size()):
			item.set_text(i + 1, _format_value(row.get(fields[i], "")))
		shown += 1

	if keyword.is_empty():
		status_label.text = "表 %s · 共 %d 行" % [table_name, shown]
	else:
		status_label.text = "表 %s · 匹配 %d / %d 行（key 包含 \"%s\"）" % [table_name, shown, ids.size(), keyword]

func _format_value(value) -> String:
	return str(value)

# id 按数值比较（整数）或字符串比较，保证 1, 2, 10 而非 1, 10, 2
func _compare_ids(a, b) -> bool:
	if a is int and b is int:
		return a < b
	return str(a) < str(b)

# ================================================================================
# 资源页

# 用资源库文件列表构建层级树：目录为可展开节点，文件叶子节点按分类着色。
func _populate_resources() -> void:
	resource_tree.clear()
	var files := GameDB.list_resource_files()

	var root: TreeItem = resource_tree.create_item()
	if files.is_empty():
		var empty: TreeItem = resource_tree.create_item(root)
		empty.set_text(0, "资源库为空")
		return

	var dir_items: Dictionary = {}  # 目录相对路径 -> TreeItem
	for rel in files:
		var parts := rel.split("/")
		var parent: TreeItem = root
		var cur := ""
		# 中间段是目录，按累积路径复用已建节点
		for i in range(parts.size() - 1):
			cur = cur.path_join(parts[i])
			var dir_item: TreeItem = dir_items.get(cur)
			if dir_item == null:
				dir_item = resource_tree.create_item(parent)
				dir_item.set_text(0, parts[i])
				dir_item.set_collapsed(false)
				dir_items[cur] = dir_item
			parent = dir_item
		var file_item: TreeItem = resource_tree.create_item(parent)
		file_item.set_text(0, parts[parts.size() - 1])
		file_item.set_meta("rel", rel)
		file_item.set_custom_color(0, _resource_color(rel))

# 分类着色：图片蓝 / 音频绿 / Godot 资源橙（与资源库面板配色一致）。
func _resource_color(rel: String) -> Color:
	match GameDB.get_resource_type(rel):
		"image":
			return Color(0.4, 0.6, 1.0)
		"audio":
			return Color(0.35, 0.8, 0.45)
		"godot":
			return Color(1.0, 0.7, 0.35)
	return Color(0.9, 0.9, 0.9)

func _on_resource_selected() -> void:
	var item := resource_tree.get_selected()
	if item == null:
		return
	var rel: String = item.get_meta("rel", "")
	if rel.is_empty():
		return  # 目录节点，不加载
	# 切换选择先清理上一次的预览/播放状态，避免残留。
	sprite_preview.texture = null
	audio_player.stop()
	match GameDB.get_resource_type(rel):
		"image":
			var tex: Texture2D = GameDB.load_sprite(rel)
			sprite_preview.texture = tex
			if tex:
				resource_status.text = "图片 %s → %s（%dx%d）· %s" % [
					rel, tex.get_class(), tex.get_width(), tex.get_height(),
					GameDB.resolve_resource_path(rel)]
			else:
				resource_status.text = "图片加载失败：%s" % rel
		"audio":
			var stream: AudioStream = GameDB.load_audio(rel)
			if stream:
				audio_player.stream = stream
				audio_player.play()
				resource_status.text = "音频 %s → %s（%.2f 秒）· 正在播放 · %s" % [
					rel, stream.get_class(), stream.get_length(),
					GameDB.resolve_resource_path(rel)]
			else:
				resource_status.text = "音频加载失败：%s" % rel
		"godot":
			var res: Resource = GameDB.load_resource(rel)
			if res:
				resource_status.text = "Godot 资源 %s → %s · %s" % [
					rel, res.get_class(), GameDB.resolve_resource_path(rel)]
			else:
				resource_status.text = "Godot 资源加载失败：%s" % rel

func _on_clear_cache_pressed() -> void:
	GameDB.clear_resource_cache()
	audio_player.stop()
	sprite_preview.texture = null
	resource_status.text = "资源缓存已清空（再次选择会重新加载）"
