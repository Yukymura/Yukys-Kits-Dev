# ================================================================================
# UIManager —— UI 面板管理（autoload，全局单例）
#
# 需求 4.1：统一管理 UI 面板的层级、开关与跳转逻辑，控制节点数量、改善性能。
#
# 职责：
#   - 创建 / 注册面板：create_panel() / spawn_panel() / register_panel()
#   - 层级管理：面板按 layer 挂到独立 CanvasLayer（layer 越大越靠上）
#   - 开关 / 跳转：open_panel / close_panel / toggle_panel / close_all
#   - ESC 关闭：按下取消键（可设置）优先关闭最高层（后打开的）面板
#
# 与 ControlBase 协作：
#   ControlBase 是面板基类（panel_id / layer / open / close / opened / closed），
#   UIManager 通过 opened / closed 信号维护打开栈，无论谁关闭面板栈都保持一致。
#
# 用法：
#   1) 用 Godot 原生流程制作 Control 场景（根节点为 Control 即可）；
#   2) UITools.create_panel("id", "res://xxx.tscn", 5) 创建并注册；
#   3) UITools.open_panel("id") / close_panel("id") 控制开关；
#   4) 同一 id 只实例化一次（复用，控制节点数量）；
#   5) spawn_panel("res://xxx.tscn", 5) 每次新建一个实例（同时创建多个同类型面板）。
# ================================================================================

@icon("res://addons/yukys_kits/icons/ui_manager.svg")
extends Node

# 取消键（ESC）对应的输入动作名，可在 ProjectSettings 里通过 SETTING_CANCEL_ACTION 配置。
const SETTING_CANCEL_ACTION := "addons/yukys_kits/ui_cancel_action"
const DEFAULT_CANCEL_ACTION := "ui_cancel"

# 当前取消动作名（默认 ui_cancel = ESC）。
var cancel_action: String = DEFAULT_CANCEL_ACTION

# panel_id -> ControlBase
var _panels: Dictionary = {}
# layer -> CanvasLayer（懒创建，面板按层级挂载）
var _layers: Dictionary = {}
# 打开栈：按打开先后顺序记录 panel_id，用于「优先关闭高层」判定。
var _open_stack: Array[String] = []

func _ready() -> void:
	cancel_action = ProjectSettings.get_setting(SETTING_CANCEL_ACTION, DEFAULT_CANCEL_ACTION)

# ================================================================================
# 创建 / 注册面板

# 从场景实例化面板并注册。若场景根节点本就是 ControlBase 则直接使用；否则包一层
# ControlBase 再挂载（需求 4.1 的「组装」逻辑）。layer < 0 时沿用面板自身 layer。
# 同一 panel_id 只实例化一次，重复调用返回已有实例（复用，控制节点数量）。
# 若要「同时创建多个同类型面板」，用 spawn_panel()。
func create_panel(panel_id: String, scene_path: String, layer: int = -1) -> ControlBase:
	if panel_id.is_empty():
		push_error("UIManager.create_panel: panel_id 不能为空")
		return null
	if _panels.has(panel_id):
		return _panels[panel_id]
	var panel := _instantiate_panel(scene_path)
	if panel == null:
		return null
	panel.panel_id = panel_id
	panel.name = panel_id
	_mount_panel(panel, layer)
	return panel

# 每次调用都创建一个新面板实例（不复用），自动生成唯一 panel_id（"<id_base>_<序号>"）。
# 用于「同时创建多个同类型面板」的场景（支持创建多个 UI）。id_base 为空时取场景文件名。
func spawn_panel(scene_path: String, layer: int = -1, id_base: String = "") -> ControlBase:
	var panel := _instantiate_panel(scene_path)
	if panel == null:
		return null
	if id_base.is_empty():
		id_base = scene_path.get_file().get_basename()
	var panel_id := _unique_panel_id(id_base)
	panel.panel_id = panel_id
	panel.name = panel_id
	_mount_panel(panel, layer)
	return panel

# 注册一个已实现的 ControlBase 面板，交给 UIManager 管理（需求 4.3 场景）。
func register_panel(panel: ControlBase, layer: int = -1) -> ControlBase:
	if panel == null:
		push_error("UIManager.register_panel: panel 不能为 null")
		return null
	if panel.panel_id.is_empty():
		push_error("UIManager.register_panel: panel.panel_id 不能为空")
		return null
	if _panels.has(panel.panel_id):
		push_error("UIManager.register_panel: panel_id 重复: %s" % panel.panel_id)
		return null
	_mount_panel(panel, layer)
	return panel

# 注销并释放面板（连同其挂载内容）。
func unregister_panel(panel_id: String) -> void:
	var panel: ControlBase = _panels.get(panel_id)
	if panel == null:
		return
	_panels.erase(panel_id)
	_open_stack.erase(panel_id)
	if panel.opened.is_connected(_on_panel_opened):
		panel.opened.disconnect(_on_panel_opened)
	if panel.closed.is_connected(_on_panel_closed):
		panel.closed.disconnect(_on_panel_closed)
	var parent := panel.get_parent()
	if parent != null:
		parent.remove_child(panel)
	_free_node(panel)

# ================================================================================
# 查询

func get_panel(panel_id: String) -> ControlBase:
	return _panels.get(panel_id)

func has_panel(panel_id: String) -> bool:
	return _panels.has(panel_id)

func get_panel_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _panels.keys():
		ids.append(key)
	ids.sort()
	return ids

# 当前打开的面板（按打开顺序）。
func get_open_panels() -> Array[ControlBase]:
	var out: Array[ControlBase] = []
	for id in _open_stack:
		var panel: ControlBase = _panels.get(id)
		if panel != null:
			out.append(panel)
	return out

# 当前「最靠上」的打开面板：layer 最大者；同层取后打开的。
func get_top_panel() -> ControlBase:
	return _find_top(false)

# ================================================================================
# 开关 / 跳转

func open_panel(panel_id: String) -> bool:
	var panel: ControlBase = _panels.get(panel_id)
	if panel == null:
		return false
	panel.open()
	return true

func close_panel(panel_id: String) -> bool:
	var panel: ControlBase = _panels.get(panel_id)
	if panel == null:
		return false
	panel.close()
	return true

func toggle_panel(panel_id: String) -> bool:
	var panel: ControlBase = _panels.get(panel_id)
	if panel == null:
		return false
	if panel.is_open():
		panel.close()
	else:
		panel.open()
	return true

# 关闭当前最靠上的「可取消」面板（供 ESC 等取消键调用）。
func close_top_panel() -> bool:
	var target := _find_top(true)
	if target == null:
		return false
	target.close()
	return true

func close_all() -> void:
	for id in _open_stack.duplicate():
		var panel: ControlBase = _panels.get(id)
		if panel != null:
			panel.close()

# ================================================================================
# 设置

func set_cancel_action(action: String) -> void:
	cancel_action = action

func get_cancel_action() -> String:
	return cancel_action

# ================================================================================
# 输入

func _unhandled_input(event: InputEvent) -> void:
	if cancel_action.is_empty():
		return
	if event.is_action_pressed(cancel_action):
		close_top_panel()

# ================================================================================
# 内部

# 从场景实例化面板：加载 + 实例化 + 组装（根节点是 ControlBase 直接用，普通 Control 包一层）。
# 不设置 panel_id、不挂载，由 create_panel / spawn_panel 调用方负责后续。
func _instantiate_panel(scene_path: String) -> ControlBase:
	if scene_path.is_empty():
		push_error("UIManager: scene_path 不能为空")
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("UIManager: 无法加载场景 %s" % scene_path)
		return null
	var node := packed.instantiate()
	if node == null:
		push_error("UIManager: 场景实例化失败 %s" % scene_path)
		return null
	var panel: ControlBase
	if node is ControlBase:
		panel = node as ControlBase
	elif node is Control:
		var content := node as Control
		panel = ControlBase.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		push_error("UIManager: 场景根节点必须是 Control（%s 根节点是 %s）" % [scene_path, node.get_class()])
		node.free()
		return null
	return panel

# 生成唯一 panel_id：从 "<id_base>_1" 起找第一个未被占用的序号。
func _unique_panel_id(id_base: String) -> String:
	var n := 1
	while _panels.has("%s_%d" % [id_base, n]):
		n += 1
	return "%s_%d" % [id_base, n]

# 挂载面板：确定层级、挂到对应 CanvasLayer、初始隐藏、连接生命周期信号、登记。
func _mount_panel(panel: ControlBase, layer: int) -> void:
	if layer >= 0:
		panel.layer = layer
	var cl := _ensure_layer(panel.layer)
	cl.add_child(panel)
	panel.hide()
	if not panel.opened.is_connected(_on_panel_opened):
		panel.opened.connect(_on_panel_opened)
	if not panel.closed.is_connected(_on_panel_closed):
		panel.closed.connect(_on_panel_closed)
	_panels[panel.panel_id] = panel

# 取（或懒创建）某层级的 CanvasLayer，layer 值即 CanvasLayer.layer（越大越靠上）。
func _ensure_layer(layer: int) -> CanvasLayer:
	if _layers.has(layer):
		return _layers[layer]
	var cl := CanvasLayer.new()
	cl.name = "Layer%d" % layer
	cl.layer = layer
	add_child(cl)
	_layers[layer] = cl
	return cl

# 面板打开时移到本层级最上（同一 CanvasLayer 内靠后绘制即靠上）。
func _bring_to_front(panel: ControlBase) -> void:
	var cl: CanvasLayer = _layers.get(panel.layer)
	if cl != null and panel.get_parent() == cl:
		cl.move_child(panel, -1)

# 找「最靠上」的打开面板。require_closable 为 true 时跳过 close_on_cancel=false 的面板。
func _find_top(require_closable: bool) -> ControlBase:
	var best: ControlBase = null
	for id in _open_stack:
		var panel: ControlBase = _panels.get(id)
		if panel == null or not panel.is_open():
			continue
		if require_closable and not panel.close_on_cancel:
			continue
		if best == null or panel.layer >= best.layer:
			best = panel
	return best

func _on_panel_opened(panel: ControlBase) -> void:
	_bring_to_front(panel)
	if not _open_stack.has(panel.panel_id):
		_open_stack.append(panel.panel_id)

func _on_panel_closed(panel: ControlBase) -> void:
	_open_stack.erase(panel.panel_id)

func _free_node(node: Node) -> void:
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.free()
