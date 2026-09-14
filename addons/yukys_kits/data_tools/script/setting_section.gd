# ================================================================================
# SettingSection —— 设置栏位场景（对应「设置栏配置表」的一行）
#
# 一个栏位 = 一个有背景色的标题（像 Godot 检查器里的栏位）+ 一列设置项。
# 由 SettingsDock 根据设置栏配置表实例化，再通过 add_item() 把同栏位的
# 设置项场景（SettingItem）挂进来。
# ================================================================================

@tool
extends VBoxContainer

func setup(title: String) -> void:
	$Header/TitleLabel.text = title

func add_item(item: Node) -> void:
	$ItemsBox.add_child(item)
