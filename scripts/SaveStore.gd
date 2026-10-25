extends RefCounted
const Logic = preload("res://scripts/BrickLogic.gd")
const ROOT := "user://blocks/"
const AUTO := ROOT + "autosave.json"
const VERSION := 1

static func _ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

static func _write_atomic(path: String, payload: Dictionary) -> bool:
	_ensure_directory()
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	if not FileAccess.file_exists(temp):
		return false
	if FileAccess.file_exists(path):
		var backup := path + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		var old_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup))
		if old_err != OK:
			return false
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))
	return err == OK

static func save_autosave(pieces: Array, title: String, next_id: int, guide_id: int = -1, step: int = 0) -> bool:
	return _write_atomic(AUTO,{"version":VERSION,"pieces":pieces,"title":title,"next_id":next_id,"guide_id":guide_id,"step":step})

static func read_file(path: String) -> Dictionary:
	for actual in [path,path + ".bak"]:
		if not FileAccess.file_exists(actual):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(actual)) != OK:
			continue
		var d: Variant = json.data
		if not (d is Dictionary) or int(d.get("version",-1)) != VERSION or not (d.get("pieces",null) is Array):
			continue
		var all_ids := {}
		var valid := true
		for p in d["pieces"]:
			if not Logic.validate_saved_piece(p) or all_ids.has(int(p["id"])):
				valid = false
				break
			all_ids[int(p["id"])] = true
		if valid and d["pieces"].size() <= Logic.MAX_PIECES and not Logic.has_orphans(d["pieces"]):
			return d
	return {}

static func load_autosave() -> Dictionary:
	return read_file(AUTO)

static func save_work(pieces: Array, title: String) -> String:
	_ensure_directory()
	var id := "work_%d" % Time.get_unix_time_from_system()
	var path := ROOT + id + ".json"
	var ok := _write_atomic(path,{"version":VERSION,"pieces":pieces,"title":title,"next_id":pieces.size()+1,"guide_id":-1,"step":0})
	return path if ok else ""

static func list_works() -> Array[String]:
	_ensure_directory()
	var output: Array[String] = []
	var directory := DirAccess.open(ROOT)
	if directory == null:
		return output
	for file in directory.get_files():
		if file.begins_with("work_") and file.ends_with(".json"):
			output.append(ROOT + file)
	output.sort()
	output.reverse()
	return output

static func delete_work(path: String) -> void:
	if not path.begins_with(ROOT + "work_") or not path.ends_with(".json"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
