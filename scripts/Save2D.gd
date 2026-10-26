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

static func autosave(parts: Array, title: String, guide_id: int = -1, step: int = 0, gallery_file: String = "") -> bool:
	# Remember which collected work is currently open. Old autosave data without
	# this field remains readable and is matched by content on its next save.
	return write_safe(AUTOSAVE,{"version":2,"title":title,"pieces":parts,"guide_id":guide_id,"step":step,"gallery_file":gallery_file})

static func load_autosave() -> Dictionary:
	return read_document(AUTOSAVE)

static func gallery_path_valid(path: String) -> bool:
	var name := path.get_file()
	return path == ROOT+name and name.begins_with("work_") and name.ends_with(".json")

static func work_signature(parts: Array, title: String) -> String:
	# Compare appearance, not random file names or the IDs assigned while placing
	# bricks. This also finds the duplicates created by previous app versions.
	var features: Array[String] = []
	for part in parts:
		features.append("%d,%d,%d,%d,%d" % [
			int(part.get("kind",0)),int(part.get("color",0)),
			int(part.get("x",0)),int(part.get("y",0)),Core.rotation_of(part)])
	features.sort()
	return JSON.stringify([title,features])

static func save_work(parts: Array, title: String, existing_file: String = "") -> String:
	var document := {"version":2,"title":title,"pieces":parts,"guide_id":-1,"step":0}
	if not Core.document_valid(document):
		return ""
	# A work opened from the gallery is edited in place. Merely opening an old
	# work, or saving it again, must never create a second gallery entry.
	if gallery_path_valid(existing_file):
		var original := read_document(existing_file)
		if not original.is_empty():
			var previous_signature := work_signature(original["pieces"],str(original.get("title","")))
			if previous_signature == work_signature(parts,title):
				return existing_file
			# Preserve historical duplicate files, but link them to the
			# canonical work before its content diverges. Otherwise each old
			# duplicate resurfaces as a separate item after every edit.
			var identical_copies: Array = []
			for other in _all_gallery_files():
				if str(other["file"]) != existing_file and work_signature(other["pieces"],str(other.get("title",""))) == previous_signature:
					identical_copies.append(other)
			if not write_safe(existing_file,document):
				return ""
			for duplicate in identical_copies:
				var alias: Dictionary = duplicate.duplicate(true)
				alias.erase("file")
				alias["alias_of"] = existing_file
				write_safe(str(duplicate["file"]),alias)
			return existing_file
	var signature := work_signature(parts,title)
	for saved in list_gallery():
		if signature == work_signature(saved["pieces"],str(saved.get("title",""))):
			return str(saved["file"])
	ensure_directory()
	for attempt in 32:
		var target := ROOT+"work_%d_%d.json" % [int(Time.get_unix_time_from_system()),randi_range(1000,999999)]
		if not FileAccess.file_exists(target) and write_safe(target,document):
			return target
	return ""

static func save_to_gallery(parts: Array, title: String) -> bool:
	return not save_work(parts,title).is_empty()

static func _all_gallery_files() -> Array:
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

static func list_gallery() -> Array:
	# Never delete a user's old work. Suppress identical versions and linked
	# historical duplicates; allow an orphaned alias back if its original file
	# is missing so the old artwork can still be recovered.
	var unique: Array = []
	var seen: Dictionary = {}
	for data in _all_gallery_files():
		var origin := str(data.get("alias_of",""))
		if gallery_path_valid(origin) and FileAccess.file_exists(origin):
			continue
		var signature := work_signature(data["pieces"],str(data.get("title","")))
		if seen.has(signature):
			continue
		seen[signature] = true
		unique.append(data)
	return unique
