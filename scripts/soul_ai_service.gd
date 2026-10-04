extends Node
# Desktop editor demo: reuse one loopback bridge, never put credentials in Godot.
var health: HTTPRequest
var checked := false
var configured := false
func _ready() -> void:
	health = HTTPRequest.new()
	health.timeout = 2
	add_child(health)
	health.request_completed.connect(_health_received)
	if not OS.get_cmdline_args().has("--script"):
		health.request("http://127.0.0.1:8765/health")
func _health_received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	checked = true
	if result == HTTPRequest.RESULT_SUCCESS and status == 200:
		var payload = JSON.parse_string(body.get_string_from_utf8())
		configured = payload is Dictionary and payload.get("service") == "neh-soul-ai" and payload.get("configured") == true
		return
	var script := ProjectSettings.globalize_path("res://tools/soul_ai_server.py")
	if FileAccess.file_exists(script):
		var executable := "python" if OS.has_feature("windows") else "python3"
		OS.create_process(executable, [script], false)
