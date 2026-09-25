# ================================================================================
# UI 工具（需求 4）—— 回归测试
#
#   验证 UIManager / ControlBase 的核心逻辑（无需场景树即可测）：
#   - register_panel / get_panel / has_panel / get_panel_ids
#   - open / close / toggle / close_all 与打开栈
#   - 层级排序：get_top_panel 返回最高层；同层取后打开的
#   - ESC 关闭：close_top_panel / _unhandled_input 优先关闭最高层
#   - close_on_cancel=false 的面板被跳过
#   - create_panel：从场景实例化、包裹 Control、同 id 复用
#
#   注：UIManager 是运行时 autoload，这里直接 preload 脚本 new() 出独立实例测试；
#   ControlBase 是全局 class_name，直接 new()。
# ================================================================================

@tool
extends McpTestSuite

const UIManager := preload("res://addons/yukys_kits/runtime/ui_manager.gd")

# 测试用简单 Control 场景（游戏目录 test/ 下），用于 create_panel 的包裹逻辑。
const TEST_PANEL_SCENE := "res://test/ui_test_panel.tscn"

func suite_name() -> String:
	return "ui_manager"

func _make_manager() -> Variant:
	var m = UIManager.new()
	track(m)
	return m

func _make_panel(m, id: String, layer: int) -> ControlBase:
	var p := ControlBase.new()
	p.panel_id = id
	m.register_panel(p, layer)
	return p

func test_register_and_query() -> void:
	var m = _make_manager()
	var p := _make_panel(m, "shop", 3)
	assert_true(m.has_panel("shop"), "注册后 has_panel 应为 true")
	assert_true(m.get_panel("shop") == p, "get_panel 应返回同一面板")
	assert_true(m.get_panel_ids().has("shop"), "get_panel_ids 应包含 shop")
	assert_true(p.get_parent() is CanvasLayer, "面板应挂到 CanvasLayer")
	assert_eq((p.get_parent() as CanvasLayer).layer, 3, "CanvasLayer.layer 应等于面板 layer")

func test_open_close() -> void:
	var m = _make_manager()
	var p := _make_panel(m, "bag", 1)
	assert_true(m.open_panel("bag"), "open_panel 应返回 true")
	assert_true(p.is_open(), "打开后 is_open 应为 true")
	assert_true(p.visible, "打开后应可见")
	assert_true(m.get_top_panel() == p, "打开后面板应位于栈顶")
	assert_true(m.close_panel("bag"), "close_panel 应返回 true")
	assert_false(p.is_open(), "关闭后 is_open 应为 false")
	assert_true(m.get_top_panel() == null, "关闭后栈应为空")

func test_toggle() -> void:
	var m = _make_manager()
	var p := _make_panel(m, "mail", 1)
	m.toggle_panel("mail")
	assert_true(p.is_open(), "toggle 打开")
	m.toggle_panel("mail")
	assert_false(p.is_open(), "toggle 关闭")

func test_top_panel_by_layer() -> void:
	var m = _make_manager()
	_make_panel(m, "a", 1)
	var b := _make_panel(m, "b", 3)
	_make_panel(m, "c", 2)
	m.open_panel("a")
	m.open_panel("c")
	m.open_panel("b")
	assert_true(m.get_top_panel() == b, "最高层 b 应为栈顶")

func test_same_layer_recent_open() -> void:
	var m = _make_manager()
	_make_panel(m, "a", 1)
	var b := _make_panel(m, "b", 1)
	m.open_panel("a")
	m.open_panel("b")
	assert_true(m.get_top_panel() == b, "同层后打开的 b 应为栈顶")

func test_close_top_closes_highest_first() -> void:
	var m = _make_manager()
	var a := _make_panel(m, "a", 1)
	var b := _make_panel(m, "b", 3)
	var c := _make_panel(m, "c", 2)
	m.open_panel("a")
	m.open_panel("b")
	m.open_panel("c")
	assert_true(m.close_top_panel(), "close_top_panel 应返回 true")
	assert_false(b.is_open(), "最高层 b 应先被关闭")
	assert_true(c.is_open(), "c 应保持打开")
	assert_true(a.is_open(), "a 应保持打开")
	assert_true(m.close_top_panel(), "再次 close_top_panel")
	assert_false(c.is_open(), "其次关闭 c")
	assert_true(m.close_top_panel(), "第三次 close_top_panel")
	assert_false(a.is_open(), "最后关闭 a")
	assert_false(m.close_top_panel(), "无打开面板时应返回 false")

func test_close_on_cancel_opt_out() -> void:
	var m = _make_manager()
	var a := _make_panel(m, "a", 1)
	var b := _make_panel(m, "b", 2)
	b.close_on_cancel = false
	m.open_panel("a")
	m.open_panel("b")
	assert_true(m.close_top_panel(), "应关闭到可关闭的面板")
	assert_true(b.is_open(), "close_on_cancel=false 的 b 应被跳过")
	assert_false(a.is_open(), "a 应被关闭")

func test_cancel_input_closes_top() -> void:
	var m = _make_manager()
	var a := _make_panel(m, "a", 1)
	var b := _make_panel(m, "b", 2)
	m.open_panel("a")
	m.open_panel("b")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	m._unhandled_input(ev)
	assert_false(b.is_open(), "ESC 应关闭最高层 b")
	assert_true(a.is_open(), "低层 a 应保持打开")

func test_close_all() -> void:
	var m = _make_manager()
	_make_panel(m, "a", 1)
	_make_panel(m, "b", 2)
	m.open_panel("a")
	m.open_panel("b")
	m.close_all()
	assert_true(m.get_open_panels().is_empty(), "close_all 后打开栈应为空")

func test_create_panel_wraps_and_reuses() -> void:
	var m = _make_manager()
	var p1 = m.create_panel("hud", TEST_PANEL_SCENE, 5)
	assert_true(p1 is ControlBase, "create_panel 应返回 ControlBase")
	assert_eq(p1.panel_id, "hud", "panel_id 应被设置")
	assert_eq(p1.layer, 5, "layer 应被设置")
	assert_true(p1.get_child_count() >= 1, "包裹场景应把用户 Control 挂为子节点")
	assert_true(not p1.is_open(), "创建后默认关闭")
	var p2 = m.create_panel("hud", TEST_PANEL_SCENE, 5)
	assert_true(p1 == p2, "同 id 重复 create 应复用同一实例")
	m.unregister_panel("hud")
	assert_false(m.has_panel("hud"), "注销后 has_panel 应为 false")

func test_spawn_panel_multiple_instances() -> void:
	var m = _make_manager()
	var p1 = m.spawn_panel(TEST_PANEL_SCENE, 5, "toast")
	var p2 = m.spawn_panel(TEST_PANEL_SCENE, 5, "toast")
	assert_true(p1 is ControlBase and p2 is ControlBase, "spawn_panel 应返回 ControlBase")
	assert_true(p1 != p2, "两次 spawn 应返回不同实例")
	assert_eq(p1.panel_id, "toast_1", "第一个实例 id 应为 toast_1")
	assert_eq(p2.panel_id, "toast_2", "第二个实例 id 应为 toast_2")
	assert_true(m.has_panel("toast_1") and m.has_panel("toast_2"), "两个面板都应注册")
	assert_eq(m.get_panel_ids().size(), 2, "应注册 2 个面板")
	var p3 = m.spawn_panel(TEST_PANEL_SCENE)
	assert_eq(p3.panel_id, "ui_test_panel_1", "缺省 id_base 应取场景文件名")
	m.unregister_panel("toast_1")
	m.unregister_panel("toast_2")
	m.unregister_panel("ui_test_panel_1")
