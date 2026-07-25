class_name M1DebugScenarioController
extends RefCounted

const DEBUG_BUILD_VERSION: String = "m1_debug"

var last_error: String = ""

var _game_state: GameStateModel
var _registry: GameDataRegistry
var _scene_router: SceneRouterService
var _scene_container: Node
var _save_service: SaveServiceModel
var _settings_service: SettingsServiceModel
var _express_hud: ExpressOrderHUD
var _status: M1DebugStatus
var _catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
var _definition: M1DebugScenarioDefinition
var _initial_snapshot: GameProgressData
var _express_fixture: OrderDefinition


func configure(
	game_state: GameStateModel,
	registry: GameDataRegistry,
	scene_router: SceneRouterService,
	scene_container: Node,
	save_service: SaveServiceModel,
	settings_service: SettingsServiceModel,
	express_hud: ExpressOrderHUD,
	status: M1DebugStatus
) -> void:
	_game_state = game_state
	_registry = registry
	_scene_router = scene_router
	_scene_container = scene_container
	_save_service = save_service
	_settings_service = settings_service
	_express_hud = express_hud
	_status = status


func start_scenario(scenario_id: StringName) -> bool:
	last_error = ""
	if not _validate_runtime_dependencies():
		return false
	var definition: M1DebugScenarioDefinition = _catalog.get_definition(
		scenario_id,
		_registry
	)
	if definition == null:
		return _fail(_catalog.last_error)
	if not _apply_definition(definition):
		return false
	_definition = definition
	if not _route_target():
		return false
	_refresh_persistent_debug_ui()
	_initial_snapshot = _capture_deterministic_snapshot()
	if _initial_snapshot == null:
		return false
	print(
		(
			"[m1-debug] READY scenario=%s chapter=%s order=%s planet=%s "
			+ "stage=%s autosave=off"
		) % [
			_definition.scenario_id,
			_definition.chapter_id,
			_get_status_order_id(),
			_definition.focus_planet_id,
			SceneRouterService.get_stage_name(_definition.target_stage),
		]
	)
	return true


func reset_scenario() -> bool:
	last_error = ""
	if _definition == null or _initial_snapshot == null:
		return _fail("No active M1 debug scenario can be reset.")
	if not _initial_snapshot.apply_to(_game_state):
		return _fail("M1 debug initial snapshot could not be restored.")
	if not _route_target():
		return false
	_refresh_persistent_debug_ui()
	print("[m1-debug] RESET scenario=%s" % _definition.scenario_id)
	return true


func stop_scenario() -> void:
	if _express_hud != null and _express_hud.is_inside_tree():
		_express_hud.set_order_override(null)
	if _status != null and _status.is_inside_tree():
		_status.hide_scenario()
	_definition = null
	_initial_snapshot = null
	_express_fixture = null


func get_definition() -> M1DebugScenarioDefinition:
	return _definition


func get_initial_state_signature() -> String:
	if _initial_snapshot == null:
		return ""
	return JSON.stringify(_initial_snapshot.to_dictionary())


func get_express_fixture() -> OrderDefinition:
	return _express_fixture


func _apply_definition(definition: M1DebugScenarioDefinition) -> bool:
	var progress: GameProgressData = _catalog.build_initial_progress(
		definition,
		_registry
	)
	if progress == null:
		return _fail(_catalog.last_error)
	if not progress.apply_to(_game_state):
		return _fail("M1 debug progress snapshot could not be applied.")
	_express_fixture = null
	if not definition.active_order_id.is_empty():
		_express_fixture = _build_express_fixture(definition)
		if _express_fixture == null:
			return false
		if not _game_state.accept_order(_express_fixture):
			return _fail(
				"Debug express fixture was rejected: %s."
				% _game_state.last_order_error
			)
	return true


func _build_express_fixture(
	definition: M1DebugScenarioDefinition
) -> OrderDefinition:
	var source: OrderDefinition = _registry.find_order(
		definition.fixture_source_order_id
	)
	if source == null:
		_fail("Debug express source order is unavailable.")
		return null
	var fixture: OrderDefinition = source.duplicate(true) as OrderDefinition
	var fixture_planet: PlanetDefinition = (
		source.destination_planet.duplicate(true) as PlanetDefinition
	)
	if fixture == null or fixture_planet == null:
		_fail("Debug express fixture could not be duplicated.")
		return null
	fixture.id = definition.active_order_id
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture.required_chapter = &""
	fixture.unlock_conditions.clear()
	fixture.story_requirements.clear()
	fixture_planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	fixture_planet.flight_scene_path = (
		M1DebugScenarioCatalog.FLIGHT_LAB_SCENE_PATH
	)
	fixture.destination_planet = fixture_planet
	fixture.planet_id = fixture_planet.id
	return fixture


func _capture_deterministic_snapshot() -> GameProgressData:
	var captured: GameProgressData = GameProgressData.capture(_game_state)
	if not captured.is_valid():
		_fail("M1 debug state is invalid: %s." % captured.validation_error)
		return null
	captured.last_saved_at_unix = 0
	captured.build_version = DEBUG_BUILD_VERSION
	var snapshot: GameProgressData = GameProgressData.from_dictionary(
		captured.to_dictionary()
	)
	if not snapshot.is_valid():
		_fail("M1 debug snapshot is invalid: %s." % snapshot.validation_error)
		return null
	return snapshot


func _route_target() -> bool:
	var switched: bool = _scene_router.debug_switch_to_stage_scene(
		_definition.target_stage,
		_definition.target_scene_path
	)
	if not switched:
		return _fail(
			"M1 debug target could not open: %s." % _scene_router.last_error
		)
	if _definition.target_scene_path == M1DebugScenarioCatalog.CATALOG_SCENE_PATH:
		var catalog_view: M1DebugCatalogView = _find_catalog_view()
		if catalog_view == null:
			return _fail("M1 catalog debug scene did not instantiate.")
		if not catalog_view.configure_focus(
			_registry,
			_definition.catalog_focus_order_id
		):
			return _fail(catalog_view.last_error)
	return true


func _find_catalog_view() -> M1DebugCatalogView:
	if _scene_container == null:
		return null
	for child: Node in _scene_container.get_children():
		if child is M1DebugCatalogView:
			return child as M1DebugCatalogView
	return null


func _refresh_persistent_debug_ui() -> void:
	if _express_hud != null:
		_express_hud.set_order_override(_express_fixture)
		_express_hud.refresh_from_state()
	if _status != null:
		_status.show_scenario(
			_definition,
			_save_service.isolated_debug_session
			and not _save_service.automatic_saves_enabled
		)


func _get_status_order_id() -> StringName:
	if not _definition.active_order_id.is_empty():
		return _definition.active_order_id
	return _definition.catalog_focus_order_id


func _validate_runtime_dependencies() -> bool:
	if (
		_game_state == null
		or _registry == null
		or _scene_router == null
		or _scene_container == null
		or _save_service == null
		or _settings_service == null
		or _express_hud == null
		or _status == null
	):
		return _fail("M1 debug runtime dependencies are unavailable.")
	if (
		not _save_service.isolated_debug_session
		or _save_service.automatic_saves_enabled
	):
		return _fail("M1 debug requires isolated, disabled progress saving.")
	if not _settings_service.isolated_debug_session:
		return _fail("M1 debug requires read-only player settings.")
	if _save_service.get_storage_access_count() != 0:
		return _fail("M1 debug detected access to normal progress storage.")
	if _settings_service.get_storage_write_count() != 0:
		return _fail("M1 debug detected a player-settings write.")
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
