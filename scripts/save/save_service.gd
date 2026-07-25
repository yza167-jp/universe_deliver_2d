class_name SaveServiceModel
extends Node

signal progress_saved
signal progress_loaded(source: LoadSource)
signal backup_recovery_used
signal save_availability_changed(availability: SaveAvailability)

enum SaveAvailability {
	NONE,
	PRIMARY,
	BACKUP,
	INVALID,
}

enum LoadSource {
	NONE,
	PRIMARY,
	BACKUP,
}

const DEFAULT_SAVE_PATH: String = "user://savegame.json"
const DEFAULT_TEMP_PATH: String = "user://savegame.tmp"
const DEFAULT_BACKUP_PATH: String = "user://savegame.backup.json"
const DEFAULT_REJECTED_PATH: String = "user://savegame.invalid.json"

const WARNING_NONE: StringName = &""
const WARNING_BACKUP_RECOVERY: StringName = &"backup_recovery"
const WARNING_SCHEMA_MIGRATED: StringName = &"schema_migrated"

const ERROR_NONE: StringName = &""
const ERROR_NO_SAVE: StringName = &"no_save"
const ERROR_INVALID_SAVE: StringName = &"invalid_save"
const ERROR_READ_FAILED: StringName = &"read_failed"
const ERROR_WRITE_FAILED: StringName = &"write_failed"
const ERROR_RUNTIME_UNAVAILABLE: StringName = &"runtime_unavailable"

const AUTOSAVE_STAGES: PackedInt32Array = [
	SceneRouterService.Stage.STATION,
	SceneRouterService.Stage.RESULTS,
]
const DEBUG_ROUTE_ARGUMENTS: PackedStringArray = [
	"--flight-lab",
	"--delivery-lab",
	"--red-sand-route",
	"--red-sand-arrival",
	"--red-sand-results",
]

var storage_path: String = DEFAULT_SAVE_PATH
var temporary_path: String = DEFAULT_TEMP_PATH
var backup_path: String = DEFAULT_BACKUP_PATH
var rejected_path: String = DEFAULT_REJECTED_PATH

var game_state_override: GameStateModel
var scene_router_override: SceneRouterService
var automatic_saves_enabled: bool = false
var availability: SaveAvailability = SaveAvailability.NONE
var last_load_source: LoadSource = LoadSource.NONE
var last_error_code: StringName = ERROR_NONE
var last_warning_code: StringName = WARNING_NONE
var last_error: String = ""

var _save_queued: bool = false
var _suspend_automatic_saves: bool = false


func _ready() -> void:
	set_automatic_saves_enabled(
		should_enable_automatic_saves(
			OS.get_cmdline_args(),
			OS.get_cmdline_user_args()
		)
	)


func set_automatic_saves_enabled(enabled: bool) -> void:
	var game_state: GameStateModel = _resolve_game_state()
	if game_state != null:
		if enabled and not game_state.persistent_state_changed.is_connected(
			_on_persistent_state_changed
		):
			game_state.persistent_state_changed.connect(_on_persistent_state_changed)
		elif not enabled and game_state.persistent_state_changed.is_connected(
			_on_persistent_state_changed
		):
			game_state.persistent_state_changed.disconnect(_on_persistent_state_changed)
	var scene_router: SceneRouterService = _resolve_scene_router()
	if scene_router != null:
		if enabled and not scene_router.stage_changed.is_connected(_on_stage_changed):
			scene_router.stage_changed.connect(_on_stage_changed)
		elif not enabled and scene_router.stage_changed.is_connected(_on_stage_changed):
			scene_router.stage_changed.disconnect(_on_stage_changed)
	automatic_saves_enabled = enabled


static func should_enable_automatic_saves(
	command_line_args: PackedStringArray,
	user_arguments: PackedStringArray
) -> bool:
	for argument: String in command_line_args:
		if argument in ["--headless", "--script", "--editor", "--import"]:
			return false
		if argument.begins_with("res://tests/"):
			return false
	for debug_argument: String in DEBUG_ROUTE_ARGUMENTS:
		if user_arguments.has(debug_argument):
			return false
	return true


func configure_storage_paths(
	primary: String,
	temporary: String,
	backup: String,
	rejected: String
) -> void:
	storage_path = primary
	temporary_path = temporary
	backup_path = backup
	rejected_path = rejected
	_clear_result_state()


func reset_storage_paths() -> void:
	configure_storage_paths(
		DEFAULT_SAVE_PATH,
		DEFAULT_TEMP_PATH,
		DEFAULT_BACKUP_PATH,
		DEFAULT_REJECTED_PATH
	)


func start_new_game() -> bool:
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return _fail(ERROR_RUNTIME_UNAVAILABLE, "GameState is unavailable.")
	_suspend_automatic_saves = true
	game_state.reset_runtime_state()
	_suspend_automatic_saves = false
	return save_progress()


func save_progress() -> bool:
	_clear_result_state()
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return _fail(ERROR_RUNTIME_UNAVAILABLE, "GameState is unavailable.")
	var progress: GameProgressData = GameProgressData.capture(game_state)
	if not progress.is_valid():
		return _fail(ERROR_WRITE_FAILED, progress.validation_error)
	var serialized_text: String = JSON.stringify(progress.to_dictionary(), "\t", true)

	_remove_file_if_present(temporary_path)
	var write_error: Error = _write_text(temporary_path, serialized_text)
	if write_error != OK:
		return _fail(
			ERROR_WRITE_FAILED,
			"Could not write temporary save %s (error %d)." % [temporary_path, write_error]
		)
	var temporary_result: Dictionary = _read_progress_file(temporary_path)
	if not _result_has_valid_progress(temporary_result):
		return _fail(
			ERROR_WRITE_FAILED,
			"Temporary save validation failed: %s" % temporary_result.get("error", "unknown")
		)

	var primary_result: Dictionary = _read_progress_file(storage_path)
	if bool(primary_result.get("exists", false)):
		var primary_text: String = String(primary_result.get("raw_text", ""))
		if _result_has_valid_progress(primary_result):
			var backup_error: Error = _write_text(backup_path, primary_text)
			if backup_error != OK:
				return _fail(
					ERROR_WRITE_FAILED,
					"Could not rotate the last valid save to backup (error %d)." % backup_error
				)
			var backup_result: Dictionary = _read_progress_file(backup_path)
			if not _result_has_valid_progress(backup_result):
				return _fail(
					ERROR_WRITE_FAILED,
					"Backup validation failed: %s" % backup_result.get("error", "unknown")
				)
		else:
			var preserve_error: Error = _write_text(rejected_path, primary_text)
			if preserve_error != OK:
				return _fail(
					ERROR_WRITE_FAILED,
					"Could not preserve the rejected primary save (error %d)." % preserve_error
				)

	if not _replace_primary_with_temporary(serialized_text):
		return false
	var committed_result: Dictionary = _read_progress_file(storage_path)
	if not _result_has_valid_progress(committed_result):
		return _fail(
			ERROR_WRITE_FAILED,
			"Committed save validation failed: %s" % committed_result.get("error", "unknown")
		)
	availability = SaveAvailability.PRIMARY
	save_availability_changed.emit(availability)
	progress_saved.emit()
	return true


func refresh_save_availability() -> SaveAvailability:
	_clear_result_state()
	var primary_result: Dictionary = _read_progress_file(storage_path)
	if _result_has_valid_progress(primary_result):
		availability = SaveAvailability.PRIMARY
		var primary_progress: GameProgressData = primary_result.get("progress") as GameProgressData
		if primary_progress != null and primary_progress.was_migrated():
			last_warning_code = WARNING_SCHEMA_MIGRATED
		save_availability_changed.emit(availability)
		return availability

	var backup_result: Dictionary = _read_progress_file(backup_path)
	if _result_has_valid_progress(backup_result):
		availability = SaveAvailability.BACKUP
		last_warning_code = WARNING_BACKUP_RECOVERY
		last_error = _combine_read_errors(primary_result, backup_result)
		save_availability_changed.emit(availability)
		return availability

	var any_save_exists: bool = (
		bool(primary_result.get("exists", false))
		or bool(backup_result.get("exists", false))
	)
	if any_save_exists:
		availability = SaveAvailability.INVALID
		last_error_code = ERROR_INVALID_SAVE
		last_error = _combine_read_errors(primary_result, backup_result)
	else:
		availability = SaveAvailability.NONE
		last_error_code = ERROR_NO_SAVE
		last_error = "No primary or backup save exists."
	save_availability_changed.emit(availability)
	return availability


func load_progress() -> bool:
	var current_availability: SaveAvailability = refresh_save_availability()
	var selected_path: String = ""
	match current_availability:
		SaveAvailability.PRIMARY:
			selected_path = storage_path
		SaveAvailability.BACKUP:
			selected_path = backup_path
		_:
			return false
	var read_result: Dictionary = _read_progress_file(selected_path)
	var progress: GameProgressData = read_result.get("progress") as GameProgressData
	if progress == null or not progress.is_valid():
		return _fail(
			ERROR_READ_FAILED,
			"Selected save became unreadable: %s" % read_result.get("error", "unknown")
		)
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return _fail(ERROR_RUNTIME_UNAVAILABLE, "GameState is unavailable.")
	_suspend_automatic_saves = true
	var applied: bool = progress.apply_to(game_state)
	_suspend_automatic_saves = false
	if not applied:
		return _fail(ERROR_READ_FAILED, "Decoded progress could not be applied to GameState.")
	last_load_source = (
		LoadSource.BACKUP
		if current_availability == SaveAvailability.BACKUP
		else LoadSource.PRIMARY
	)
	progress_loaded.emit(last_load_source)
	if last_load_source == LoadSource.BACKUP:
		backup_recovery_used.emit()
	return true


func has_continue_option() -> bool:
	return refresh_save_availability() in [
		SaveAvailability.PRIMARY,
		SaveAvailability.BACKUP,
	]


func _on_persistent_state_changed() -> void:
	if not automatic_saves_enabled or _suspend_automatic_saves or _save_queued:
		return
	var scene_router: SceneRouterService = _resolve_scene_router()
	if scene_router == null or scene_router.current_stage not in AUTOSAVE_STAGES:
		return
	_save_queued = true
	call_deferred("_flush_queued_save")


func _on_stage_changed(_previous_stage: int, current_stage: int) -> void:
	if (
		not automatic_saves_enabled
		or _suspend_automatic_saves
		or _save_queued
		or current_stage not in AUTOSAVE_STAGES
	):
		return
	_save_queued = true
	call_deferred("_flush_queued_save")


func _flush_queued_save() -> void:
	_save_queued = false
	if _suspend_automatic_saves or not automatic_saves_enabled:
		return
	if not save_progress():
		push_warning("Automatic progress save failed: %s" % last_error)


func _replace_primary_with_temporary(serialized_text: String) -> bool:
	if FileAccess.file_exists(storage_path):
		var remove_error: Error = _remove_file_if_present(storage_path)
		if remove_error != OK:
			return _fail(
				ERROR_WRITE_FAILED,
				"Could not replace the previous primary save (error %d)." % remove_error
			)
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(storage_path)
	)
	if rename_error == OK:
		return true
	var fallback_error: Error = _write_text(storage_path, serialized_text)
	if fallback_error != OK:
		return _fail(
			ERROR_WRITE_FAILED,
			"Could not commit the primary save (rename %d, write %d)." % [
				rename_error,
				fallback_error,
			]
		)
	_remove_file_if_present(temporary_path)
	return true


func _read_progress_file(path: String) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"exists": FileAccess.file_exists(path),
		"progress": null,
		"error": "",
		"raw_text": "",
	}
	if not bool(result["exists"]):
		result["error"] = "File does not exist: %s." % path
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["error"] = "Could not open %s (error %d)." % [
			path,
			FileAccess.get_open_error(),
		]
		return result
	var raw_text: String = file.get_as_text()
	file.close()
	result["raw_text"] = raw_text
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(raw_text)
	if parse_error != OK:
		result["error"] = "JSON parse failed at line %d: %s" % [
			json.get_error_line(),
			json.get_error_message(),
		]
		return result
	if not json.data is Dictionary:
		result["error"] = "Save root must be a JSON object."
		return result
	var progress: GameProgressData = GameProgressData.from_dictionary(json.data as Dictionary)
	if not progress.is_valid():
		result["error"] = progress.validation_error
		return result
	result["progress"] = progress
	return result


func _write_text(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error


func _remove_file_if_present(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _result_has_valid_progress(result: Dictionary) -> bool:
	var progress: GameProgressData = result.get("progress") as GameProgressData
	return progress != null and progress.is_valid()


func _combine_read_errors(primary_result: Dictionary, backup_result: Dictionary) -> String:
	return "Primary: %s Backup: %s" % [
		String(primary_result.get("error", "unknown")),
		String(backup_result.get("error", "unknown")),
	]


func _clear_result_state() -> void:
	last_error_code = ERROR_NONE
	last_warning_code = WARNING_NONE
	last_error = ""
	last_load_source = LoadSource.NONE


func _fail(error_code: StringName, message: String) -> bool:
	last_error_code = error_code
	last_error = message
	return false


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService
