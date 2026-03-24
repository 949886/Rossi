@tool
extends Node2D

@export_group("Beam")
@export_range(1.0, 4000.0, 1.0) var max_length := 320.0
@export_range(1.0, 64.0, 0.5) var beam_width := 8.0
@export_range(0.01, 1.0, 0.01) var hit_padding := 2.0
@export var starts_enabled := true

@export_group("Visuals")
@export var active_colors: Array[Color] = [
	Color(1.0, 0.2, 0.2, 0.96),
	Color(1.0, 0.85, 0.2, 0.96),
	Color(0.2, 1.0, 0.8, 0.96),
	Color(0.45, 0.65, 1.0, 0.96),
]
@export var disabled_color := Color(1.0, 0.15, 0.15, 0.95)
@export var show_rounded_caps := true
@export_range(0.1, 20.0, 0.1) var color_cycle_speed := 4.0
@export_range(2.0, 64.0, 1.0) var dash_length := 18.0
@export_range(2.0, 64.0, 1.0) var dash_gap := 10.0

@export_group("Collision")
@export_flags_2d_physics var blocker_collision_mask := 1
@export_flags_2d_physics var damage_collision_mask := 1
@export var collide_with_areas := false
@export var collide_with_bodies := true

var _damage_area: Area2D
var _damage_shape: CollisionShape2D
var _current_length := 0.0
var _is_enabled := false

var is_enabled: bool:
	get:
		return _is_enabled

func _ready() -> void:
	add_to_group("EncounterResettable")
	_damage_area = get_node("DamageArea")
	_damage_shape = get_node("DamageArea/CollisionShape2D")

	_is_enabled = starts_enabled
	set_process(Engine.is_editor_hint())
	set_physics_process(true)
	_update_beam()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_beam()

func _physics_process(_delta: float) -> void:
	_update_beam()

	if Engine.is_editor_hint() or not _is_enabled or not _damage_area.monitoring:
		return

	for body in _damage_area.get_overlapping_bodies():
		if body is CharacterBody2D:
			if body.has_method("interact_with"):
				body.interact_with(self)
			elif body.has_method("InteractWith"):
				body.InteractWith(self)

func _draw() -> void:
	if _current_length <= 0.1:
		return

	var beam_vector: Vector2 = _get_local_direction() * _current_length
	var beam_color: Color = _get_animated_active_color() if _is_enabled else disabled_color

	if _is_enabled:
		draw_line(Vector2.ZERO, beam_vector, beam_color, beam_width, true)
		if show_rounded_caps:
			draw_circle(Vector2.ZERO, beam_width * 0.5, beam_color)
			draw_circle(beam_vector, beam_width * 0.5, beam_color)
		return

	var beam_dir: Vector2 = _get_local_direction()
	var distance: float = 0.0
	while distance < _current_length:
		var segment_start: float = distance
		var segment_end: float = minf(distance + dash_length, _current_length)
		var start: Vector2 = beam_dir * segment_start
		var finish: Vector2 = beam_dir * segment_end
		draw_line(start, finish, beam_color, beam_width * 0.75, true)
		distance += dash_length + dash_gap

func set_enabled(enabled: bool) -> void:
	if _is_enabled == enabled:
		return

	_is_enabled = enabled
	_update_beam()

func toggle() -> void:
	set_enabled(not _is_enabled)

func reset_for_encounter() -> void:
	set_enabled(starts_enabled)

func _update_beam() -> void:
	_current_length = _compute_visible_length()
	_update_damage_shape()
	queue_redraw()

func _compute_visible_length() -> float:
	var normalized_direction: Vector2 = _get_world_direction()
	var start: Vector2 = global_position
	var finish: Vector2 = start + normalized_direction * max_length
	var state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var excludes: Array[RID] = [_damage_area.get_rid()]

	for _attempt in range(8):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, finish, blocker_collision_mask)
		query.exclude = excludes
		query.collide_with_areas = collide_with_areas
		query.collide_with_bodies = collide_with_bodies

		var result: Dictionary = state.intersect_ray(query)
		if result.is_empty():
			return max_length

		var collider = result.get("collider")
		if collider is CollisionObject2D and collider.is_in_group("Player"):
			excludes.append(collider.get_rid())
			continue

		var hit_point: Vector2 = result["position"]
		var length: float = start.distance_to(hit_point) - hit_padding
		return length

	return max_length

func _update_damage_shape() -> void:
	_damage_area.collision_mask = damage_collision_mask
	_damage_area.monitoring = _is_enabled
	_damage_area.monitorable = _damage_area.monitoring

	var rectangle_shape: RectangleShape2D = _damage_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return

	if _current_length <= 0.1:
		rectangle_shape.size = Vector2(0.01, beam_width)
		_damage_shape.position = Vector2.ZERO
		return

	_damage_area.rotation = 0.0
	rectangle_shape.size = Vector2(_current_length, beam_width + 6.0)
	_damage_shape.position = Vector2(_current_length * 0.5, 0.0)

func _get_local_direction() -> Vector2:
	return Vector2.RIGHT

func _get_world_direction() -> Vector2:
	return global_transform.x.normalized()

func _get_animated_active_color() -> Color:
	if active_colors.is_empty():
		return Color.WHITE

	if active_colors.size() == 1:
		return active_colors[0]

	var time: float = Time.get_ticks_msec() / 1000.0
	var cycle: float = time * color_cycle_speed
	var from_index: int = posmod(int(floor(cycle)), active_colors.size())
	var to_index: int = (from_index + 1) % active_colors.size()
	var weight: float = cycle - floor(cycle)
	return active_colors[from_index].lerp(active_colors[to_index], weight)
