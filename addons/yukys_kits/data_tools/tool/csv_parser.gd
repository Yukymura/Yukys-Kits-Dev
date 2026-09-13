# ================================================================================
# CsvParser —— 解析「规定格式」的 CSV
#
# 规定格式：
#   第 1 行   表头：第一个单元格为表名。
#   第 2 行   字段行：首格以 "*" 开头标记（如 "*id"，第一列为 id，不导出），
#             其后每格为 "字段名:类型"。字段名以 "#" 开头表示忽略（不导出）。
#   第 3 行起 数据行：首格为 id，其余为对应字段的值。
#             id 以 "#" 开头或为空的行被跳过。
#
# 解析结果 data：
#   {
#     "header": String,  表名
#     "keys":   Array,   字段名列表
#     "types":  Array,   类型列表（与 keys 对应）
#     "values": Array,   数据行，每行 = [id, 字段值...]
#   }
# ================================================================================

@tool
extends RefCounted

# ================================================================================

# 返回 { ok: bool, data/error }
static func read_csv(path: String, delimiter: String = ",") -> Dictionary:
	var raw := _read_lines(path, delimiter)
	if not raw.ok:
		return raw
	var lines: Array = raw.data

	# 第 1 行：表头（表名）
	if lines.is_empty():
		return _fail("文件为空: %s" % path)
	var header_line = lines[0]
	var table_name := _strip_bom(str(header_line[0]).strip_edges()) if header_line.size() > 0 else ""
	if table_name.is_empty():
		return _fail("缺少表头（第 1 行第一格应为表名）")

	# 剔除空行与注释行，得到正文
	var body: Array = []
	for i in range(1, lines.size()):
		var line = lines[i]
		if line.is_empty():
			continue
		var first := str(line[0]).strip_edges()
		if first.is_empty() or first.begins_with("#"):
			continue
		body.append(line)
	if body.is_empty():
		return _fail("没有数据行")

	# 第 2 行：字段行（首格以 "*" 开头标记，如 "*id"，第一列为 id，不导出）
	var key_line = body[0]
	if key_line.is_empty() or not str(key_line[0]).strip_edges().begins_with("*"):
		return _fail("缺少字段行（第 2 行第一格应以 \"*\" 开头，例如 \"*id\"）")

	var keys: Array = []
	var types: Array = []
	var cols: Array = []
	for i in range(1, key_line.size()):
		var token := str(key_line[i]).strip_edges()
		if token.is_empty() or token.begins_with("#"):
			continue
		var parts := token.split(":")
		var field_name := parts[0].strip_edges()
		var field_type := parts[1].strip_edges() if parts.size() > 1 else "String"
		if field_name.is_empty():
			continue
		keys.append(field_name)
		types.append(field_type)
		cols.append(i)
	if keys.is_empty():
		return _fail("没有可导出的字段")

	# 数据行
	var values: Array = []
	for i in range(1, body.size()):
		var line = body[i]
		var row: Array = [str(line[0]).strip_edges()]
		for c in cols:
			row.append(str(line[c]) if c < line.size() else "")
		values.append(row)
	if values.is_empty():
		return _fail("没有有效的数据行")

	return _ok({
		"header": table_name,
		"keys": keys,
		"types": types,
		"values": values,
	})

# ================================================================================

static func _read_lines(path: String, delimiter: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("文件不存在: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return _fail("无法打开文件: %s" % path)
	var lines: Array = []
	while not file.eof_reached():
		lines.append(file.get_csv_line(delimiter))
	file.close()
	return _ok(lines)

static func _strip_bom(s: String) -> String:
	return s.lstrip(String.chr(0xFEFF))

static func _ok(data) -> Dictionary:
	return {"ok": true, "data": data}

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

# ================================================================================
