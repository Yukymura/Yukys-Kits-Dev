# ================================================================================
# SettingItem —— 设置项场景（对应「设置项配置表」的一行）
#
# 根据配置项的 type 动态创建交互控件：
#   1=勾选框 CheckBox      2=输入框 LineEdit      3=路径框（只读输入框 + 文件选择按钮）
#   4=选项框 OptionButton  5=颜色框 ColorPickerButton
# 控件值通过 DataImporter.get_setting / set_setting 按 data_name 读写，
# 序列化（Color -> 十六进制）在 DataImporter 内部完成，这里只传类型化值。
# ================================================================================

@tool
extends HBoxContainer

const TYPE_CHECKBOX := 1
const TYPE_LINEEDIT := 2
const TYPE_PATH := 3
const TYPE_OPTION := 4
const TYPE_COLOR := 5

var _importer: Variant
var _data_name: String = ""
var _type: int = TYPE_LINEEDIT
var _control: Control      # 类型对应的交互控件（type 3 为容器）
var _path_edit: LineEdit   # type 3 的只读路径输入框

func setup(importer, config: Dictionary) -> void:
	_importer = importer
	_data_name = str(config.get("data_name", ""))
	_type = int(config.get("type", TYPE_LINEEDIT))
	$NameLabel.text = str(config.get("setting_name", ""))
	var desc: String = str(config.get("description", ""))
	if not desc.is_empty():
		$NameLabel.tooltip_text = desc
	var reset := _build_reset_button()
	if reset != null:
		add_child(reset)
	_control = _build_control(config)
	if _control != null:
		add_child(_control)
	_load_value()

func _build_control(config: Dictionary) -> Control:
	match _type:
		TYPE_CHECKBOX:
			return _build_checkbox()
		TYPE_LINEEDIT:
			return _build_lineedit()
		TYPE_PATH:
			return _build_path()
		TYPE_OPTION:
			return _build_option(config)
		TYPE_COLOR:
			return _build_color()
	return null

# --- 重置按钮 ---

# 扁平图标按钮，图标用 Godot 检查器「重置为默认值」同款（Reload / EditorIcons）。
func _build_reset_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.tooltip_text = "重置为默认值"
	b.custom_minimum_size = Vector2(24, 0)
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme != null:
		var icon := editor_theme.get_icon("Reload", "EditorIcons")
		if icon != null:
			b.icon = icon
	b.pressed.connect(_on_reset_pressed)
	return b

# --- 各类型控件构建 ---

func _build_checkbox() -> CheckBox:
	var c := CheckBox.new()
	c.toggled.connect(_on_checkbox_toggled)
	return c

func _build_lineedit() -> LineEdit:
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_submitted.connect(_on_text_submitted)
	return e

func _build_path() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	_path_edit = LineEdit.new()
	_path_edit.editable = false
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_path_edit)

	var btn := Button.new()
	btn.text = "设置"
	btn.custom_minimum_size = Vector2(64, 32)
	box.add_child(btn)

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.title = "选择目录"
	box.add_child(dialog)

	btn.pressed.connect(dialog.popup_centered_ratio.bind(0.6))
	dialog.dir_selected.connect(func(path: String) -> void:
		_path_edit.text = path
		_importer.set_setting(_data_name, path)
	)

	return box

func _build_option(config: Dictionary) -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options: Array = config.get("option", [])
	for opt in options:
		o.add_item(str(opt))
	o.item_selected.connect(_on_option_selected)
	return o

func _build_color() -> ColorPickerButton:
	var p := ColorPickerButton.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.popup_closed.connect(_on_color_picker_closed)
	return p

# --- 值读写 ---

func _load_value() -> void:
	if _importer == null or _data_name.is_empty():
		return
	var v = _importer.get_setting(_data_name)
	match _type:
		TYPE_CHECKBOX:
			(_control as CheckBox).button_pressed = bool(v)
		TYPE_LINEEDIT:
			(_control as LineEdit).text = "" if v == null else str(v)
		TYPE_PATH:
			if _path_edit != null:
				_path_edit.text = "" if v == null else str(v)
		TYPE_OPTION:
			_select_option(v)
		TYPE_COLOR:
			if v is Color:
				(_control as ColorPickerButton).color = v

func _select_option(v) -> void:
	var o := _control as OptionButton
	if v == null:
		return
	for i in o.item_count:
		if o.get_item_text(i) == str(v):
			o.select(i)
			return

# --- 控件回调 ---

func _on_checkbox_toggled(pressed: bool) -> void:
	_importer.set_setting(_data_name, pressed)

func _on_text_submitted(text: String) -> void:
	_importer.set_setting(_data_name, text)

func _on_option_selected(index: int) -> void:
	_importer.set_setting(_data_name, (_control as OptionButton).get_item_text(index))

func _on_color_picker_closed() -> void:
	_importer.set_setting(_data_name, (_control as ColorPickerButton).color)

func _on_reset_pressed() -> void:
	if _importer == null or _data_name.is_empty():
		return
	var dflt = _importer.get_setting_default(_data_name)
	if dflt == null:
		return
	_importer.set_setting(_data_name, dflt)
	_load_value()
