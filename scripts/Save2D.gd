extends RefCounted
const Core = preload("res://scripts/Blocks2D.gd")
# Keep the earlier 3D project saves untouched instead of overwriting incompatible data.
const ROOT := "user://blocks_2d/"
const AUTOSAVE := ROOT + "autosave.json"

static func ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

static func write_safe(path: String, document: Dictionary) -> bool:
	if not Core.document_valid(document):
		return false
	ensure_directory()
	var temp := path + ".tmp"
	var stream := FileAccess.open(temp,FileAccess.WRITE)
	if stream == null:
		return false
	stream.store_string(JSON.stringify(document))
	stream.flush()
	stream.close()
	if not FileAccess.file_exists(temp):
		return false
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup)) != OK:
			return false
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))
	if error != OK:
		if not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup),ProjectSettings.globalize_path(path))
		return false
	return true

static func read_document(path: String) -> Dictionary:
	for target in [path,path+".bak"]:
		if not FileAccess.file_exists(target):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(target)) != OK:
			continue
		if Core.document_valid(parser.data):
			return parser.data
	return {}

static func autosave(parts: Array, title: String, guide_id: int = -1, step: int = 0) -> bool:
	return write_safe(AUTOSAVE,{"version":2,"title":title,"pieces":parts,"guide_id":guide_id,"step":step})

static func load_autosave() -> Dictionary:
	return read_document(AUTOSAVE)

static func save_to_gallery(parts: Array, title: String) -> bool:
	ensure_directory()
	var target := ROOT + "work_%d_%d.json" % [int(Time.get_unix_time_from_system()),randi_range(1000,9999)]
	return write_safe(target,{"version":2,"title":title,"pieces":parts,"guide_id":-1,"step":0})

static func list_gallery() -> Array:
	ensure_directory()
	var files := DirAccess.open(ROOT)
	if files == null:
		return []
	var result: Array = []
	for filename in files.get_files():
		if filename.begins_with("work_") and filename.ends_with(".json"):
			var path := ROOT+filename
			var data := read_document(path)
			if not data.is_empty():
				data["file"] = path
				result.append(data)
	result.sort_custom(func(a: Dictionary,b: Dictionary): return str(a["file"]) > str(b["file"]))
	return result
