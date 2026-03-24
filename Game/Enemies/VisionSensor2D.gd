@tool
extends Area2D
class_name VisionSensor2D

signal detected_target_changed(target)
signal visual_debug_toggled(enabled: bool)

@export_group("Detection")
## Max detection distance measured from the sensor origin.
@export var detection_radius := 300
## Horizontal field-of-view angle in degrees. Use 360 for omni-directional sensing.
@export_range(1.0, 360.0, 1.0) var fov_angle_degrees := 360.0
## Default local offset applied when the sensor node is still at the owner's origin.
@export var vision_offset := Vector2.ZERO
## Only nodes in this group can be considered valid targets.
@export var target_group := "Player"
## Physics mask used by the line-of-sight raycast to detect blockers.
@export_flags_2d_physics var line_of_sight_collision_mask := 1
## When enabled, candidates must pass an unobstructed line-of-sight check.
@export var require_line_of_sight := true
## Master switch for overlap sensing and line-of-sight evaluation.
@export var sensor_enabled := true

@export_group("Visual Persistence")
## Keeps the last seen target position for a short time after visual contact is lost.
@export var enable_visual_persistence := false
## How long the last seen position remains available after the target is lost.
@export_range(0.0, 10.0, 0.1) var visual_persistence_duration := 1.2
## Distance threshold used by AI when it reaches the remembered position.
@export_range(0.0, 64.0, 1.0) var visual_persistence_arrival_tolerance := 12.0

@export_group("Vertical Sweep")
## Enables an up/down sweeping motion for directional vision checks and debug rendering.
@export var enable_vertical_sweep := false
## Maximum angular offset above and below the base facing direction.
@export_range(0.0, 89.0, 0.5) var sweep_max_angle_degrees := 18.0
## Sweep speed in cycles per second.
@export_range(0.0, 10.0, 0.1) var sweep_frequency := 0.8
## Phase offset used to desync multiple sensors.
@export_range(0.0, TAU, 0.01) var sweep_phase_offset := 0.0

@export_group("Visual Debug")
@export var show_visual_debug := true
@export var fill_alpha := 0.12
@export var outline_alpha := 0.96
@export_range(0.1, 5.0, 0.1) var outline_width := 0.5
@export var use_crisp_outline := true
@export var show_direction_indicator := false
@export var show_target_line := true
@export_range(0.1, 5.0, 0.1) var target_line_width := 0.5

@export_group("Editor Preview")
@export var editor_preview_enabled := true
@export_enum("idle", "patrol", "chase", "windup", "attack", "recover", "hit", "dead", "respawn", "return_home") var editor_preview_state := "idle"
@export_range(-1, 1, 2) var editor_preview_facing_direction := 1

@export_group("State Colors")
@export var idle_color := Color(0.33, 0.9, 0.55, 1.0)
@export var patrol_color := Color(0.24, 0.72, 1.0, 1.0)
@export var chase_color := Color(1.0, 0.72, 0.26, 1.0)
@export var windup_color := Color(1.0, 0.46, 0.26, 1.0)
@export var attack_color := Color(1.0, 0.2, 0.2, 1.0)
@export var recover_color := Color(0.95, 0.56, 0.25, 1.0)
@export var hit_color := Color(1.0, 0.42, 0.78, 1.0)
@export var dead_color := Color(0.45, 0.45, 0.45, 0.95)
@export var respawn_color := Color(0.4, 0.95, 1.0, 1.0)
@export var return_home_color := Color(0.95, 0.92, 0.32, 1.0)

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var _visual_state_name := "idle"
var _facing_direction := 1
var _debug_target: Node2D
var _sweep_time := 0.0
var _current_sweep_angle_radians := 0.0
var _visual_persistence_position := Vector2.ZERO
var _visual_persistence_timer := 0.0
var _has_visual_persistence_position := false

func _ready() -> void:
	add_to_group("VisionSensor")
	_apply_scene_debug_override()
	_apply_default_offset_if_needed()
	_apply_detection_shape()
	_apply_editor_preview()
	set_sensor_enabled(sensor_enabled)
	_refresh_process_state()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_detection_shape()
		_apply_editor_preview()
		_update_sweep(_delta)
		if editor_preview_enabled and show_visual_debug:
			queue_redraw()
		return

	_update_sweep(_delta)
	_update_visual_persistence(_delta)
	if show_visual_debug or enable_vertical_sweep:
		queue_redraw()

func find_best_target(validate_target: Callable = Callable()) -> Node2D:
	if not sensor_enabled:
		set_debug_target(null)
		return null

	var nearest_target: Node2D
	var nearest_distance := INF
	for body in get_overlapping_bodies():
		if not _is_candidate_valid(body, validate_target):
			continue
		var body_2d := body as Node2D
		if body_2d == null:
			continue
		var distance_to_body := global_position.distance_to(body_2d.global_position)
		if distance_to_body < nearest_distance:
			nearest_distance = distance_to_body
			nearest_target = body_2d

	var previous_target = _debug_target
	if nearest_target != null:
		track_visible_target(nearest_target)
	set_debug_target(nearest_target)
	if previous_target != _debug_target:
		detected_target_changed.emit(_debug_target)
	return nearest_target

func has_line_of_sight(target: Node2D) -> bool:
	if not sensor_enabled or target == null or not is_instance_valid(target):
		return false
	if not require_line_of_sight:
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, line_of_sight_collision_mask)
	var excludes: Array[RID] = [get_rid()]
	var parent_node := get_parent()
	if parent_node is CollisionObject2D:
		excludes.append(parent_node.get_rid())
	query.exclude = excludes
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true

	var collider = result.get("collider")
	return collider == target

func set_detection_radius(radius: float) -> void:
	detection_radius = maxf(radius, 1.0)
	_apply_detection_shape()
	queue_redraw()

func set_sensor_enabled(enabled: bool) -> void:
	sensor_enabled = enabled
	monitoring = enabled
	monitorable = enabled
	if not enabled:
		clear_visual_persistence()
	else:
		_refresh_process_state()
	queue_redraw()

func set_visual_state(state_name: String) -> void:
	if Engine.is_editor_hint() and editor_preview_enabled:
		editor_preview_state = state_name
	if _visual_state_name == state_name:
		return
	_visual_state_name = state_name
	queue_redraw()

func set_facing_direction(direction: int) -> void:
	var next_direction := 1 if direction >= 0 else -1
	if Engine.is_editor_hint() and editor_preview_enabled:
		editor_preview_facing_direction = next_direction
	if _facing_direction == next_direction:
		return
	_facing_direction = next_direction
	queue_redraw()

func set_debug_target(target: Node2D) -> void:
	if _debug_target == target:
		return
	_debug_target = target
	queue_redraw()

func track_visible_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	_visual_persistence_position = target.global_position
	if not _uses_visual_persistence():
		return
	_has_visual_persistence_position = true
	_visual_persistence_timer = visual_persistence_duration
	_refresh_process_state()
	queue_redraw()

func has_visual_persistence_target() -> bool:
	return _uses_visual_persistence() and _has_visual_persistence_position and _visual_persistence_timer > 0.0

func get_visual_persistence_position() -> Vector2:
	return _visual_persistence_position

func get_visual_persistence_arrival_tolerance() -> float:
	return maxf(visual_persistence_arrival_tolerance, 0.0)

func clear_visual_persistence() -> void:
	var was_active := _has_visual_persistence_position or _visual_persistence_timer > 0.0
	_has_visual_persistence_position = false
	_visual_persistence_timer = 0.0
	if was_active:
		_refresh_process_state()
		queue_redraw()

func set_visual_debug_enabled(enabled: bool) -> void:
	show_visual_debug = enabled
	_refresh_process_state()
	queue_redraw()
	visual_debug_toggled.emit(enabled)

func is_visual_debug_enabled() -> bool:
	return show_visual_debug

func _draw() -> void:
	if not show_visual_debug:
		return
	if Engine.is_editor_hint() and not editor_preview_enabled:
		return

	var shape := _get_shape_resource()
	if shape == null:
		return

	var color := _get_state_color(_visual_state_name)
	var fill_color := Color(color.r, color.g, color.b, fill_alpha)
	var outline_color := Color(color.r, color.g, color.b, outline_alpha)
	var center := Vector2.ZERO

	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		if _uses_cone_visual():
			_draw_sector(center, radius, fill_color, outline_color)
		else:
			draw_circle(center, radius, fill_color)
			draw_arc(center, radius, 0.0, TAU, 48, outline_color, outline_width, _is_outline_antialiased())
		_draw_direction_indicator(center, radius, outline_color)
	elif shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		var rect := Rect2(center - rect_shape.size * 0.5, rect_shape.size)
		draw_rect(rect, fill_color)
		draw_rect(rect, outline_color, false, outline_width)
		_draw_direction_indicator(center, minf(rect_shape.size.x, rect_shape.size.y) * 0.5, outline_color)

	var has_target_line := false
	var target_line_position := Vector2.ZERO
	if is_instance_valid(_debug_target):
		has_target_line = true
		target_line_position = _debug_target.global_position
	elif has_visual_persistence_target():
		has_target_line = true
		target_line_position = _visual_persistence_position

	if show_target_line and has_target_line:
		draw_line(center, to_local(target_line_position), outline_color.lightened(0.2), target_line_width, true)

func _is_candidate_valid(candidate: Variant, validate_target: Callable) -> bool:
	if not sensor_enabled:
		return false
	if not (candidate is Node2D) or not is_instance_valid(candidate):
		return false
	if target_group != "" and not candidate.is_in_group(target_group):
		return false
	if _uses_fov() and not _is_in_fov(candidate.global_position):
		return false
	if require_line_of_sight and not has_line_of_sight(candidate):
		return false
	if validate_target.is_valid() and not bool(validate_target.call(candidate)):
		return false
	return true

func _uses_fov() -> bool:
	return fov_angle_degrees < 359.0

func _uses_cone_visual() -> bool:
	return _uses_fov() and _get_shape_resource() is CircleShape2D

func _is_in_fov(world_position: Vector2) -> bool:
	if not _uses_fov():
		return true

	var to_point := world_position - global_position
	if to_point.length_squared() <= 0.001:
		return true

	var forward := Vector2.RIGHT.rotated(_get_current_forward_angle())
	var angle_to_target := absf(rad_to_deg(forward.angle_to(to_point.normalized())))
	return angle_to_target <= fov_angle_degrees * 0.5

func _apply_detection_shape() -> void:
	var shape := _get_shape_resource()
	if shape is CircleShape2D:
		(shape as CircleShape2D).radius = detection_radius

	if collision_shape != null:
		collision_shape.position = Vector2.ZERO

func _get_shape_resource() -> Shape2D:
	if collision_shape == null:
		return null
	return collision_shape.shape

func _get_state_color(state_name: String) -> Color:
	match state_name:
		"idle":
			return idle_color
		"patrol":
			return patrol_color
		"chase":
			return chase_color
		"windup":
			return windup_color
		"attack":
			return attack_color
		"recover":
			return recover_color
		"hit":
			return hit_color
		"dead":
			return dead_color
		"respawn":
			return respawn_color
		"return_home":
			return return_home_color
	return idle_color

func _draw_sector(center: Vector2, radius: float, fill_color: Color, outline_color: Color) -> void:
	var points := _build_sector_points(center, radius)
	if points.size() < 3:
		return

	draw_colored_polygon(points, fill_color)

	var edge_points := PackedVector2Array()
	for i in range(1, points.size()):
		edge_points.append(points[i])
	draw_polyline(edge_points, outline_color, outline_width, _is_outline_antialiased())
	draw_line(center, points[1], outline_color, outline_width, _is_outline_antialiased())
	draw_line(center, points[points.size() - 1], outline_color, outline_width, _is_outline_antialiased())

func _build_sector_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(center)

	var half_angle := deg_to_rad(fov_angle_degrees * 0.5)
	var facing_angle := _get_current_forward_angle()
	var start_angle := facing_angle - half_angle
	var end_angle := facing_angle + half_angle
	var segment_count := maxi(12, int(ceil(fov_angle_degrees / 8.0)))

	for index in range(segment_count + 1):
		var t := float(index) / float(segment_count)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return points

func _draw_direction_indicator(center: Vector2, radius: float, color: Color) -> void:
	if not show_direction_indicator:
		return

	var arrow_width := outline_width
	var direction := Vector2.RIGHT.rotated(_get_current_forward_angle())
	var start := center + direction * minf(radius * 0.15, 8.0)
	var finish := center + direction * minf(radius * 0.8, 42.0)
	draw_line(start, finish, color, arrow_width, _is_outline_antialiased())

	var arrow_normal := direction.orthogonal()
	var arrow_back := finish - direction * 7.0
	draw_line(finish, arrow_back + arrow_normal * 4.0, color, arrow_width, _is_outline_antialiased())
	draw_line(finish, arrow_back - arrow_normal * 4.0, color, arrow_width, _is_outline_antialiased())

func _apply_scene_debug_override() -> void:
	if Engine.is_editor_hint():
		return
	for controller in get_tree().get_nodes_in_group("EncounterController"):
		var debug_enabled = controller.get("vision_debug_enabled")
		if debug_enabled is bool:
			show_visual_debug = debug_enabled
			return

func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return

	_visual_state_name = editor_preview_state
	_facing_direction = 1 if editor_preview_facing_direction >= 0 else -1

func _apply_default_offset_if_needed() -> void:
	if position == Vector2.ZERO and vision_offset != Vector2.ZERO:
		position = vision_offset

func _is_outline_antialiased() -> bool:
	return not use_crisp_outline

func _refresh_process_state() -> void:
	set_process(show_visual_debug or enable_vertical_sweep or has_visual_persistence_target() or Engine.is_editor_hint())

func _update_sweep(delta: float) -> void:
	if not enable_vertical_sweep or sweep_max_angle_degrees <= 0.0 or sweep_frequency <= 0.0:
		_current_sweep_angle_radians = 0.0
		return

	_sweep_time += maxf(delta, 0.0)
	var phase := _sweep_time * TAU * sweep_frequency + sweep_phase_offset
	_current_sweep_angle_radians = deg_to_rad(sin(phase) * sweep_max_angle_degrees)

func _get_current_forward_angle() -> float:
	var base_angle := 0.0 if _facing_direction >= 0 else PI
	return base_angle + _current_sweep_angle_radians

func _uses_visual_persistence() -> bool:
	return sensor_enabled and enable_visual_persistence and visual_persistence_duration > 0.0

func _update_visual_persistence(delta: float) -> void:
	if not _has_visual_persistence_position:
		return
	if not _uses_visual_persistence():
		clear_visual_persistence()
		return
	if _visual_persistence_timer <= 0.0:
		clear_visual_persistence()
		return

	_visual_persistence_timer = maxf(0.0, _visual_persistence_timer - maxf(delta, 0.0))
	if _visual_persistence_timer <= 0.0:
		clear_visual_persistence()
