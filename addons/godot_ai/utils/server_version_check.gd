@tool
class_name McpServerVersionCheck
extends RefCounted

## Published v4 compatibility value. Lifecycle owns the authenticated
## handshake and episode transition; this class intentionally owns no timer,
## connection, or manager reference.


static func evaluate(actual_version: String, expected_version: String) -> Dictionary:
	if actual_version.is_empty():
		return {"compatible": false, "reason": "missing_version"}
	var compatible := actual_version == expected_version
	return {
		"compatible": compatible,
		"reason": "" if compatible else "version_mismatch",
	}
