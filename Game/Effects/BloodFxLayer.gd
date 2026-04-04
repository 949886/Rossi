extends Node
class_name BloodFxLayer

@export_group("Textures")
## Textures used by airborne droplets and directional spray particles.
@export var blood_particle_textures: Array[Texture2D] = [
	preload("res://Game/Effects/Textures/efx_blood_particle_1.png"),
	preload("res://Game/Effects/Textures/efx_blood_particle_2.png"),
	preload("res://Game/Effects/Textures/efx_blood_particle_3.png"),
	preload("res://Game/Effects/Textures/efx_blood_particle_4.png"),
	preload("res://Game/Effects/Textures/efx_blood_particle_5.png"),
]

## Textures used for floor splashes and soft blood clouds.
@export var blood_floor_textures: Array[Texture2D] = [
	preload("res://Game/Effects/Textures/efx_blood_background_1.png"),
	preload("res://Game/Effects/Textures/efx_blood_background_2.png"),
]

## Textures used when a droplet or impact leaves a stain on a wall surface.
@export var blood_wall_textures: Array[Texture2D] = [
	preload("res://Game/Effects/Textures/efx_blood_wall_1.png"),
	preload("res://Game/Effects/Textures/efx_blood_wall_2.png"),
]

@export_group("Limits")
@export var max_persistent_stains := 72
@export var max_active_droplets := 36
@export var pooled_droplet_capacity := 36

@export_group("Blood Motion")
@export var droplet_gravity := 1280.0
@export var droplet_min_lifetime := 0.28
@export var droplet_max_lifetime := 0.75
@export var downward_stain_probe := 104.0
@export var wall_stain_probe := 92.0

@export_group("Hitstop")
@export var hit_hitstop_duration := 0.03
@export var kill_hitstop_duration := 0.055
@export var hitstop_time_scale := 0.05

@export_group("Cinematic")
@export var kill_flash_color := Color(1.0, 0.72, 0.72, 0.24)
@export var kill_flash_duration := 0.08
@export var camera_shake_duration := 0.14
@export var camera_shake_strength := 7.5
@export var chromatic_peak_strength := 6.0

var _rng := RandomNumberGenerator.new()
var _world_root: Node2D
var _transient_back: Node2D
var _persistent_back: Node2D
var _persistent_front: Node2D
var _transient_front: Node2D
var _overlay_layer: CanvasLayer
var _flash_rect: ColorRect
var _droplet_pool: Array[Sprite2D] = []
var _active_droplets: Array[Dictionary] = []
var _persistent_stains: Array[Sprite2D] = []
var _active_camera: Camera2D
var _camera_base_offset := Vector2.ZERO
var _shake_remaining := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _chromatic_material: ShaderMaterial
var _chromatic_base_strength := 0.0
var _chromatic_tween: Tween

func _ready() -> void:
	add_to_group("BloodFxLayer")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_structure()
	_rebuild_droplet_pool()
	_active_camera = get_viewport().get_camera_2d()
	if _active_camera != null:
		_camera_base_offset = _active_camera.offset
	_find_chromatic_material()

func _exit_tree() -> void:
	if _active_camera != null:
		_active_camera.offset = _camera_base_offset

func _process(delta: float) -> void:
	_update_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if _active_droplets.is_empty():
		return

	for index in range(_active_droplets.size() - 1, -1, -1):
		var droplet := _active_droplets[index]
		var sprite: Sprite2D = droplet["sprite"]
		if sprite == null or not is_instance_valid(sprite):
			_active_droplets.remove_at(index)
			continue

		droplet["lifetime"] = float(droplet["lifetime"]) - delta
		if float(droplet["lifetime"]) <= 0.0:
			_release_droplet(index)
			continue

		var velocity: Vector2 = droplet["velocity"]
		var from_position: Vector2 = sprite.global_position
		var to_position := from_position + velocity * delta
		var collision := _intersect_environment(from_position, to_position, droplet["exclude"])
		if not collision.is_empty():
			if bool(droplet["leave_stain"]):
				_spawn_surface_stain(
					collision["position"],
					collision["normal"],
					float(droplet["stain_scale"]),
					float(droplet["rotation_bias"])
				)
			_release_droplet(index)
			continue

		sprite.global_position = to_position
		sprite.rotation = velocity.angle()
		droplet["velocity"] = velocity + Vector2.DOWN * droplet_gravity * delta
		_active_droplets[index] = droplet

func spawn_hit_blood(context: Dictionary) -> void:
	if not is_inside_tree():
		return

	var origin := _get_origin_from_context(context)
	var attack_direction := _get_attack_direction(context)
	var spray_direction := attack_direction
	var scale := maxf(0.2, float(context.get("blood_scale", 1.0)))
	var exclude_rids := _get_exclude_rids(context)

	_apply_hitstop(hit_hitstop_duration)
	_spawn_blood_cloud(origin, 0.9 * scale, false)
	_spawn_slash_fan_burst(origin, spray_direction, 7, 0.34, 150.0, 290.0, 0.42 * scale, 0.76 * scale, 0.12, 0.2, false)
	_spawn_slash_fan_droplets(origin, spray_direction, 10, 0.4, 260.0, 440.0, 0.24 * scale, 0.42 * scale, exclude_rids)
	if _rng.randf() < 0.75:
		_spawn_ground_stain_beneath(origin, 0.28 * scale)

func spawn_death_blood(context: Dictionary) -> void:
	if not is_inside_tree():
		return

	var origin := _get_origin_from_context(context)
	var attack_direction := _get_attack_direction(context)
	var spray_direction := attack_direction
	var scale := maxf(0.45, float(context.get("blood_scale", 1.0)))
	var exclude_rids := _get_exclude_rids(context)
	var facing_direction := signf(float(context.get("facing_direction", 1.0)))
	if is_zero_approx(facing_direction):
		facing_direction = 1.0

	_apply_hitstop(kill_hitstop_duration)
	_spawn_screen_flash()
	_pulse_chromatic_aberration()
	_start_camera_shake(camera_shake_strength * scale, camera_shake_duration)
	_spawn_blood_cloud(origin, 1.45 * scale, true)
	_spawn_slash_fan_burst(origin, spray_direction, 12, 0.5, 190.0, 380.0, 0.58 * scale, 1.1 * scale, 0.16, 0.28, false)
	_spawn_slash_fan_burst(origin, spray_direction, 9, 0.56, 210.0, 410.0, 0.52 * scale, 0.96 * scale, 0.12, 0.24, true)
	_spawn_slash_fan_droplets(origin, spray_direction, 24, 0.62, 320.0, 560.0, 0.34 * scale, 0.74 * scale, exclude_rids)
	_spawn_ground_stain_beneath(origin, 0.95 * scale)
	_spawn_wall_stain_near(origin, spray_direction, Vector2(facing_direction, 0.0), 0.76 * scale, exclude_rids)

func clear_all() -> void:
	if _transient_back != null:
		for child in _transient_back.get_children():
			child.queue_free()
	if _transient_front != null:
		for child in _transient_front.get_children():
			child.queue_free()
	if _persistent_back != null:
		for child in _persistent_back.get_children():
			child.queue_free()
	if _persistent_front != null:
		for child in _persistent_front.get_children():
			child.queue_free()

	_droplet_pool.clear()
	_active_droplets.clear()
	_persistent_stains.clear()
	_rebuild_droplet_pool()
	_shake_remaining = 0.0
	if _active_camera != null:
		_active_camera.offset = _camera_base_offset
	if _flash_rect != null:
		_flash_rect.color.a = 0.0

func get_active_blood_count() -> int:
	var transient_back_count := 0
	if _transient_back != null:
		transient_back_count = maxi(0, _transient_back.get_child_count() - _droplet_pool.size())
	var transient_front_count := 0
	if _transient_front != null:
		transient_front_count = _transient_front.get_child_count()
	return _persistent_stains.size() + _active_droplets.size() + transient_back_count + transient_front_count

func _ensure_structure() -> void:
	_world_root = _get_or_create_node2d(self, "WorldFx")
	_transient_back = _get_or_create_node2d(_world_root, "TransientBack")
	_persistent_back = _get_or_create_node2d(_world_root, "PersistentBack")
	_persistent_front = _get_or_create_node2d(_world_root, "PersistentFront")
	_transient_front = _get_or_create_node2d(_world_root, "TransientFront")
	# Floor stains should sit behind world geometry; wall stains stay in front.
	_transient_back.z_as_relative = false
	_transient_back.z_index = 0
	_persistent_back.z_as_relative = false
	_persistent_back.z_index = -5
	_persistent_front.z_as_relative = false
	_persistent_front.z_index = 0
	_transient_front.z_as_relative = false
	_transient_front.z_index = 5

	_overlay_layer = get_node_or_null("Overlay") as CanvasLayer
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "Overlay"
		_overlay_layer.layer = 20
		add_child(_overlay_layer)

	_flash_rect = _overlay_layer.get_node_or_null("KillFlash") as ColorRect
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.name = "KillFlash"
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.offset_left = 0.0
		_flash_rect.offset_top = 0.0
		_flash_rect.offset_right = 0.0
		_flash_rect.offset_bottom = 0.0
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.color = Color(kill_flash_color.r, kill_flash_color.g, kill_flash_color.b, 0.0)
		_overlay_layer.add_child(_flash_rect)

func _get_or_create_node2d(parent: Node, node_name: String) -> Node2D:
	var node := parent.get_node_or_null(node_name) as Node2D
	if node != null:
		return node
	node = Node2D.new()
	node.name = node_name
	parent.add_child(node)
	return node

func _rebuild_droplet_pool() -> void:
	for _index in range(pooled_droplet_capacity):
		var sprite := Sprite2D.new()
		sprite.visible = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 0
		_transient_back.add_child(sprite)
		_droplet_pool.append(sprite)

func _spawn_blood_cloud(origin: Vector2, scale_amount: float, front: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _random_texture(blood_floor_textures)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = origin
	sprite.rotation = _rng.randf_range(-PI, PI)
	sprite.scale = Vector2.ONE * _rng.randf_range(0.45, 0.7) * scale_amount
	sprite.modulate = Color(0.72, 0.06, 0.06, 0.0)
	var parent := _transient_front if front else _transient_back
	parent.add_child(sprite)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.72, 0.05)
	tween.tween_property(sprite, "scale", sprite.scale * _rng.randf_range(1.2, 1.65), 0.16)
	tween.set_parallel(false)
	tween.tween_interval(0.04)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)

func _spawn_spray_burst(origin: Vector2, direction: Vector2, count: int, spread: float, min_speed: float, max_speed: float, min_scale: float, max_scale: float, min_life: float, max_life: float, front: bool) -> void:
	var parent := _transient_front if front else _transient_back
	var base_direction := direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.LEFT

	for _index in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = _random_texture(blood_particle_textures)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.global_position = origin
		sprite.modulate = Color(0.85, 0.05, 0.05, _rng.randf_range(0.72, 0.94))
		sprite.scale = Vector2.ONE * _rng.randf_range(min_scale, max_scale)
		parent.add_child(sprite)

		var velocity := base_direction.rotated(_rng.randf_range(-spread, spread)) * _rng.randf_range(min_speed, max_speed)
		var target := origin + velocity * _rng.randf_range(0.14, 0.24)
		sprite.rotation = velocity.angle()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "global_position", target, _rng.randf_range(min_life, max_life))
		tween.tween_property(sprite, "modulate:a", 0.0, _rng.randf_range(min_life, max_life))
		tween.tween_property(sprite, "scale", sprite.scale * _rng.randf_range(0.75, 1.2), _rng.randf_range(min_life, max_life))
		tween.set_parallel(false)
		tween.tween_callback(sprite.queue_free)

func _spawn_slash_fan_burst(origin: Vector2, slash_direction: Vector2, count: int, half_angle: float, min_speed: float, max_speed: float, min_scale: float, max_scale: float, min_life: float, max_life: float, front: bool) -> void:
	var parent := _transient_front if front else _transient_back
	var base_direction := slash_direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	var normal := base_direction.orthogonal()

	for index in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = _random_texture(blood_particle_textures)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var t := 0.0
		if count > 1:
			t = lerpf(-1.0, 1.0, float(index) / float(count - 1))
		var curved_t := signf(t) * pow(absf(t), 0.7)
		var angle_offset := curved_t * half_angle + _rng.randf_range(-0.04, 0.04)
		var dir := base_direction.rotated(angle_offset).normalized()
		var lane_offset := normal * curved_t * _rng.randf_range(3.0, 10.0)
		var speed := _rng.randf_range(min_speed, max_speed)
		var life := _rng.randf_range(min_life, max_life)

		sprite.global_position = origin + lane_offset
		sprite.modulate = Color(0.86, 0.05, 0.05, _rng.randf_range(0.74, 0.96))
		sprite.scale = Vector2.ONE * _rng.randf_range(min_scale, max_scale)
		sprite.rotation = dir.angle()
		parent.add_child(sprite)

		var target := sprite.global_position + dir * speed * life
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "global_position", target, life)
		tween.tween_property(sprite, "modulate:a", 0.0, life)
		tween.tween_property(sprite, "scale", sprite.scale * _rng.randf_range(0.82, 1.18), life)
		tween.set_parallel(false)
		tween.tween_callback(sprite.queue_free)

func _spawn_slash_fan_droplets(origin: Vector2, slash_direction: Vector2, count: int, half_angle: float, min_speed: float, max_speed: float, min_scale: float, max_scale: float, exclude_rids: Array[RID]) -> void:
	var base_direction := slash_direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	var normal := base_direction.orthogonal()

	for index in range(count):
		if _active_droplets.size() >= max_active_droplets:
			break

		var sprite := _acquire_droplet_sprite()
		if sprite == null:
			break

		var t := 0.0
		if count > 1:
			t = lerpf(-1.0, 1.0, float(index) / float(count - 1))
		var curved_t := signf(t) * pow(absf(t), 0.72)
		var angle_offset := curved_t * half_angle + _rng.randf_range(-0.06, 0.06)
		var dir := base_direction.rotated(angle_offset).normalized()
		var side_offset := normal * curved_t * _rng.randf_range(4.0, 12.0)
		var scale_amount := _rng.randf_range(min_scale, max_scale)
		var speed := _rng.randf_range(min_speed, max_speed)

		sprite.texture = _random_texture(blood_particle_textures)
		sprite.global_position = origin + side_offset + dir * _rng.randf_range(0.0, 6.0)
		sprite.scale = Vector2.ONE * scale_amount
		sprite.rotation = dir.angle()
		sprite.modulate = Color(0.95, 0.08, 0.08, _rng.randf_range(0.82, 0.98))
		sprite.visible = true

		_active_droplets.append({
			"sprite": sprite,
			"velocity": dir * speed,
			"lifetime": _rng.randf_range(droplet_min_lifetime, droplet_max_lifetime),
			"stain_scale": scale_amount * 0.92,
			"rotation_bias": angle_offset * 0.35,
			"exclude": exclude_rids.duplicate(),
			"leave_stain": true,
		})

func _spawn_droplet_spray(origin: Vector2, direction: Vector2, count: int, spread: float, min_speed: float, max_speed: float, min_scale: float, max_scale: float, exclude_rids: Array[RID]) -> void:
	var base_direction := direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.LEFT

	for _index in range(count):
		if _active_droplets.size() >= max_active_droplets:
			break

		var sprite := _acquire_droplet_sprite()
		if sprite == null:
			break

		var velocity := base_direction.rotated(_rng.randf_range(-spread, spread)) * _rng.randf_range(min_speed, max_speed)
		sprite.texture = _random_texture(blood_particle_textures)
		sprite.global_position = origin + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-6.0, 6.0))
		sprite.scale = Vector2.ONE * _rng.randf_range(min_scale, max_scale)
		sprite.rotation = velocity.angle()
		sprite.modulate = Color(0.95, 0.08, 0.08, _rng.randf_range(0.82, 0.98))
		sprite.visible = true

		_active_droplets.append({
			"sprite": sprite,
			"velocity": velocity,
			"lifetime": _rng.randf_range(droplet_min_lifetime, droplet_max_lifetime),
			"stain_scale": _rng.randf_range(min_scale, max_scale) * 0.92,
			"rotation_bias": _rng.randf_range(-0.22, 0.22),
			"exclude": exclude_rids.duplicate(),
			"leave_stain": true,
		})

func _spawn_ground_stain_beneath(origin: Vector2, scale_amount: float) -> void:
	var start := origin + Vector2(0.0, -4.0)
	var result := _intersect_environment(start, start + Vector2.DOWN * downward_stain_probe, [])
	if result.is_empty():
		return
	_spawn_surface_stain(result["position"], result["normal"], scale_amount, _rng.randf_range(-0.3, 0.3))

func _spawn_wall_stain_near(origin: Vector2, primary_direction: Vector2, secondary_direction: Vector2, scale_amount: float, exclude_rids: Array[RID]) -> void:
	var directions := [
		primary_direction.normalized(),
		secondary_direction.normalized(),
		-secondary_direction.normalized(),
	]
	for candidate_direction in directions:
		if candidate_direction == Vector2.ZERO:
			continue
		var result := _intersect_environment(origin, origin + candidate_direction * wall_stain_probe, exclude_rids)
		if result.is_empty():
			continue
		var normal: Vector2 = result["normal"]
		if absf(normal.y) > 0.45:
			continue
		_spawn_surface_stain(result["position"], normal, scale_amount, _rng.randf_range(-0.18, 0.18))
		return

func _spawn_surface_stain(position: Vector2, normal: Vector2, scale_amount: float, rotation_bias: float) -> void:
	var sprite := Sprite2D.new()
	var floor_surface := absf(normal.y) > 0.55
	sprite.texture = _random_texture(blood_floor_textures if floor_surface else blood_wall_textures)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = position + normal * 1.5
	sprite.modulate = Color(0.78, 0.08, 0.08, _rng.randf_range(0.76, 0.94))
	sprite.scale = Vector2.ONE * maxf(0.2, scale_amount) * _rng.randf_range(0.88, 1.18)
	if floor_surface:
		sprite.rotation = _rng.randf_range(-PI, PI)
	else:
		sprite.rotation = normal.angle() + PI * 0.5 + rotation_bias

	var parent := _persistent_back if floor_surface else _persistent_front
	parent.add_child(sprite)
	_persistent_stains.append(sprite)
	if _persistent_stains.size() > max_persistent_stains:
		var oldest: Sprite2D = _persistent_stains.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

func _acquire_droplet_sprite() -> Sprite2D:
	if _droplet_pool.is_empty():
		if _active_droplets.size() >= max_active_droplets:
			return null
		var sprite := Sprite2D.new()
		sprite.visible = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_transient_back.add_child(sprite)
		return sprite
	return _droplet_pool.pop_back()

func _release_droplet(index: int) -> void:
	var droplet := _active_droplets[index]
	var sprite: Sprite2D = droplet["sprite"]
	if sprite != null and is_instance_valid(sprite):
		sprite.visible = false
		sprite.texture = null
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
		_droplet_pool.append(sprite)
	_active_droplets.remove_at(index)

func _apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	Chronos.play_hitstop(duration, hitstop_time_scale)

func _spawn_screen_flash() -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = kill_flash_color
	if _flash_rect.has_meta("flash_tween"):
		var old_tween_value: Variant = _flash_rect.get_meta("flash_tween")
		if old_tween_value is Tween and (old_tween_value as Tween).is_valid():
			(old_tween_value as Tween).kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_flash_rect, "color:a", kill_flash_color.a, 0.02)
	tween.set_parallel(false)
	tween.tween_property(_flash_rect, "color:a", 0.0, kill_flash_duration)
	_flash_rect.set_meta("flash_tween", tween)

func _start_camera_shake(strength: float, duration: float) -> void:
	_active_camera = get_viewport().get_camera_2d()
	if _active_camera == null:
		return
	_camera_base_offset = _active_camera.offset
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_remaining = maxf(_shake_remaining, duration)

func _update_camera_shake(delta: float) -> void:
	_active_camera = get_viewport().get_camera_2d()
	if _active_camera == null:
		return
	if _shake_remaining <= 0.0:
		if _active_camera.offset != _camera_base_offset:
			_active_camera.offset = _camera_base_offset
		return

	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	var normalized := 0.0 if _shake_duration <= 0.0 else (_shake_remaining / _shake_duration)
	var intensity := _shake_strength * normalized
	_active_camera.offset = _camera_base_offset + Vector2(
		_rng.randf_range(-intensity, intensity),
		_rng.randf_range(-intensity, intensity)
	)
	if _shake_remaining <= 0.0:
		_active_camera.offset = _camera_base_offset

func _pulse_chromatic_aberration() -> void:
	if _chromatic_material == null:
		_find_chromatic_material()
	if _chromatic_material == null:
		return

	if _chromatic_tween != null and _chromatic_tween.is_valid():
		_chromatic_tween.kill()

	var peak := maxf(_chromatic_base_strength + 1.25, chromatic_peak_strength)
	var strength_callback := Callable(self, "_set_chromatic_strength")
	_chromatic_tween = create_tween()
	_chromatic_tween.tween_method(strength_callback, _chromatic_base_strength, peak, 0.04)
	_chromatic_tween.tween_method(strength_callback, peak, _chromatic_base_strength, 0.12)

func _set_chromatic_strength(value: float) -> void:
	if _chromatic_material == null:
		return
	_chromatic_material.set_shader_parameter("MAX_DIST_PX", value)

func _find_chromatic_material() -> void:
	_chromatic_material = null
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var candidate := _find_chromatic_material_in_node(current_scene)
	if candidate != null:
		_chromatic_material = candidate
		var base_value: Variant = _chromatic_material.get_shader_parameter("MAX_DIST_PX")
		if base_value is float:
			_chromatic_base_strength = base_value
		else:
			_chromatic_base_strength = 0.0

func _find_chromatic_material_in_node(node: Node) -> ShaderMaterial:
	if node is ColorRect:
		var material := (node as ColorRect).material
		if material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			var base_value: Variant = shader_material.get_shader_parameter("MAX_DIST_PX")
			if base_value != null:
				return shader_material
	for child in node.get_children():
		var found := _find_chromatic_material_in_node(child)
		if found != null:
			return found
	return null

func _get_origin_from_context(context: Dictionary) -> Vector2:
	var impact_position: Variant = context.get("impact_position", null)
	if impact_position is Vector2:
		return impact_position
	var receiver_position: Variant = context.get("receiver_global_position", null)
	if receiver_position is Vector2:
		return receiver_position
	return Vector2.ZERO

func _get_attack_direction(context: Dictionary) -> Vector2:
	var direction: Variant = context.get("attack_direction", context.get("direction", Vector2.LEFT))
	if direction is Vector2 and direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector2.LEFT

func _get_exclude_rids(context: Dictionary) -> Array[RID]:
	var exclude_rids: Array[RID] = []
	for key in ["source", "receiver"]:
		var node: Variant = context.get(key, null)
		if node is CollisionObject2D:
			exclude_rids.append((node as CollisionObject2D).get_rid())
	return exclude_rids

func _intersect_environment(from_position: Vector2, to_position: Vector2, exclude_rids: Array[RID]) -> Dictionary:
	var world := get_viewport().world_2d
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude_rids
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Variant = result.get("collider")
	if not _is_supported_surface(collider):
		return {}
	return result

func _is_supported_surface(collider: Variant) -> bool:
	return collider is StaticBody2D or collider is AnimatableBody2D or collider is TileMap or collider is TileMapLayer

func _random_texture(textures: Array[Texture2D]) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[_rng.randi_range(0, textures.size() - 1)]
