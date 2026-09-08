# ================================================================================
# ConfigTool —— config.json 读写
# ================================================================================

@tool
extends RefCounted

# 返回 { ok: bool, data/error }
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "配置文件不存在: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"ok": false, "error": "无法打开配置: %s" % path}
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		return {"ok": false, "error": "配置解析失败: %s" % path}
	return {"ok": true, "data": data}

# 返回 { ok: bool, data/error }
static func save_config(path: String, data: Dictionary) -> Dictionary:
	if not path.ends_with(".json"):
		path += ".json"
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"ok": false, "error": "无法保存配置: %s" % path}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return {"ok": true, "data": path}

# ================================================================================
