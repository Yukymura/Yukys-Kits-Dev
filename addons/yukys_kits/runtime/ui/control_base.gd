# ================================================================================
# ControlBase —— 自定义 UI 面板基类（需求 4.3）
#
# 继承 Control，作为本插件所有自定义 UI 面板的统一基类，放在 runtime/ui/ 目录，
# 随游戏一起导出。
#
# 服从 UIManager 管理：
#   - panel_id：面板唯一标识，UIManager 据此查找 / 注册 / 跳转面板。
#   - layer：面板层级，UIManager 据此做层级排序 / 堆叠管理。
#   - open() / close() + opened / closed 信号：统一的面板开关生命周期，
#     供 UIManager 与外部监听。
#
# 保持可拓展性：子类可覆写 _on_open() / _on_close() 钩子，或新增自身属性与信号，
# 无需改动 UIManager 的基础管理逻辑。
# ================================================================================

@icon("res://addons/yukys_kits/icons/control_base.svg")
class_name ControlBase
extends Control

# --------------------------------------------------------------------------------
# 属性

## 面板唯一标识（UIManager 据此管理面板，建议每个面板全局唯一）。
@export var panel_id: String = ""

## 面板层级（数值越大越靠前，供 UIManager 做层级 / 堆叠管理）。
@export var layer: int = 0

## 是否在按下取消键（ESC）时被 UIManager 优先关闭。默认 true；弹窗/输入类面板可设 false 豁免。
@export var close_on_cancel: bool = true

# --------------------------------------------------------------------------------
# 信号

## 面板打开后发出（open() 调用成功后）。
signal opened(panel: ControlBase)

## 面板关闭后发出（close() 调用成功后）。
signal closed(panel: ControlBase)

# --------------------------------------------------------------------------------
# 状态

# 面板当前是否处于打开状态。
var _is_open: bool = false

# --------------------------------------------------------------------------------
# 生命周期接口

## 打开面板：显示自身并发出 opened 信号。已打开时无操作。
func open() -> void:
	if _is_open:
		return
	_is_open = true
	_on_open()
	visible = true
	opened.emit(self)

## 关闭面板：隐藏自身并发出 closed 信号。已关闭时无操作。
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_on_close()
	visible = false
	closed.emit(self)

## 面板是否打开。
func is_open() -> bool:
	return _is_open

# --------------------------------------------------------------------------------
# 覆写钩子（子类实现，无需调用 super）

## 打开时的扩展逻辑（子类覆写）。
func _on_open() -> void:
	pass

## 关闭时的扩展逻辑（子类覆写）。
func _on_close() -> void:
	pass
