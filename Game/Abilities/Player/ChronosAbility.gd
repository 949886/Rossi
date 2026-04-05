extends Ability
class_name ChronosAbility

@export_group("Chronos")
@export var chronos_stamina_max := 100.0
@export var chronos_stamina_use_per_second := 28.0
@export var chronos_stamina_recover_per_second := 38.0
@export var chronos_stamina_recover_delay := 0.2
@export var chronos_cooldown := 0.45
@export var chronos_afterimage_interval := 0.045
@export var chronos_afterimage_fade_duration := 0.22
@export var chronos_afterimage_color := Color(0.58, 0.92, 1.0, 0.3)
@export var chronos_afterimage_min_speed := 65.0
@export var chronos_afterimage_trail_distance := 18.0
@export_range(0, 8, 1) var chronos_start_burst_count := 3
@export_range(0, 8, 1) var chronos_stop_burst_count := 2

var chronos_stamina := 0.0
var chronos_cooldown_left := 0.0
var _chronos_stamina_recover_delay_left := 0.0
var _chronos_afterimage_left := 0.0


func _init() -> void:
	ability_id = &"chronos"
	slot = &"utility"
	input_action = &"chronos"


func _on_setup() -> void:
	chronos_stamina = chronos_stamina_max

func tick(_delta: float) -> void:
	var real_delta := Chronos.get_real_delta()
	_update_chronos_state(real_delta)
	_update_chronos_afterimage(real_delta)
	_sync_affected_animation_speeds()


func reset_state() -> void:
	_set_chronos_running(false, false)
	chronos_stamina = chronos_stamina_max
	chronos_cooldown_left = 0.0
	_chronos_stamina_recover_delay_left = 0.0
	_chronos_afterimage_left = 0.0
	_sync_affected_animation_speeds()


func is_chronos_ready() -> bool:
	return ability_owner.get("is_dead") != true and chronos_stamina > 0.0 and chronos_cooldown_left <= 0.0


func is_chronos_running() -> bool:
	return ability_owner.get("is_dead") != true and Chronos.is_chronos_enabled()


func chronos_stamina_percent() -> float:
	if chronos_stamina_max <= 0.0:
		return 0.0
	return clampf(chronos_stamina / chronos_stamina_max, 0.0, 1.0)


func chronos_cooldown_percent() -> float:
	if chronos_cooldown <= 0.0:
		return 0.0
	return clampf(chronos_cooldown_left / chronos_cooldown, 0.0, 1.0)


func try_spawn_afterimage() -> bool:
	if not is_chronos_running():
		return false
	_spawn_chronos_afterimage(1.0)
	return true


func _update_chronos_state(real_delta: float) -> void:
	if real_delta <= 0.0:
		return

	chronos_cooldown_left = maxf(0.0, chronos_cooldown_left - real_delta)

	if ability_owner.get("is_dead") == true:
		_set_chronos_running(false, false)
		return

	var wants_chronos := Input.is_action_pressed(&"chronos")
	if wants_chronos and is_chronos_ready():
		_set_chronos_running(true, false)
	elif not wants_chronos and is_chronos_running():
		_set_chronos_running(false, true)

	if is_chronos_running():
		chronos_stamina = maxf(0.0, chronos_stamina - chronos_stamina_use_per_second * real_delta)
		_chronos_stamina_recover_delay_left = chronos_stamina_recover_delay
		if chronos_stamina <= 0.0:
			_set_chronos_running(false, true)
		return

	if _chronos_stamina_recover_delay_left > 0.0:
		_chronos_stamina_recover_delay_left = maxf(0.0, _chronos_stamina_recover_delay_left - real_delta)
	elif chronos_stamina < chronos_stamina_max:
		chronos_stamina = minf(chronos_stamina_max, chronos_stamina + chronos_stamina_recover_per_second * real_delta)


func _set_chronos_running(enabled: bool, start_cooldown: bool) -> void:
	var was_running := Chronos.is_chronos_enabled()
	if enabled == was_running:
		return

	Chronos.set_chronos_enabled(enabled)

	if enabled:
		_chronos_afterimage_left = 0.0
		_spawn_chronos_burst(chronos_start_burst_count, 1.0)
#		ability_owner.emit_compat_signal(&"chronos_started")
		return

	if was_running:
		_spawn_chronos_burst(chronos_stop_burst_count, 0.78)
#		ability_owner.emit_compat_signal(&"chronos_stopped")
		_chronos_afterimage_left = 0.0
		if start_cooldown:
			chronos_cooldown_left = chronos_cooldown
			_chronos_stamina_recover_delay_left = chronos_stamina_recover_delay


func _update_chronos_afterimage(real_delta: float) -> void:
	if real_delta <= 0.0:
		return
	if not is_chronos_running():
		_chronos_afterimage_left = 0.0
		return
	if not _should_spawn_chronos_afterimage():
		_chronos_afterimage_left = minf(_chronos_afterimage_left, chronos_afterimage_interval)
		return

	_chronos_afterimage_left -= real_delta
	while _chronos_afterimage_left <= 0.0:
		_spawn_chronos_afterimage(1.0)
		_chronos_afterimage_left += maxf(0.01, chronos_afterimage_interval)


func _should_spawn_chronos_afterimage() -> bool:
	if ability_owner.animated_sprite == null or ability_owner.animated_sprite.sprite_frames == null:
		return false
	if ability_owner.get("is_dead") == true or not ability_owner.visible:
		return false
	if ability_owner.velocity.length() >= chronos_afterimage_min_speed:
		return true
	match ability_owner.get("current_state"):
		ability_owner.State.DASH, ability_owner.State.ATTACK, ability_owner.State.THROW, ability_owner.State.AIR_THROW, ability_owner.State.JUMP, ability_owner.State.DOUBLE_JUMP:
			return true
		_:
			return false


func _spawn_chronos_burst(count: int, alpha_scale: float) -> void:
	if count <= 0:
		return
	var burst_count := maxi(1, count)
	var burst_direction := _get_afterimage_direction()
	for i in range(burst_count):
		var t := float(i + 1) / float(burst_count + 1)
		var offset := -burst_direction * chronos_afterimage_trail_distance * t
		var burst_alpha := lerpf(alpha_scale, alpha_scale * 0.45, t)
		_spawn_chronos_afterimage(burst_alpha, offset)


func _get_afterimage_direction() -> Vector2:
	if ability_owner.velocity.length_squared() > 0.001:
		return ability_owner.velocity.normalized()
	return Vector2(-1.0 if ability_owner.animated_sprite != null and ability_owner.animated_sprite.flip_h else 1.0, 0.0)


func _spawn_chronos_afterimage(alpha_scale: float, position_offset: Vector2 = Vector2.ZERO) -> void:
	if ability_owner.animated_sprite == null or ability_owner.animated_sprite.sprite_frames == null:
		return

	var texture: Texture2D = ability_owner.animated_sprite.sprite_frames.get_frame_texture(ability_owner.animated_sprite.animation, ability_owner.animated_sprite.frame)
	if texture == null:
		return
	var current_scene: Node = ability_owner.get_tree().current_scene
	if current_scene == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = ability_owner.animated_sprite.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.centered = true
	ghost.global_position = ability_owner.animated_sprite.global_position + position_offset
	ghost.scale = ability_owner.animated_sprite.scale
	ghost.z_index = ability_owner.animated_sprite.z_index - 1
	var ghost_color := chronos_afterimage_color
	ghost_color.a *= clampf(alpha_scale, 0.0, 1.0)
	ghost.modulate = ghost_color
	current_scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, chronos_afterimage_fade_duration)
	tween.tween_property(ghost, "scale", ghost.scale * 1.04, chronos_afterimage_fade_duration)
	tween.set_parallel(false)
	tween.tween_callback(ghost.queue_free)
	
func _sync_affected_animation_speeds() -> void:
	var tree: SceneTree = ability_owner.get_tree()
	if tree == null:
		return
	_sync_animation_speed_for_group(tree, &"Player", Chronos.PLAYER_GROUP)
	_sync_animation_speed_for_group(tree, &"Enemy", Chronos.ENEMY_GROUP)


func _sync_animation_speed_for_group(tree: SceneTree, group_name: StringName, time_group: StringName) -> void:
	var relative_time_scale: float = Chronos.get_relative_time_scale_for_group(time_group)
	for node in tree.get_nodes_in_group(group_name):
		if node is Node:
			_apply_animation_speed_scale(node as Node, relative_time_scale)


func _apply_animation_speed_scale(node: Node, speed_scale: float) -> void:
	var animation_player: AnimationPlayer = node.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.speed_scale = speed_scale
	var animated_sprite: AnimatedSprite2D = node.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.speed_scale = speed_scale
