extends SceneTree

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"


func _initialize() -> void:
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var catalog := M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE,
		registry
	)
	var formal_order: OrderDefinition = registry.find_order(
		M1DebugScenarioCatalog.ORDER_WHITE_NOISE
	)
	var formal_planet: PlanetDefinition = registry.find_planet(
		M1ProgressRules.PLANET_WHITE_NOISE
	)
	if (
		definition == null
		or formal_order == null
		or formal_planet == null
		or definition.target_scene_path
		!= M1DebugScenarioCatalog.WHITE_NOISE_ROUTE_SCENE_PATH
		or formal_order.content_readiness
		!= OrderDefinition.ContentReadiness.PLAYABLE
		or formal_planet.content_readiness
		!= PlanetDefinition.ContentReadiness.PLAYABLE
		or formal_planet.flight_scene_path
		!= M1DebugScenarioCatalog.WHITE_NOISE_ROUTE_SCENE_PATH
	):
		printerr(
			"[t120-debug-smoke] FAIL: debug entry changed formal White Noise readiness."
		)
		quit(1)
		return
	var before_order: String = formal_order.resource_path
	var before_planet: String = formal_planet.resource_path
	var progress: GameProgressData = catalog.build_initial_progress(
		definition,
		registry
	)
	if (
		progress == null
		or not progress.is_valid()
		or formal_order.resource_path != before_order
		or formal_planet.resource_path != before_planet
	):
		printerr(
			"[t120-debug-smoke] FAIL: debug snapshot mutated formal resources."
		)
		quit(1)
		return
	print(
		"[t120-debug-smoke] PASS: isolated entry preserves formal "
		+ "White Noise PLAYABLE resources."
	)
	quit(0)
