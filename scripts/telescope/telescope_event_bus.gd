extends RefCounted
# Layer 3: Decoupled Event Bus, Two-Layer Unlock System & Secret Room Clue Dispatch.
# Dispatches reward, key (`key_with_tag.glb` / `room_key`), safe (`new_evidence`),
# and secret room (`next_clue`) events completely independently without mutating
# or touching any main story state variables (`GameProgress`).

signal dome_locked(constellation_id: String, star_count: int)
signal astronomical_lock_opened(payload: Dictionary)
signal observatory_drawer_opened(payload: Dictionary)
signal safe_unlocked(payload: Dictionary)
signal secret_room_opened(payload: Dictionary)
signal lens_core_picked_up(payload: Dictionary)
signal lens_core_installed(payload: Dictionary)
signal item_granted(item_id: String, metadata: Dictionary)
signal achievement_unlocked(achievement_id: String, metadata: Dictionary)
signal event_published(event_name: String, payload: Dictionary)

const ITEM_LENS_CORE := "telescope_lens_core"
const ITEM_STAR_COMPASS := "star_compass"
const ITEM_ROOM_KEY := "room_key"
const ITEM_NEW_EVIDENCE := "new_evidence"
const ITEM_NEXT_CLUE := "next_clue"
const ACH_STAR_GUIDE := "ach_star_guide"
const EXPECTED_PASSCODE := "598418"
const META_KEY := "_telescope_event_bus"

var _listeners := {}
var _granted_items := {}
var _unlocked_achievements := {}
var _completed_constellations := {}
var _lens_installed := false
var _drawer_opened := false
var _safe_opened := false
var _secret_room_opened := false
var _history: Array[Dictionary] = []

static func instance() -> RefCounted:
	var loop := Engine.get_main_loop()
	if loop != null and loop.has_meta(META_KEY):
		var existing = loop.get_meta(META_KEY)
		if existing != null:
			return existing
	var script: Script = load("res://scripts/telescope/telescope_event_bus.gd")
	var bus: RefCounted = script.new()
	if loop != null:
		loop.set_meta(META_KEY, bus)
	return bus

func reset() -> void:
	_listeners.clear()
	_granted_items.clear()
	_unlocked_achievements.clear()
	_completed_constellations.clear()
	_lens_installed = false
	_drawer_opened = false
	_safe_opened = false
	_secret_room_opened = false
	_history.clear()

func subscribe(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	var list: Array = _listeners[event_name]
	if not list.has(callback):
		list.append(callback)

func unsubscribe(event_name: String, callback: Callable) -> void:
	if _listeners.has(event_name):
		(_listeners[event_name] as Array).erase(callback)

func publish(event_name: String, payload: Dictionary = {}) -> void:
	var record := {
		"event": event_name,
		"payload": payload.duplicate(true),
		"timestamp_ms": Time.get_ticks_msec()
	}
	_history.append(record)
	event_published.emit(event_name, payload)
	if _listeners.has(event_name):
		for callback: Callable in (_listeners[event_name] as Array).duplicate():
			if callback.is_valid():
				callback.call(payload)

func notify_dome_locked(constellation_id: String, star_count: int) -> void:
	dome_locked.emit(constellation_id, star_count)
	publish("dome_locked", {"constellation_id": constellation_id, "star_count": star_count})

func dispatch_lock_opened(constellation_id: String, eta: float, optimal_length: float, player_length: float, algorithm: String, passcode_digits := "") -> Dictionary:
	var lock_payload := {
		"constellation_id": constellation_id,
		"eta": eta,
		"optimal_length": optimal_length,
		"player_length": player_length,
		"algorithm": algorithm,
		"passcode_digits": passcode_digits,
		"reward_item": ITEM_STAR_COMPASS,
		"achievement": ACH_STAR_GUIDE
	}
	_completed_constellations[constellation_id] = lock_payload
	astronomical_lock_opened.emit(lock_payload)
	publish("astronomical_lock_opened", lock_payload)

	var item_meta := {
		"item_id": ITEM_STAR_COMPASS,
		"name": "La bàn Tinh tú",
		"constellation_id": constellation_id,
		"eta": eta
	}
	_granted_items[ITEM_STAR_COMPASS] = item_meta
	item_granted.emit(ITEM_STAR_COMPASS, item_meta)
	publish("item_granted", item_meta)

	var ach_meta := {
		"achievement_id": ACH_STAR_GUIDE,
		"title": "Người dẫn đường các vì sao",
		"constellation_id": constellation_id,
		"eta": eta
	}
	_unlocked_achievements[ACH_STAR_GUIDE] = ach_meta
	achievement_unlocked.emit(ACH_STAR_GUIDE, ach_meta)
	publish("achievement_unlocked", ach_meta)

	if _completed_constellations.size() >= 3 and not _drawer_opened:
		_open_observatory_drawer()

	return lock_payload

func _open_observatory_drawer() -> void:
	_drawer_opened = true
	var key_meta := {
		"item_id": ITEM_ROOM_KEY,
		"model": "res://assets/models/telescope/key_with_tag.glb",
		"name": "Chìa khóa có thẻ (key_with_tag) mở Căn phòng bí mật",
		"solved_count": _completed_constellations.size()
	}
	_granted_items[ITEM_ROOM_KEY] = key_meta
	item_granted.emit(ITEM_ROOM_KEY, key_meta)
	publish("item_granted", key_meta)
	observatory_drawer_opened.emit(key_meta)
	publish("observatory_drawer_opened", key_meta)

func attempt_safe_unlock(entered_code: String) -> Dictionary:
	var clean_code := entered_code.strip_edges()
	if not _drawer_opened:
		return {
			"unlocked": false,
			"reason": "drawer_locked",
			"message": "Cần quét và giải đủ 3 chòm sao trên bầu trời để mở ngăn kéo lấy Chìa khóa trước!"
		}
	if clean_code != EXPECTED_PASSCODE:
		return {
			"unlocked": false,
			"reason": "wrong_code",
			"message": "Mã số '%s' không khớp! Hãy tra Sách hướng dẫn 12 cung theo đúng thứ tự Dị thường #1 → #2 → #3." % clean_code
		}
	_safe_opened = true
	var evidence_meta := {
		"item_id": ITEM_NEW_EVIDENCE,
		"name": "Chứng cứ mới (Hồ sơ Mật mã Thiên văn)",
		"passcode": clean_code,
		"drawer_key_used": ITEM_ROOM_KEY
	}
	_granted_items[ITEM_NEW_EVIDENCE] = evidence_meta
	item_granted.emit(ITEM_NEW_EVIDENCE, evidence_meta)
	publish("item_granted", evidence_meta)
	safe_unlocked.emit(evidence_meta)
	publish("safe_unlocked", evidence_meta)
	return {
		"unlocked": true,
		"item_id": ITEM_NEW_EVIDENCE,
		"passcode": clean_code,
		"message": "Đã mở Két sắt Đài quan sát! Nhận được: Chứng cứ mới (new_evidence) + Chìa khóa phòng bí mật (key_with_tag)."
	}

# Grants the Telescope Optical Lens Core (`telescope_lens_core`) found in the Fairground (`Khu vui chơi`).
func pickup_lens_core() -> Dictionary:
	var lens_meta := {
		"item_id": ITEM_LENS_CORE,
		"name": "Cục Thấu Kính Tinh Tú (Lõi Thấu Kính Kính Thiên Văn)",
		"location": "fairground_plaza"
	}
	_granted_items[ITEM_LENS_CORE] = lens_meta
	item_granted.emit(ITEM_LENS_CORE, lens_meta)
	publish("item_granted", lens_meta)
	lens_core_picked_up.emit(lens_meta)
	publish("lens_core_picked_up", lens_meta)
	return lens_meta

# Attaches `telescope_lens_core` onto the broken telescope to repair it.
func install_lens_core() -> bool:
	if _lens_installed:
		return true
	if not has_item(ITEM_LENS_CORE):
		return false
	_lens_installed = true
	var payload := {
		"item_id": ITEM_LENS_CORE,
		"repaired": true,
		"message": "Đã gắn Cục Thấu Kính Tinh Tú vào Kính Thiên Văn! Hệ thống quang học đã hoạt động trở lại."
	}
	lens_core_installed.emit(payload)
	publish("lens_core_installed", payload)
	return true

func is_lens_installed() -> bool:
	return _lens_installed

# Uses the key (`key_with_tag.glb` / `room_key`) to unlock the Secret Room and grant the Next Clue (`next_clue`).
func unlock_secret_room() -> Dictionary:
	if not has_item(ITEM_ROOM_KEY):
		return {
			"unlocked": false,
			"reason": "missing_key",
			"message": "Cửa Căn phòng bí mật đang khóa! Hãy giải đủ 3 chòm sao trên Kính Thiên Văn để nhận Chìa khóa có thẻ (key_with_tag)."
		}
	_secret_room_opened = true
	var clue_meta := {
		"item_id": ITEM_NEXT_CLUE,
		"name": "Manh mối tiếp theo (Bản đồ Mật thất & Nhật ký Đài quan sát)",
		"used_key": ITEM_ROOM_KEY,
		"key_model": "res://assets/models/telescope/key_with_tag.glb"
	}
	_granted_items[ITEM_NEXT_CLUE] = clue_meta
	item_granted.emit(ITEM_NEXT_CLUE, clue_meta)
	publish("item_granted", clue_meta)
	secret_room_opened.emit(clue_meta)
	publish("secret_room_opened", clue_meta)
	return {
		"unlocked": true,
		"item_id": ITEM_NEXT_CLUE,
		"message": "Đã dùng Chìa khóa (key_with_tag) mở Căn phòng bí mật và thu thập Manh mối tiếp theo!"
	}

func has_item(item_id: String) -> bool:
	return _granted_items.has(item_id)

func has_achievement(achievement_id: String) -> bool:
	return _unlocked_achievements.has(achievement_id)

func is_constellation_completed(constellation_id: String) -> bool:
	return _completed_constellations.has(constellation_id)

func completed_count() -> int:
	return _completed_constellations.size()

func is_drawer_opened() -> bool:
	return _drawer_opened

func is_safe_opened() -> bool:
	return _safe_opened

func is_secret_room_opened() -> bool:
	return _secret_room_opened

func history() -> Array[Dictionary]:
	return _history
