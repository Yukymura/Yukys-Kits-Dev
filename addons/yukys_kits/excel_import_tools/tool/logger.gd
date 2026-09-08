# ================================================================================
# Logger —— 导表日志
#
# 职责：
#   - 把导表的记录、过程、失败原因写入日志文件（追加模式）。
#   - 控制台只输出「导表结果」和「失败原因」，由 done()/error() 负责。
#
# 用法：
#   Logger.set_log_path(path)  设置日志文件
#   Logger.info(msg)   仅写日志
#   Logger.warn(msg)   仅写日志
#   Logger.error(msg)  写日志 + 控制台（失败原因）
#   Logger.done(msg)   写日志 + 控制台（导表结果）
# ================================================================================

@tool
extends RefCounted

# ================================================================================

static var _log_path: String = ""

static func set_log_path(path: String) -> void:
	_log_path = path

static func get_log_path() -> String:
	return _log_path

static func info(msg: String) -> void:
	_write("INFO", msg)

static func warn(msg: String) -> void:
	_write("WARN", msg)

static func error(msg: String) -> void:
	_write("ERROR", msg)
	printerr(msg)

static func done(msg: String) -> void:
	_write("DONE", msg)
	print(msg)

static func _write(level: String, msg: String) -> void:
	if _log_path.is_empty():
		return
	var dir := _log_path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var line := "[%s] [%s] %s\n" % [Time.get_datetime_string_from_system(), level, msg]
	# READ_WRITE 不会创建不存在的文件，首次写入需用 WRITE 创建
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_log_path) else FileAccess.WRITE
	var file := FileAccess.open(_log_path, mode)
	if file:
		file.seek_end()
		file.store_string(line)
		file.close()

# ================================================================================
