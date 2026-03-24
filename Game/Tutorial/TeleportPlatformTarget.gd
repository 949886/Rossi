@tool
extends AnimatableBody2D
class_name TeleportPlatformTarget

@export var size := Vector2(80.0, 20.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var platform_color := Color(0.4, 0.92, 1.0, 1.0):
	set(value):
		platform_color = value
		queue_redraw()
@export var inner_color := Color(0.1, 0.18, 0.26, 1.0):
	set(value):
		inner_color = value
		queue_redraw()
@export var travel_offset := Vector2(256.0, -48.0)
@export_range(0.2, 6.0, 0.1) var travel_duration := 2.4

var _start_position := Vector2.ZERO
var _collision_shape: CollisionShape2D

func _ready() -> void:
	_start_position = global_position
	_collision_shape = ($"CollisionShape2D" as CollisionShape2D) if has_node(^"CollisionShape2D") else null
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	_update_shape()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if travel_duration <= 0.01:
		return

	var time := Time.get_ticks_msec() / 1000.0
	var phase := pingpong(float(time / travel_duration), 1.0)
	global_position = _start_position + travel_offset * phase

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, platform_color)
	draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), inner_color)

func can_accept_shuriken() -> bool:
	return true

func get_shuriken_attach_position(hit_position: Vector2, _hit_normal: Vector2) -> Vector2:
	var local_hit := to_local(hit_position)
	local_hit.x = clampf(local_hit.x, -size.x * 0.42, size.x * 0.42)
	local_hit.y = -size.y * 0.5
	return to_global(local_hit)

func get_shuriken_attach_normal(_fallback_normal: Vector2) -> Vector2:
	return Vector2.UP

func reset_platform() -> void:
	global_position = _start_position

func _update_shape() -> void:
	if _collision_shape == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_collision_shape.shape = rectangle
