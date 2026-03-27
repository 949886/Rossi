extends EnemyBase
class_name EnemyGangsterRanged

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var projectile_spawn_offset := Vector2(24.0, -50.0)
@export var target_aim_offset := Vector2(0.0, -46.0)
@export var max_attack_vertical_delta := 96.0

func _can_attack_target() -> bool:
	if projectile_scene == null:
		return false
	if not _is_target_valid(_target):
		return false
	if _attack_cooldown_timer > 0.0:
		return false
	if not _has_line_of_sight(_target):
		return false

	var to_target := _get_target_aim_position() - _get_projectile_spawn_position()
	if absf(to_target.x) > attack_range:
		return false
	if absf(to_target.y) > max_attack_vertical_delta:
		return false
	if sign(to_target.x) != _facing_direction and absf(to_target.x) > 4.0:
		return false
	return true

func _on_enter_windup_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_play_animation("shoot")

func _on_enter_attack_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_fire_projectile()

func _fire_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		projectile.queue_free()
		return

	spawn_parent.add_child(projectile)
	var spawn_position := _get_projectile_spawn_position()
	var shot_direction := _get_projectile_direction(spawn_position)

	if projectile is Node2D:
		(projectile as Node2D).global_position = spawn_position
	if projectile is EnemyProjectile:
		(projectile as EnemyProjectile).configure_projectile(self, shot_direction)
	elif projectile.has_method("configure_projectile"):
		projectile.configure_projectile(self, shot_direction)

func _get_projectile_spawn_position() -> Vector2:
	return global_position + Vector2(projectile_spawn_offset.x * _facing_direction, projectile_spawn_offset.y)

func _get_target_aim_position() -> Vector2:
	if not _is_target_valid(_target):
		return global_position + Vector2(_facing_direction, 0.0)
	return _target.global_position + target_aim_offset

func _get_projectile_direction(spawn_position: Vector2) -> Vector2:
	var to_target := _get_target_aim_position() - spawn_position
	if to_target.length_squared() < 0.0001:
		return Vector2(_facing_direction, 0.0)
	return to_target.normalized()
