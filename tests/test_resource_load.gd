# ================================================================================
# 资源库加载（需求 2.1）—— 回归测试
#
#   验证 GameDB 新增的资源加载能力：
#   - resolve_resource_path：相对路径 → 拼上资源库目录；res:// / 绝对路径原样返回。
#   - load_sprite / load_audio / load_resource：从资源库加载图片/音频/Godot 资源。
#   - 缓存：同一路径重复加载返回同一实例（性能）。
#   - 不存在的资源返回 null（不报错）。
#
#   注：GameDB 是运行时 autoload，这里直接 preload 脚本 new() 出独立实例测试其
#   公开方法（这些方法不依赖 _ready / 是否挂入场景树）。
# ================================================================================

@tool
extends McpTestSuite

const GameDB := preload("res://addons/yukys_kits/runtime/game_db.gd")

func suite_name() -> String:
	return "resource_load"

func test_resolve_relative_path() -> void:
	var db = GameDB.new()
	# 相对路径 → 拼上资源库目录（缺省 res://res）
	assert_eq(db.resolve_resource_path("pic/啤酒.png"), "res://res/pic/啤酒.png",
		"相对路径应拼上资源库目录")
	# res:// / user:// / 绝对路径 → 原样返回
	assert_eq(db.resolve_resource_path("res://res/pic/啤酒.png"), "res://res/pic/啤酒.png",
		"res:// 路径应原样返回")
	assert_eq(db.resolve_resource_path("user://assets/a.png"), "user://assets/a.png",
		"user:// 路径应原样返回")
	assert_eq(db.resolve_resource_path(""), "", "空路径应返回空串")
	db.free()

func test_load_sprite_and_cache() -> void:
	var db = GameDB.new()
	var s1 = db.load_sprite("res://res/pic/啤酒.png")
	assert_true(s1 is Texture2D, "完整 res:// 路径应加载出 Texture2D")
	var s2 = db.load_sprite("pic/啤酒.png")
	assert_true(s2 is Texture2D, "相对路径应加载出 Texture2D")
	assert_true(s1 == s2, "同一资源重复加载应命中缓存（同一实例）")
	db.clear_resource_cache()
	var s3 = db.load_sprite("pic/啤酒.png")
	assert_true(s3 is Texture2D, "清缓存后仍能加载")
	db.free()

func test_load_audio() -> void:
	var db = GameDB.new()
	var a1 = db.load_audio("res://res/sfx/我的世界拾取物品.mp3")
	assert_true(a1 is AudioStream, "完整 res:// 路径应加载出 AudioStream")
	var a2 = db.load_audio("sfx/我的世界拾取物品.mp3")
	assert_true(a2 is AudioStream, "相对路径应加载出 AudioStream")
	assert_true(a1 == a2, "音频重复加载应命中缓存")
	db.free()

func test_load_godot_resource() -> void:
	var db = GameDB.new()
	var r = db.load_resource("res://res/theme/theme1.tres")
	assert_true(r is Resource, "应加载出 Godot 资源")
	db.free()

func test_missing_resource_returns_null() -> void:
	var db = GameDB.new()
	assert_true(db.load_sprite("pic/不存在.png") == null, "不存在的资源应返回 null")
	assert_true(db.load_audio("sfx/不存在.mp3") == null, "不存在的音频应返回 null")
	db.free()

func test_list_resource_files_and_type() -> void:
	var db = GameDB.new()
	var files := db.list_resource_files()
	assert_true(files.size() > 0, "资源库应能列出资源文件")
	assert_true(files.has("pic/啤酒.png"), "应包含 pic/啤酒.png")
	assert_eq(db.get_resource_type("pic/啤酒.png"), "image", "图片分类应为 image")
	assert_eq(db.get_resource_type("sfx/我的世界拾取物品.mp3"), "audio", "音频分类应为 audio")
	assert_eq(db.get_resource_type("theme/theme1.tres"), "godot", "Godot 资源分类应为 godot")
	assert_true(db.is_resource_file("pic/啤酒.png"), "is_resource_file 对已知类型应判真")
	assert_true(not db.is_resource_file("readme.txt"), "is_resource_file 对未知类型应判假")
	db.free()
