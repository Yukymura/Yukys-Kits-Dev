# ================================================================================
# UITools —— UI 工具（autoload，全局单例）
#
# 需求 4.2：提供接口进行 UI 相关的创建 / 开关 / 设置操作，底层委托给 UIManager。
#
# 暴露给业务代码的接口（均委托给 UIManager）：
#   UITools.create_panel(id, scene_path, layer) -> ControlBase  创建并注册面板（可复用）
#   UITools.spawn_panel(scene_path, layer, id_base) -> ControlBase  每次新建实例（多个同类型面板）
#   UITools.register_panel(panel, layer)        -> ControlBase  注册已实现的 ControlBase
#   UITools.open_panel(id) / close_panel(id) / toggle_panel(id)
#   UITools.get_panel(id) / has_panel(id) / get_panel_ids()
#   UITools.get_open_panels() / get_top_panel()
#   UITools.close_top_panel() / close_all()
#   UITools.set_cancel_action(action) / get_cancel_action()
# ================================================================================

@icon("res://addons/yukys_kits/icons/ui_tools.svg")
extends Node

# UIManager autoload 的路径（project.godot 注册名 UIManager）。
const UIMANAGER_PATH := "/root/UIManager"

func _manager() -> Variant:
	return get_node_or_null(UIMANAGER_PATH)

func create_panel(panel_id: String, scene_path: String, layer: int = -1) -> ControlBase:
	var m = _manager()
	if m == null:
		return null
	return m.create_panel(panel_id, scene_path, layer)

func spawn_panel(scene_path: String, layer: int = -1, id_base: String = "") -> ControlBase:
	var m = _manager()
	if m == null:
		return null
	return m.spawn_panel(scene_path, layer, id_base)

func register_panel(panel: ControlBase, layer: int = -1) -> ControlBase:
	var m = _manager()
	if m == null:
		return null
	return m.register_panel(panel, layer)

func unregister_panel(panel_id: String) -> void:
	var m = _manager()
	if m != null:
		m.unregister_panel(panel_id)

func get_panel(panel_id: String) -> ControlBase:
	var m = _manager()
	if m == null:
		return null
	return m.get_panel(panel_id)

func has_panel(panel_id: String) -> bool:
	var m = _manager()
	if m == null:
		return false
	return m.has_panel(panel_id)

func get_panel_ids() -> Array[String]:
	var m = _manager()
	if m == null:
		return []
	return m.get_panel_ids()

func get_open_panels() -> Array[ControlBase]:
	var m = _manager()
	if m == null:
		return []
	return m.get_open_panels()

func get_top_panel() -> ControlBase:
	var m = _manager()
	if m == null:
		return null
	return m.get_top_panel()

func open_panel(panel_id: String) -> bool:
	var m = _manager()
	if m == null:
		return false
	return m.open_panel(panel_id)

func close_panel(panel_id: String) -> bool:
	var m = _manager()
	if m == null:
		return false
	return m.close_panel(panel_id)

func toggle_panel(panel_id: String) -> bool:
	var m = _manager()
	if m == null:
		return false
	return m.toggle_panel(panel_id)

func close_top_panel() -> bool:
	var m = _manager()
	if m == null:
		return false
	return m.close_top_panel()

func close_all() -> void:
	var m = _manager()
	if m != null:
		m.close_all()

func set_cancel_action(action: String) -> void:
	var m = _manager()
	if m != null:
		m.set_cancel_action(action)

func get_cancel_action() -> String:
	var m = _manager()
	if m == null:
		return ""
	return m.get_cancel_action()
