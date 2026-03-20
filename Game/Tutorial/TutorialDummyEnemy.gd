@tool
extends Node2D
class_name TutorialDummyEnemy

@export var body_size := Vector2(28.0, 56.0):
	set(value):
		body_size = value
		queue_redraw()
@export var body_color := Color(1.0, 0.36, 0.36, 1.0):
	set(value):
		body_color = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	draw_rect(rect, body_color)
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size - Vector2(10.0, 10.0)), body_color.darkened(0.45))

func defeat_from(direction: Vector2) -> void:
	var push_direction := direction.normalized()
	if push_direction == Vector2.ZERO:
		push_direction = Vector2.RIGHT

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + push_direction * 70.0 + Vector2(0.0, -26.0), 0.22)
	tween.tween_property(self, "rotation", rotation + push_direction.x * 0.5, 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
