@tool
extends Resource
class_name DisguiseProfile

@export var id: StringName
@export var display_name := ""
@export var faction_id: StringName
@export var sprite_frames: SpriteFrames
@export var menu_icon: Texture2D
@export var sprite_offset := Vector2.ZERO
@export var animation_map: Dictionary = {}
@export_range(0.2, 1.0, 0.01) var move_speed_multiplier := 0.65
@export_range(0.0, 600.0, 1.0) var suspicion_move_speed := 135.0


func get_animation_for(source_animation: StringName) -> StringName:
	var source_key: String = String(source_animation)
	var mapped_animation: Variant = animation_map.get(source_key, animation_map.get(source_animation, StringName()))
	if mapped_animation is StringName and not String(mapped_animation).is_empty():
		return mapped_animation
	if mapped_animation is String and not String(mapped_animation).is_empty():
		return StringName(mapped_animation)

	var fallback_name: String = _get_fallback_animation(source_key)
	if fallback_name.is_empty():
		return StringName()
	return StringName(fallback_name)


func _get_fallback_animation(source_animation: String) -> String:
	match source_animation:
		"idle", "idle_to_run", "run_to_idle", "fall_to_idle", "landing", "respawn":
			return "idle"
		"run":
			return "walk"
		"jump", "jump_to_fall", "double_jump", "fall", "wall_slide":
			return "jump"
		_:
			return "idle"
