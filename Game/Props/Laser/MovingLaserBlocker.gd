extends AnimatableBody2D
class_name MovingLaserBlocker

@export var travel_offset := Vector2(0.0, -120.0)
@export_range(0.1, 8.0, 0.1) var cycle_duration := 2.2
@export var blocker_size := Vector2(28.0, 84.0)
@export var blocker_color := Color(0.18, 0.82, 1.0, 1.0)

var _start_position := Vector2.ZERO

func _ready() -> void:
	_start_position = global_position
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if cycle_duration <= 0.01:
		return

	var t := Chronos.get_elapsed_time_for_group(&"world")
	var phase := pingpong(t / cycle_duration, 1.0)
	global_position = _start_position + travel_offset * phase

func _draw() -> void:
	var rect := Rect2(-blocker_size * 0.5, blocker_size)
	draw_rect(rect, blocker_color)
	draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), blocker_color.darkened(0.35))
