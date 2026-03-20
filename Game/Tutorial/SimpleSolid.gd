@tool
extends StaticBody2D
class_name SimpleSolid

@export var size := Vector2(128.0, 32.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var fill_color := Color(0.14, 0.17, 0.24, 1.0):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color(0.35, 0.45, 0.65, 1.0):
	set(value):
		edge_color = value
		queue_redraw()

var _collision_shape: CollisionShape2D

func _ready() -> void:
	_collision_shape = get_node_or_null("CollisionShape2D")
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	_update_shape()
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, fill_color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), edge_color)

func _update_shape() -> void:
	if _collision_shape == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_collision_shape.shape = rectangle
