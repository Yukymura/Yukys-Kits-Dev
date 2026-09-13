# ================================================================================
# JsonDataTool —— 结构化数据 与 JSON 文件互转（load_file 返回含 types）
#
# 写入：把 CsvParser 的解析结果转换为类型化字典，序列化为 JSON 文件。
# 读取：加载导出目录下的所有 JSON，并把 JSON 值还原为 Godot 类型。
#
# JSON 结构：
#   {
#     "table_name": "表名",
#     "import_path": "源 CSV 路径",
#     "update_time": "更新时间",
#     "types": { "字段": "类型", ... },
#     "data": { "id": { "字段": 值, ... }, ... }
#   }
# ================================================================================

@tool
extends RefCounted

# 数据库目录（导出/读取 JSON 的目录）的 ProjectSettings 键与默认值。
# 编辑器侧（DataImporter / plugin.gd）写入，运行时侧（GameDB）经此键读取，
# 让运行时不再写死 res://data，而是跟随用户配置的导出路径。
const SETTING_DATA_DIR := "addons/yukys_kits/data_dir"
const DEFAULT_DATA_DIR := "res://data"

# ================================================================================
# 写

# 返回 { ok: bool, data/error }
static func create_json(path: String, import_path: String, csv_data: Dictionary) -> Dictionary:
	var table_name: String = csv_data["header"]
	var keys: Array = csv_data["keys"]
	var types: Array = csv_data["types"]
	var values: Array = csv_data["values"]

	var types_dict: Dictionary = {}
	for i in range(keys.size()):
		types_dict[keys[i]] = types[i]

	var data_dict: Dictionary = {}
	var seen: Dictionary = {}
	for row in values:
		var id := str(row[0])
		if seen.has(id):
			return _fail("id 重复: %s" % id)
		seen[id] = true
		var row_dict: Dictionary = {}
		for j in range(keys.size()):
			row_dict[keys[j]] = cell_to_value(str(row[j + 1]), str(types[j]))
		data_dict[id] = row_dict

	var root := {
		"table_name": table_name,
		"import_path": import_path,
		"update_time": Time.get_datetime_string_from_system(),
		"types": types_dict,
		"data": data_dict,
	}

	if not path.ends_with(".json"):
		path += ".json"
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _fail("无法写入文件: %s" % path)
	file.store_string(JSON.stringify(root, "\t"))
	file.close()
	return _ok(path)

# CSV 单元格字符串 → 可 JSON 序列化的值（int/float/bool/String/Array）
static func cell_to_value(cell: String, type_str: String):
	var t := type_str.strip_edges()
	if t.begins_with("Array"):
		var inner := _inner_type(t)
		var arr: Array = []
		for e in cell.split(";"):
			var se := e.strip_edges()
			if se.is_empty():
				continue
			arr.append(cell_to_value(se, inner))
		return arr
	match t:
		"int":
			return cell.strip_edges().to_int()
		"float":
			return cell.strip_edges().to_float()
		"bool":
			return _to_bool(cell)
		"Vector2":
			return _parse_vector(cell, 2, false)
		"Vector3":
			return _parse_vector(cell, 3, false)
		"Vector2i":
			return _parse_vector(cell, 2, true)
		"Vector3i":
			return _parse_vector(cell, 3, true)
		_:
			return cell

# ================================================================================
# 读

static func load_all(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	if dir_path.is_empty():
		return result
	_load_dir(dir_path, result)
	return result

# 返回 { ok: bool, data: { table_name, data, types } / error }
static func load_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return _fail("文件不存在: %s" % file_path)
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return _fail("无法打开文件: %s" % file_path)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return _fail("JSON 解析失败: %s" % file_path)
	if not parsed.has("data") or not parsed.has("types") or not parsed.has("table_name"):
		return _fail("JSON 结构不完整: %s" % file_path)

	var types_dict: Dictionary = parsed["types"]
	var raw_data: Dictionary = parsed["data"]
	var converted: Dictionary = {}
	for key in raw_data:
		var row: Dictionary = raw_data[key]
		var out_row: Dictionary = {}
		for field in row:
			out_row[field] = json_to_value(row[field], str(types_dict.get(field, "")))
		converted[_convert_id(key)] = out_row

	return _ok({"table_name": parsed["table_name"], "data": converted, "types": types_dict})

# JSON 值 → Godot 类型值
static func json_to_value(value, type_str: String):
	var t := type_str.strip_edges()
	if t.begins_with("Array"):
		var inner := _inner_type(t)
		if value is Array:
			var arr: Array = []
			for e in value:
				arr.append(json_to_value(e, inner))
			return arr
		return []
	match t:
		"int":
			return int(value)
		"float":
			return float(value)
		"bool":
			return bool(value)
		"Vector2":
			return Vector2(_num(value, 0), _num(value, 1))
		"Vector3":
			return Vector3(_num(value, 0), _num(value, 1), _num(value, 2))
		"Vector2i":
			return Vector2i(_int(value, 0), _int(value, 1))
		"Vector3i":
			return Vector3i(_int(value, 0), _int(value, 1), _int(value, 2))
		_:
			return value

# ================================================================================
# 内部

static func _load_dir(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		var full := path.path_join(item)
		if dir.current_is_dir():
			_load_dir(full, out)
		elif full.get_extension().to_lower() == "json":
			var r := load_file(full)
			if r.ok:
				var info: Dictionary = r.data
				out[info["table_name"]] = info["data"]
		item = dir.get_next()
	dir.list_dir_end()

static func _convert_id(key):
	if key is String and key.is_valid_int():
		return int(key)
	if key is float and key == floor(key):
		return int(key)
	return key

static func _inner_type(t: String) -> String:
	var start := t.find("[")
	var end := t.rfind("]")
	if start != -1 and end > start:
		return t.substr(start + 1, end - start - 1).strip_edges()
	return "String"

static func _to_bool(s: String) -> bool:
	var v := s.strip_edges().to_lower()
	return v == "true" or v == "1" or v == "yes"

static func _parse_vector(cell: String, n: int, as_int: bool) -> Array:
	var s := cell.strip_edges()
	if s.begins_with("(") and s.ends_with(")"):
		s = s.substr(1, s.length() - 2)
	var parts := s.split(",")
	var out: Array = []
	for i in range(n):
		var v := parts[i].strip_edges().to_float() if i < parts.size() else 0.0
		out.append(int(v) if as_int else v)
	return out

static func _num(value, i: int) -> float:
	if value is Array and i < value.size():
		return float(value[i])
	return 0.0

static func _int(value, i: int) -> int:
	if value is Array and i < value.size():
		return int(value[i])
	return 0

static func _ok(data) -> Dictionary:
	return {"ok": true, "data": data}

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

# ================================================================================
