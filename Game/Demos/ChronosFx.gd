extends CanvasLayer
class_name ChronosFx

@export var chromatic_rect_path: NodePath = NodePath("ShadersParent/Shaders/ChromaticRect")
@export var tint_rect_path: NodePath = NodePath("ShadersParent/Shaders/TintRect")
@export_range(0.0, 12.0, 0.1) var active_chromatic_strength := 5.0
@export var active_tint_color := Color(0.56, 0.8, 1.0, 0.12)
@export_range(0.1, 20.0, 0.1) var enter_speed := 8.0
@export_range(0.1, 20.0, 0.1) var exit_speed := 10.0
@export_range(0.0, 1.0, 0.01) var enter_pulse_strength := 0.28
@export_range(0.0, 1.0, 0.01) var exit_pulse_strength := 0.18
@export_range(0.1, 30.0, 0.1) var pulse_fade_speed := 8.0

var _chromatic_rect: ColorRect
var _tint_rect: ColorRect
var _chromatic_material: ShaderMaterial
var _shaders_parent: Node2D
var _shaders_root: Node2D
var _base_chromatic_strength := 0.0
var _current_chromatic_strength := 0.0
var _blend := 0.0
var _pulse := 0.0
var _was_chronos_enabled := false
var _last_viewport_size := Vector2.ZERO

func _ready() -> void:
	_chromatic_rect = get_node_or_null(chromatic_rect_path) as ColorRect
	_tint_rect = get_node_or_null(tint_rect_path) as ColorRect
	_shaders_root = _chromatic_rect.get_parent() as Node2D if _chromatic_rect != null else null
	_shaders_parent = _shaders_root.get_parent() as Node2D if _shaders_root != null else null
	if _chromatic_rect != null and _chromatic_rect.material is ShaderMaterial:
		_chromatic_material = _chromatic_rect.material as ShaderMaterial
		var current_value: Variant = _chromatic_material.get_shader_parameter("MAX_DIST_PX")
		if current_value is float:
			_base_chromatic_strength = current_value
			_current_chromatic_strength = current_value

	if _tint_rect != null:
		_tint_rect.color = Color(active_tint_color.r, active_tint_color.g, active_tint_color.b, 0.0)
	_update_layout()
	_was_chronos_enabled = Chronos.is_chronos_enabled()

func _process(_delta: float) -> void:
	_update_layout()

	var real_delta := Chronos.get_real_delta()
	if real_delta <= 0.0:
		return

	var chronos_enabled := Chronos.is_chronos_enabled()
	if chronos_enabled != _was_chronos_enabled:
		_pulse = maxf(_pulse, enter_pulse_strength if chronos_enabled else exit_pulse_strength)
		_was_chronos_enabled = chronos_enabled
	_pulse = move_toward(_pulse, 0.0, pulse_fade_speed * real_delta)

	var target_blend := 1.0 if chronos_enabled else 0.0
	var blend_speed := enter_speed if target_blend > _blend else exit_speed
	_blend = move_toward(_blend, target_blend, blend_speed * real_delta)

	var target_chromatic_strength := lerpf(_base_chromatic_strength, active_chromatic_strength, _blend) + active_chromatic_strength * _pulse
	_current_chromatic_strength = move_toward(_current_chromatic_strength, target_chromatic_strength, blend_speed * real_delta * 8.0)
	if _chromatic_material != null:
		_chromatic_material.set_shader_parameter("MAX_DIST_PX", _current_chromatic_strength)

	if _tint_rect != null:
		var tint_alpha := clampf(active_tint_color.a * _blend + _pulse * 0.18, 0.0, 1.0)
		_tint_rect.color = Color(active_tint_color.r, active_tint_color.g, active_tint_color.b, tint_alpha)

func _update_layout() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var visible_rect := viewport.get_visible_rect()
	var viewport_size := visible_rect.size
	if viewport_size == Vector2.ZERO or viewport_size.is_equal_approx(_last_viewport_size):
		return
	_last_viewport_size = viewport_size

	if _shaders_parent != null:
		_shaders_parent.position = visible_rect.position + viewport_size * 0.5
	if _shaders_root != null:
		_shaders_root.position = -viewport_size * 0.5

	if _chromatic_rect != null:
		_chromatic_rect.position = Vector2.ZERO
		_chromatic_rect.size = viewport_size
	if _tint_rect != null:
		_tint_rect.position = Vector2.ZERO
		_tint_rect.size = viewport_size
