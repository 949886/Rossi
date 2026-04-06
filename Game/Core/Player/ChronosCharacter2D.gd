extends PlatformerCharacter2D
class_name ChronosCharacter2D
#
#signal chronos_started
#signal chronos_stopped
#
#@export_group("Chronos")
#@export var chronos_stamina_max := 100.0
#@export var chronos_stamina_use_per_second := 28.0
#@export var chronos_stamina_recover_per_second := 38.0
#@export var chronos_stamina_recover_delay := 0.2
#@export var chronos_cooldown := 0.45
#@export var chronos_afterimage_interval := 0.045
#@export var chronos_afterimage_fade_duration := 0.22
#@export var chronos_afterimage_color := Color(0.58, 0.92, 1.0, 0.3)
#@export var chronos_afterimage_min_speed := 65.0
#@export var chronos_afterimage_trail_distance := 18.0
#@export_range(0, 8, 1) var chronos_start_burst_count := 3
#@export_range(0, 8, 1) var chronos_stop_burst_count := 2
#
#var chronos_stamina := 0.0
#var chronos_cooldown_left := 0.0
#var _chronos_stamina_recover_delay_left := 0.0
#var _chronos_afterimage_left := 0.0
#
#var is_chronos_ready: bool:
#	get:
#		return not is_dead and chronos_stamina > 0.0 and chronos_cooldown_left <= 0.0
#
#var is_chronos_running: bool:
#	get:
#		return not is_dead and Chronos.is_chronos_enabled()
#
#var chronos_stamina_percent: float:
#	get:
#		if chronos_stamina_max <= 0.0:
#			return 0.0
#		return clampf(chronos_stamina / chronos_stamina_max, 0.0, 1.0)
#
#var chronos_cooldown_percent: float:
#	get:
#		if chronos_cooldown <= 0.0:
#			return 0.0
#		return clampf(chronos_cooldown_left / chronos_cooldown, 0.0, 1.0)
#
#func _ready() -> void:
#	chronos_stamina = chronos_stamina_max
#	super._ready()
#
#func _exit_tree() -> void:
#	if Chronos.is_chronos_enabled():
#		Chronos.set_chronos_enabled(false)
#
#func _physics_process(delta: float) -> void:
#	var real_delta := Chronos.get_real_delta()
#	_update_chronos_state(real_delta)
#	super._physics_process(delta)
#	_update_chronos_afterimage(real_delta)
#
#func die() -> void:
#	_set_chronos_running(false, false)
#	_chronos_afterimage_left = 0.0
#	super.die()
#
#func respawn(spawn_position: Vector2) -> void:
#	_set_chronos_running(false, false)
#	chronos_stamina = chronos_stamina_max
#	chronos_cooldown_left = 0.0
#	_chronos_stamina_recover_delay_left = 0.0
#	_chronos_afterimage_left = 0.0
#	super.respawn(spawn_position)
#
#func _update_chronos_state(real_delta: float) -> void:
#	if real_delta <= 0.0:
#		return
#
#	chronos_cooldown_left = maxf(0.0, chronos_cooldown_left - real_delta)
#
#	if is_dead:
#		_set_chronos_running(false, false)
#		return
#
#	var wants_chronos := Input.is_action_pressed(&"chronos")
#	if wants_chronos and is_chronos_ready:
#		_set_chronos_running(true, false)
#	elif not wants_chronos and is_chronos_running:
#		_set_chronos_running(false, true)
#
#	if is_chronos_running:
#		chronos_stamina = maxf(0.0, chronos_stamina - chronos_stamina_use_per_second * real_delta)
#		_chronos_stamina_recover_delay_left = chronos_stamina_recover_delay
#		if chronos_stamina <= 0.0:
#			_set_chronos_running(false, true)
#		return
#
#	if _chronos_stamina_recover_delay_left > 0.0:
#		_chronos_stamina_recover_delay_left = maxf(0.0, _chronos_stamina_recover_delay_left - real_delta)
#	elif chronos_stamina < chronos_stamina_max:
#		chronos_stamina = minf(chronos_stamina_max, chronos_stamina + chronos_stamina_recover_per_second * real_delta)
#
#func _set_chronos_running(enabled: bool, start_cooldown: bool) -> void:
#	var was_running := Chronos.is_chronos_enabled()
#	if enabled == was_running:
#		return
#
#	Chronos.set_chronos_enabled(enabled)
#
#	if enabled:
#		_chronos_afterimage_left = 0.0
#		_spawn_chronos_burst(chronos_start_burst_count, 1.0)
#		chronos_started.emit()
#		return
#
#	if was_running:
#		_spawn_chronos_burst(chronos_stop_burst_count, 0.78)
#		chronos_stopped.emit()
#		_chronos_afterimage_left = 0.0
#		if start_cooldown:
#			chronos_cooldown_left = chronos_cooldown
#			_chronos_stamina_recover_delay_left = chronos_stamina_recover_delay
#
#func _update_chronos_afterimage(real_delta: float) -> void:
#	if real_delta <= 0.0:
#		return
#	if not is_chronos_running:
#		_chronos_afterimage_left = 0.0
#		return
#	if not _should_spawn_chronos_afterimage():
#		_chronos_afterimage_left = minf(_chronos_afterimage_left, chronos_afterimage_interval)
#		return
#
#	_chronos_afterimage_left -= real_delta
#	while _chronos_afterimage_left <= 0.0:
#		_spawn_chronos_afterimage(1.0)
#		_chronos_afterimage_left += maxf(0.01, chronos_afterimage_interval)
#
#func _should_spawn_chronos_afterimage() -> bool:
#	if animated_sprite == null or animated_sprite.sprite_frames == null:
#		return false
#	if is_dead or not visible:
#		return false
#	if velocity.length() >= chronos_afterimage_min_speed:
#		return true
#	match _current_state:
#		PlatformerCharacter2D.State.DASH, PlatformerCharacter2D.State.ATTACK, PlatformerCharacter2D.State.THROW, PlatformerCharacter2D.State.AIR_THROW, PlatformerCharacter2D.State.JUMP, PlatformerCharacter2D.State.DOUBLE_JUMP:
#			return true
#		_:
#			return false
#
#func _spawn_chronos_burst(count: int, alpha_scale: float) -> void:
#	if count <= 0:
#		return
#
#	var burst_count := maxi(1, count)
#	var burst_direction := _get_afterimage_direction()
#	for i in range(burst_count):
#		var t := float(i + 1) / float(burst_count + 1)
#		var offset := -burst_direction * chronos_afterimage_trail_distance * t
#		var burst_alpha := lerpf(alpha_scale, alpha_scale * 0.45, t)
#		_spawn_chronos_afterimage(burst_alpha, offset)
#
#func _get_afterimage_direction() -> Vector2:
#	if velocity.length_squared() > 0.001:
#		return velocity.normalized()
#	return Vector2(-1.0 if animated_sprite != null and animated_sprite.flip_h else 1.0, 0.0)
#
#func _spawn_chronos_afterimage(alpha_scale: float, position_offset: Vector2 = Vector2.ZERO) -> void:
#	if animated_sprite == null or animated_sprite.sprite_frames == null:
#		return
#
#	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
#	if texture == null:
#		return
#	var current_scene := get_tree().current_scene
#	if current_scene == null:
#		return
#
#	var ghost := Sprite2D.new()
#	ghost.texture = texture
#	ghost.flip_h = animated_sprite.flip_h
#	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
#	ghost.centered = true
#	ghost.global_position = animated_sprite.global_position + position_offset
#	ghost.scale = animated_sprite.scale
#	ghost.z_index = animated_sprite.z_index - 1
#	var ghost_color := chronos_afterimage_color
#	ghost_color.a *= clampf(alpha_scale, 0.0, 1.0)
#	ghost.modulate = ghost_color
#	current_scene.add_child(ghost)
#
#	var tween := ghost.create_tween()
#	tween.set_parallel(true)
#	tween.tween_property(ghost, "modulate:a", 0.0, chronos_afterimage_fade_duration)
#	tween.tween_property(ghost, "scale", ghost.scale * 1.04, chronos_afterimage_fade_duration)
#	tween.set_parallel(false)
#	tween.tween_callback(ghost.queue_free)
#
#func spawn_afterimage() -> void:
#	if is_chronos_running:
#		_spawn_chronos_afterimage(1.0)
#		return
#	super.spawn_afterimage()
