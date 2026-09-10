# ================================================================================
# MainPanel —— 插件主面板（TabContainer 多标签页，Dock 用）
#
# 结构：MainPanel (Control) → Tab (TabContainer) → 功能页（每页内部自带 ScrollContainer）。
# tab 标题在 main_panel.tscn 中设置。
#
# 新增功能：
#   1. 在 main_panel.tscn 的 Tab 下新增一个页面实例（PackedScene instance）。
#   2. 在 Tab 上设置对应 tab 的标题。
# ================================================================================

@tool
extends Control

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

# ================================================================================
