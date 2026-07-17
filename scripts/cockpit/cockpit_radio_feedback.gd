class_name CockpitRadioFeedback
extends Control

const INDICATOR_ON: Color = Color("77c9c4")
const INDICATOR_OFF: Color = Color("394d5d")
const WAVE_ON: Color = Color("e7a85b")
const WAVE_OFF: Color = Color("526474")
const PULSE_SPEED: float = 5.0
const BAR_COUNT: int = 5

var _active: bool = false
var _pulse_phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	advance_animation(delta)


func set_active(active: bool) -> void:
	_active = active
	if not _active:
		_pulse_phase = 0.0
	set_process(_active)
	queue_redraw()


func is_active() -> bool:
	return _active


func get_pulse_phase() -> float:
	return _pulse_phase


func advance_animation(delta: float) -> void:
	if not _active or delta <= 0.0:
		return
	_pulse_phase = fposmod(_pulse_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	var center_y: float = size.y * 0.5
	var indicator_color: Color = INDICATOR_ON if _active else INDICATOR_OFF
	var indicator_radius: float = 3.0
	if _active:
		indicator_radius += 0.65 * (sin(_pulse_phase) * 0.5 + 0.5)
	draw_circle(Vector2(6.0, center_y), indicator_radius, indicator_color)

	var wave_color: Color = WAVE_ON if _active else WAVE_OFF
	var wave_start_x: float = 17.0
	var wave_end_x: float = maxf(size.x - 2.0, wave_start_x)
	draw_line(
		Vector2(wave_start_x, center_y),
		Vector2(wave_end_x, center_y),
		wave_color.darkened(0.38),
		1.0
	)
	for bar_index: int in BAR_COUNT:
		var ratio: float = float(bar_index) / maxf(float(BAR_COUNT - 1), 1.0)
		var bar_x: float = lerpf(wave_start_x + 3.0, wave_end_x - 3.0, ratio)
		var amplitude: float = 1.5
		if _active:
			amplitude = 3.0 + 2.6 * (
				sin(_pulse_phase + float(bar_index) * 1.35) * 0.5 + 0.5
			)
		draw_line(
			Vector2(bar_x, center_y - amplitude),
			Vector2(bar_x, center_y + amplitude),
			wave_color,
			1.5
		)
