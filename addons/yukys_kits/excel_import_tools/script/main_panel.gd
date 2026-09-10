# ================================================================================
# MainPanel —— 插件主面板（TabContainer 多标签页，Dock 用）
#
# 结构：MainPanel (Control) → Tab (TabContainer) → 功能页（每页内部自带 ScrollContainer）。
# tab 标题默认取子节点名，可在 config.json 的 panel_names 里覆盖。
#
# 新增功能：
#   1. 在 main_panel.tscn 的 Tab 下新增一个页面实例（PackedScene instance）。
#   2. 在 config.json 的 panel_names 里给该页面配置显示标题（key = 页面节点名）。
# ================================================================================

@tool
extends Control

var _tab_names: Dictionary = {}

# 取 TabContainer（MainPanel 的直接子节点）。
func _get_tabs() -> TabContainer:
	return $Tab

# 注入 importer 到所有支持 set_importer 的页面。
# 注：本方法会在 _ready 之前被 plugin.gd 调用，故直接取节点而非 @onready。
func set_importer(importer) -> void:
	for child in _get_tabs().get_children():
		if child.has_method("set_importer"):
			child.set_importer(importer)

# 按节点名取页面（找不到返回 null）。
func get_page(node_name: String) -> Node:
	for child in _get_tabs().get_children():
		if str(child.name) == node_name:
			return child
	return null

# 按节点名切换到对应 tab。
func show_page(node_name: String) -> void:
	var tabs := _get_tabs()
	for i in tabs.get_child_count():
		if str(tabs.get_child(i).name) == node_name:
			tabs.current_tab = i
			return

# 设置各 tab 的显示标题（key = 页面节点名，value = 标题）。
# 注：会在 _ready 之前被 plugin.gd 调用，先存起来，_ready 时统一应用。
func apply_tab_names(names: Dictionary) -> void:
	_tab_names = names
	if is_node_ready():
		_apply_tab_names()

func _ready() -> void:
	_apply_tab_names()

func _apply_tab_names() -> void:
	if _tab_names.is_empty():
		return
	var tabs := _get_tabs()
	for i in tabs.get_child_count():
		var key := str(tabs.get_child(i).name)
		if _tab_names.has(key):
			tabs.set_tab_title(i, str(_tab_names[key]))

# ================================================================================
