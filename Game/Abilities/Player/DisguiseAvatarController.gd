extends Node2D
class_name DisguiseAvatarController

@export_range(0.05, 1.5, 0.01) var transition_duration := 0.45
@export_range(0.0, 32.0, 0.5) var ghost_offset_distance := 8.0
@export_range(0.0, 1.0, 0.01) var ghost_alpha := 0.35

@onready var _display_sprite: AnimatedSprite2D = $DisplaySprite
@onready var _transition_sprite: Sprite2D = $TransitionSprite

var _player: PlatformerCharacter2D
var _active_profile: DisguiseProfile


func _ready() -> void:
	_player = get_parent() as PlatformerCharacter2D
	visible = false
	_display_sprite.visible = false
	_transition_sprite.visible = false


func _process(_delta: float) -> void:
	if _player == null or _active_profile == null:
		return
	_sync_with_player()


func begin_transform(profile: DisguiseProfile, source_texture: Texture2D, source_flip_h: bool) -> void:
	if profile == null:
		return

	var source_anchor := _get_player_sprite_anchor_position()
	var target_anchor := _get_profile_sprite_anchor_position(profile)
	_active_profile = profile
	visible = true
	_display_sprite.visible = true
	_display_sprite.sprite_frames = profile.sprite_frames
	_display_sprite.position = target_anchor
	_display_sprite.flip_h = source_flip_h
	_display_sprite.scale = Vector2.ONE * 0.92
	_display_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_sync_with_player()
	_setup_transition_sprite(source_texture, source_flip_h, source_anchor)
	_spawn_transition_ghosts(source_texture, source_flip_h, source_anchor)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_display_sprite, "modulate:a", 1.0, transition_duration * 0.6)
	tween.tween_property(_display_sprite, "scale", Vector2.ONE, transition_duration * 0.7)
	tween.tween_property(_transition_sprite, "modulate:a", 0.0, transition_duration)
	tween.tween_property(_transition_sprite, "scale", Vector2.ONE * 1.08, transition_duration)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_transition_sprite.visible = false
	)


func begin_reveal() -> void:
	if _active_profile == null:
		visible = false
		_display_sprite.visible = false
		_transition_sprite.visible = false
		return

	var current_texture: Texture2D = _get_display_texture()
	var current_flip_h: bool = _display_sprite.flip_h
	_setup_transition_sprite(current_texture, current_flip_h, _display_sprite.position)
	_spawn_transition_ghosts(current_texture, current_flip_h, _display_sprite.position)

	_active_profile = null
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_display_sprite, "modulate:a", 0.0, transition_duration * 0.65)
	tween.tween_property(_display_sprite, "scale", Vector2.ONE * 1.06, transition_duration * 0.65)
	tween.tween_property(_transition_sprite, "modulate:a", 0.0, transition_duration)
	tween.tween_property(_transition_sprite, "scale", Vector2.ONE * 1.1, transition_duration)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_display_sprite.visible = false
		_transition_sprite.visible = false
		visible = false
	)


func get_active_profile() -> DisguiseProfile:
	return _active_profile


func _sync_with_player() -> void:
	if _player == null or _active_profile == null or _display_sprite.sprite_frames == null:
		return

	_display_sprite.position = _get_profile_sprite_anchor_position(_active_profile)
	_display_sprite.flip_h = _player.animated_sprite.flip_h
	var mapped_animation: StringName = _active_profile.get_animation_for(_player.animated_sprite.animation)
	if String(mapped_animation).is_empty():
		mapped_animation = &"idle"
	if _display_sprite.animation != mapped_animation or not _display_sprite.is_playing():
		_display_sprite.play(mapped_animation)


func _get_player_sprite_anchor_position() -> Vector2:
	if _player == null or _player.animated_sprite == null:
		return Vector2.ZERO
	return _player.animated_sprite.position


func _get_profile_sprite_anchor_position(profile: DisguiseProfile) -> Vector2:
	if profile != null and profile.sprite_offset != Vector2.ZERO:
		return profile.sprite_offset
	return _get_player_sprite_anchor_position()


func _get_display_texture() -> Texture2D:
	if _display_sprite == null or _display_sprite.sprite_frames == null:
		return null
	if not _display_sprite.sprite_frames.has_animation(_display_sprite.animation):
		return null
	return _display_sprite.sprite_frames.get_frame_texture(_display_sprite.animation, _display_sprite.frame)


func _setup_transition_sprite(texture: Texture2D, flip_h: bool, sprite_position: Vector2) -> void:
	if texture == null:
		_transition_sprite.visible = false
		return
	_transition_sprite.texture = texture
	_transition_sprite.position = sprite_position
	_transition_sprite.flip_h = flip_h
	_transition_sprite.scale = Vector2.ONE
	_transition_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_transition_sprite.visible = true


func _spawn_transition_ghosts(texture: Texture2D, flip_h: bool, sprite_position: Vector2) -> void:
	if texture == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	for index in range(3):
		var ghost := Sprite2D.new()
		ghost.texture = texture
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.flip_h = flip_h
		ghost.global_position = to_global(sprite_position + Vector2((index - 1) * ghost_offset_distance, 0.0))
		ghost.modulate = Color(0.82, 0.94, 1.0, ghost_alpha - index * 0.08)
		current_scene.add_child(ghost)
		var tween := ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, transition_duration * 0.8)
		tween.tween_property(ghost, "scale", Vector2.ONE * 1.05, transition_duration * 0.8)
		tween.set_parallel(false)
		tween.tween_callback(ghost.queue_free)
