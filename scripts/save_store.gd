class_name AstralSaveStore
extends RefCounted

const VERSION = 1
const MAX_BYTES = 4 * 1024 * 1024
var error = ""
var recovered = false
var primary_verified = false
var directory: String

func _init(custom_directory: String = "") -> void:
	directory = custom_directory
	if directory.is_empty():
		directory = OS.get_environment("ASTRAL_SAVE_DIR")
	if directory.is_empty():
		directory = OS.get_user_data_dir()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("version", 0) != VERSION:
		return {}
	if not parsed.get("profile") is Dictionary or not parsed.get("run") is Dictionary:
		return {}
	return parsed

func candidates() -> Array:
	error = ""
	recovered = false
	var result = []
	for name in ["save.json", "save.backup.json"]:
		var path = directory.path_join(name)
		var data = _read(path)
		if not data.is_empty():
			result.append({"data": data, "backup": name != "save.json"})
		elif FileAccess.file_exists(path):
			error = "A save could not be read. Your existing files have been preserved."
	return result

func write(profile: Dictionary, run: Dictionary) -> bool:
	error = ""
	var mkdir_error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK:
		error = "Could not create the save folder (%s)." % mkdir_error
		return false
	var path = directory.path_join("save.json")
	var temporary = directory.path_join("save.pending.json")
	var serialized = JSON.stringify({"version": VERSION, "profile": profile, "run": run})
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Could not write your save. Your previous save is safe."
		return false
	file.store_string(serialized)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or _read(temporary).is_empty():
		error = "Save verification failed. Your previous save is safe."
		return false
	# Preserve a valid previous generation, never replace the backup with corrupt bytes.
	if primary_verified and not _read(path).is_empty():
		var backup_temp = directory.path_join("save.backup.pending.json")
		if DirAccess.copy_absolute(path, backup_temp) != OK or DirAccess.rename_absolute(backup_temp, directory.path_join("save.backup.json")) != OK:
			error = "Could not preserve the backup. Your previous save is safe."
			return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		error = "Could not replace the save. Your previous save is safe."
		return false
	primary_verified = true
	return true
