extends ProjectTestSuite

const PROFILE_PATH: String = (
	"res://data/tuning/white_noise_storm_profile_m1.tres"
)
const MODULE_PATH: String = (
	"res://data/modules/high_voltage_shielding.tres"
)
const CORE_INPUT_ACTIONS: Array[StringName] = [
	&"flight_throttle",
	&"flight_brake",
	&"flight_pitch_up",
	&"flight_pitch_down",
	&"flight_boost",
	&"flight_restart",
	&"flight_controls_help",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var profile: WhiteNoiseStormProfile = load(
		PROFILE_PATH
	) as WhiteNoiseStormProfile
	var module: ShipModuleDefinition = load(
		MODULE_PATH
	) as ShipModuleDefinition
	expect_true(profile != null, "T-121 storm profile must load.", failures)
	expect_true(module != null, "T-121 shielding module must load.", failures)
	if profile == null or module == null:
		return failures
	_test_profile_contract(profile, failures)
	_test_state_and_pulses(profile, failures)
	_test_shielding_resource_authority(profile, module, failures)
	_test_fixed_delta_determinism(profile, failures)
	_test_input_map_is_untouched(profile, failures)
	return failures


func _test_profile_contract(
	profile: WhiteNoiseStormProfile,
	failures: Array[String]
) -> void:
	expect_true(
		profile.validate().is_empty()
		and is_equal_approx(profile.trigger_distance, 17000.0)
		and is_equal_approx(profile.warning_end_distance, 17700.0)
		and is_equal_approx(profile.recovery_start_distance, 22000.0)
		and is_equal_approx(profile.end_distance, 23000.0)
		and is_equal_approx(profile.warning_duration_seconds, 2.4)
		and is_equal_approx(profile.active_duration_seconds, 12.0)
		and is_equal_approx(profile.recovery_duration_seconds, 2.8)
		and is_equal_approx(profile.get_nominal_duration_seconds(), 17.2),
		"T-121 must keep one validated 17-23 km deterministic phase contract.",
		failures
	)
	expect_true(
		profile.interference_intensity < 1.0
		and profile.visibility_intensity < 0.8
		and profile.pulse_interval_seconds >= 3.0,
		"The blizzard must remain intense but readable and pulse-based.",
		failures
	)


func _test_state_and_pulses(
	profile: WhiteNoiseStormProfile,
	failures: Array[String]
) -> void:
	var model := WhiteNoiseInterferenceModel.new()
	expect_true(model.configure(profile), "T-121 model must configure.", failures)
	model.reset(0.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.CLEAR
		and model.step(1.0, 16999.0) == 0,
		"Blizzard must stay clear before the fixed route window.",
		failures
	)
	model.step(0.0, 17000.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.WARNING,
		"Crossing 17000 m must start the warning.",
		failures
	)
	model.step(2.4, 17699.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.WARNING,
		"Warning must require both time and route distance.",
		failures
	)
	model.step(0.0, 17700.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.ACTIVE,
		"Warning must transition to active at its deterministic gate.",
		failures
	)
	expect_true(
		model.step(3.99, 19000.0) == 0
		and model.step(0.01, 19000.0) == 1
		and model.step(0.01, 19000.0) == 0,
		"High-voltage punishment must occur by interval, never every frame.",
		failures
	)
	model.step(8.0, 22000.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.RECOVERY
		and model.get_total_pulse_count() == 3,
		"Active state must settle three deterministic pulses before recovery.",
		failures
	)
	model.step(2.8, 22999.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.RECOVERY,
		"Recovery cannot be skipped by waiting before the exit gate.",
		failures
	)
	model.step(0.0, 23000.0)
	expect_true(
		model.get_state() == WhiteNoiseInterferenceModel.State.CLEAR,
		"Signal must clear at the end of the fixed window.",
		failures
	)
	var held_model := WhiteNoiseInterferenceModel.new()
	held_model.configure(profile)
	held_model.reset(19000.0)
	held_model.debug_set_state(WhiteNoiseInterferenceModel.State.ACTIVE)
	expect_true(
		held_model.step(16.0, 19000.0) == 4
		and held_model.get_state()
		== WhiteNoiseInterferenceModel.State.ACTIVE,
		"Stopping inside the active window must not wait out later pulses.",
		failures
	)


func _test_shielding_resource_authority(
	profile: WhiteNoiseStormProfile,
	module: ShipModuleDefinition,
	failures: Array[String]
) -> void:
	var configuration: Dictionary[StringName, StringName] = (
		ShipLoadoutRules.create_default_configuration()
	)
	var module_catalog: Array[ShipModuleDefinition] = [module]
	var unshielded_multiplier: float = (
		FlightElectromagneticProtectionModel
		.get_electromagnetic_interference_multiplier(
			configuration,
			module_catalog
		)
	)
	configuration[ShipLoadoutRules.SLOT_DEFENSE] = module.id
	var shielded_interference_multiplier: float = (
		FlightElectromagneticProtectionModel
		.get_electromagnetic_interference_multiplier(
			configuration,
			module_catalog
		)
	)
	var shielded_damage_multiplier: float = (
		FlightElectromagneticProtectionModel
		.get_high_voltage_damage_multiplier(
			configuration,
			module_catalog
		)
	)
	var model := WhiteNoiseInterferenceModel.new()
	model.configure(profile)
	model.reset(profile.trigger_distance)
	model.debug_set_state(WhiteNoiseInterferenceModel.State.ACTIVE)
	expect_true(
		is_equal_approx(unshielded_multiplier, 1.0)
		and is_equal_approx(shielded_interference_multiplier, 0.45)
		and is_equal_approx(shielded_damage_multiplier, 0.60)
		and is_equal_approx(
			model.get_effective_interference(unshielded_multiplier),
			0.86
		)
		and is_equal_approx(
			model.get_effective_interference(
				shielded_interference_multiplier
			),
			0.387
		),
		"T-121 must consume 0.45/0.60 only through the installed module Resource.",
		failures
	)


func _test_fixed_delta_determinism(
	profile: WhiteNoiseStormProfile,
	failures: Array[String]
) -> void:
	var pulse_counts: PackedInt32Array = []
	var final_states: PackedInt32Array = []
	for fps: int in [30, 60, 120]:
		var model := WhiteNoiseInterferenceModel.new()
		model.configure(profile)
		model.reset(0.0)
		var delta: float = 1.0 / float(fps)
		for step_index: int in roundi(28.0 * float(fps)):
			var elapsed: float = float(step_index + 1) * delta
			var route_distance: float = 16800.0 + 300.0 * elapsed
			model.step(delta, route_distance)
		pulse_counts.append(model.get_total_pulse_count())
		final_states.append(model.get_state())
	expect_true(
		pulse_counts == PackedInt32Array([3, 3, 3])
		and final_states == PackedInt32Array([
			WhiteNoiseInterferenceModel.State.CLEAR,
			WhiteNoiseInterferenceModel.State.CLEAR,
			WhiteNoiseInterferenceModel.State.CLEAR,
		]),
		"30/60/120 FPS must produce the same state and pulse result.",
		failures
	)


func _test_input_map_is_untouched(
	profile: WhiteNoiseStormProfile,
	failures: Array[String]
) -> void:
	var before: String = _input_signature()
	var model := WhiteNoiseInterferenceModel.new()
	model.configure(profile)
	model.reset(profile.trigger_distance)
	for step_index: int in 120:
		model.step(1.0 / 60.0, 17000.0 + float(step_index) * 20.0)
	expect_true(
		before == _input_signature(),
		"Electromagnetic interference must never rewrite core Input Map actions.",
		failures
	)


func _input_signature() -> String:
	var rows: Array[String] = []
	for action: StringName in CORE_INPUT_ACTIONS:
		var event_rows: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action):
			event_rows.append(event.as_text())
		rows.append("%s=%s" % [action, ",".join(event_rows)])
	return "|".join(rows)
