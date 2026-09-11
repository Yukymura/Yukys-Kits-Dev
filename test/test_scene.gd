# ================================================================================
# TestScene —— 插件正确性测试场景（位于游戏目录，非插件目录）
#
# 仅通过插件暴露的接口 GameDB（autoload）访问导表数据，不调用任何插件内部接口：
#   - GameDB.get_table_names()  -> Array[String]      所有数据表名
#   - GameDB.get_table(name)    -> { id: {字段:值}, ... }
#   - GameDB.get_row(name, id)  -> {字段:值}
#
# 功能：
#   1. 下拉列表列出所有数据表，选中后展示整张表。
#   2. key 搜索框，输入后仅显示 key 匹配的数据行。
# ================================================================================

extends Control

@onready var table_selector: OptionButton = $Margin/VBox/TableRow/TableSelector
@onready var search_box: LineEdit = $Margin/VBox/SearchRow/SearchBox
@onready var clear_button: Button = $Margin/VBox/SearchRow/ClearButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var data_tree: Tree = $Margin/VBox/DataTree

func _ready() -> void:
	table_selector.item_selected.connect(_on_table_selected)
	search_box.text_changed.connect(_on_search_changed)
	clear_button.pressed.connect(_on_clear_pressed)

	_populate_tables()
	_refresh()

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
