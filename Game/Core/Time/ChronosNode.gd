extends CharacterBody2D
class_name ChronosNode

@export_group("Chronos")
@export var time_group: StringName = &"world"
@export var sync_animation_speed := true

@onready var _animation_player: AnimationPlayer = get_node_or_null(^"AnimationPlayer")
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null(^"AnimatedSprite2D")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not sync_animation_speed:
		return

	var relative_time_scale := Chronos.get_relative_time_scale_for_group(time_group)
	if _animation_player != null:
		_animation_player.speed_scale = relative_time_scale
	if _animated_sprite != null:
		_animated_sprite.speed_scale = relative_time_scale

func get_time_scaled_delta(delta: float) -> float:
	if Engine.is_editor_hint():
		return delta
	return Chronos.get_delta_for_group(delta, time_group)

func get_time_elapsed() -> float:
	return Chronos.get_elapsed_time_for_group(time_group)
