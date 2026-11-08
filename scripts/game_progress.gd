extends RefCounted
# How far the player has come. A chapter opens the moment it is reached and stays open.
const CHAPTERS := [
	{"id": "prologue", "title": "Tiền truyện", "text": "Căn nhà số 14, Hẻm 31", "scene": "res://scenes/home.tscn", "meta": "prologue"},
	{"id": "night0", "title": "Đêm 0 · Giấc mơ", "text": "Lẻn vào Trường NEH", "scene": "res://scenes/school_runtime.tscn"},
	{"id": "corridor", "title": "Đêm 0 · Hành lang đỏ", "text": "Chạy khỏi lũ ma", "scene": "res://scenes/school_runtime.tscn", "meta": "chapter_corridor"},
	{"id": "home", "title": "Tỉnh giấc · 05:52", "text": "Chỉ là một giấc mơ?", "scene": "res://scenes/home.tscn"},
	{"id": "town", "title": "Ngày 1 · Khu phố", "text": "Tiếp tục ở giờ đã dừng", "scene": "res://scenes/town.tscn"},
	{"id": "night1", "title": "Đêm 1 · Ghen Tị", "text": "Con quỷ đầu tiên", "scene": "res://scenes/school_runtime.tscn", "meta": "night_one"},
]
const METAS := ["prologue", "chapter_corridor", "night_one", "next_survival_run"]
static var path := "user://progress.cfg"
static var recording := true

static func _file() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(path)
	return file

static func index_of(id: String) -> int:
	for i in range(CHAPTERS.size()):
		if CHAPTERS[i].id == id:
			return i
	return -1

static func furthest() -> int:
	return _file().get_value("progress", "furthest", -1)

static func latest() -> int:
	return _file().get_value("progress", "latest", -1)

static func unlocked(index: int) -> bool:
	return index == 0 or index <= furthest()

# Test tools drive scenes in any order, so only a real session records anything.
static func mark(id: String) -> void:
	if not recording or OS.get_cmdline_args().has("--script") and path == "user://progress.cfg":
		return
	var file := _file()
	var index := index_of(id)
	file.set_value("progress", "furthest", maxi(index, file.get_value("progress", "furthest", -1)))
	file.set_value("progress", "latest", index)
	file.save(path)

static func wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func enter(tree: SceneTree, index: int) -> void:
	for meta in METAS:
		if tree.has_meta(meta):
			tree.remove_meta(meta)
	var chapter: Dictionary = CHAPTERS[index]
	if chapter.has("meta"):
		tree.set_meta(chapter.meta, true)
	tree.paused = false
	tree.change_scene_to_file(chapter.scene)
