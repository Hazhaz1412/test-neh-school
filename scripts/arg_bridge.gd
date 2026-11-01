extends Node
# Keeps the game linked to the local web stack; the game plays the same without it.
const SESSION_FILE := ".config/neh-school/hub.json"
const RETRY_SECONDS := 2.0
const SYNC_SECONDS := 0.5
var world: Node3D
var socket: WebSocketPeer
var linked := false
var last_state := ""
var clock := 0.0
var bang: AudioStreamPlayer
var lens: Node

func _ready() -> void:
	bang = AudioStreamPlayer.new()
	bang.stream = load("res://assets/audio/door_bang.wav")
	add_child(bang)
	lens = preload("res://scripts/phone_lens.gd").new()
	lens.name = "PhoneLens"
	lens.world = world
	lens.bridge = self
	add_child(lens)
	set_process(not OS.get_cmdline_args().has("--script"))

func _process(delta: float) -> void:
	clock -= delta
	if socket == null:
		if clock <= 0.0:
			clock = RETRY_SECONDS
			_connect()
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not linked:
				linked = true
				last_state = ""
			while socket.get_available_packet_count() > 0:
				_receive(socket.get_packet().get_string_from_utf8())
			if clock <= 0.0:
				clock = SYNC_SECONDS
				_send_state()
		WebSocketPeer.STATE_CLOSED:
			socket = null
			linked = false
			lens.set_active(false)
			clock = RETRY_SECONDS

func _connect() -> void:
	var path := OS.get_environment("NEH_HUB_SESSION")
	if path.is_empty():
		var home := OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")
		path = home.path_join(SESSION_FILE)
	if not FileAccess.file_exists(path):
		return
	var session = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not session is Dictionary or not session.has("port") or not session.has("token"):
		return
	var peer := WebSocketPeer.new()
	peer.outbound_buffer_size = 1 << 20
	if peer.connect_to_url("ws://127.0.0.1:%d/game?token=%s" % [int(session.port), session.token]) == OK:
		socket = peer

func _send_state() -> void:
	var story: Node3D = world.progression
	var state := JSON.stringify({"type": "state", "evidence": story.evidence.keys(), "stage": story.Stage.keys()[story.stage]})
	if state == last_state:
		return
	last_state = state
	socket.send_text(state)

func _receive(text: String) -> void:
	var message = JSON.parse_string(text)
	if not message is Dictionary:
		return
	if message.get("type") == "door_bang":
		bang.play()
		world.progression.fear.beat()
	if message.get("type") == "lens":
		lens.set_active(message.get("on") == true)
	if message.get("type") == "lens_phone":
		lens.phone_update(message)

# Frames are dropped, never queued: a late picture is worthless on the phone.
func ready_for_frame() -> bool:
	return linked and socket.get_current_outbound_buffered_amount() == 0

func send_text(text: String) -> void:
	if linked:
		socket.send_text(text)

func send_frame(jpeg: PackedByteArray) -> void:
	socket.send(jpeg, WebSocketPeer.WRITE_MODE_BINARY)
