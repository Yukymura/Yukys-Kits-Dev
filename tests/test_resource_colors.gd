# ================================================================================
# 资源库分类配色 —— 回归测试
#   验证颜色十六进制序列化（to_html）与反序列化（from_string）往返一致，
#   这是 DataImporter 把资源配色持久化到 config.json 的底层机制。
# ================================================================================

@tool
extends McpTestSuite

func suite_name() -> String:
	return "resource_colors"

func test_color_html_roundtrip() -> void:
	var samples: Array = [
		Color(0.27, 0.52, 1.0, 0.25),
		Color(0.22, 0.80, 0.45, 0.25),
		Color(1.0, 0.66, 0.22, 0.25),
		Color(1.0, 0.0, 0.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.0),
	]
	for c in samples:
		var parsed := Color.from_string(c.to_html(true), Color.WHITE)
		assert_true(_color_close(parsed, c),
			"往返不一致: %s -> %s -> %s" % [c, c.to_html(true), parsed])

func _color_close(a: Color, b: Color) -> bool:
	var eps := 0.01
	return absf(a.r - b.r) < eps and absf(a.g - b.g) < eps and absf(a.b - b.b) < eps and absf(a.a - b.a) < eps
