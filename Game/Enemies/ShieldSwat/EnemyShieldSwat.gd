extends EnemyBase
class_name EnemyShieldSwat

@export_group("Shield")
@export_range(0.0, 5.0, 0.05) var guard_duration := 0.6
@export_range(0.0, 5.0, 0.05) var post_guard_attack_lockout_duration := 0.35
@export_range(0.0, 64.0, 1.0) var guard_turn_min_distance := 20.0

var _guard_timer := 0.0
var _attack_lockout_timer := 0.0


func _physics_process(delta: float) -> void:
	var scaled_delta := Chronos.get_delta_for_group(delta, Chronos.ENEMY_GROUP)
	var guard_ended := false

	if _guard_timer > 0.0:
		_guard_timer = maxf(0.0, _guard_timer - scaled_delta)
		guard_ended = is_zero_approx(_guard_timer)
		if guard_ended:
			_attack_lockout_timer = maxf(_attack_lockout_timer, post_guard_attack_lockout_duration)
	if _attack_lockout_timer > 0.0:
		_attack_lockout_timer = maxf(0.0, _attack_lockout_timer - scaled_delta)

	super._physics_process(delta)

	if guard_ended and _state != State.DEAD:
		_restore_animation_for_current_state()
	elif _guard_timer > 0.0 and _state != State.DEAD and _state != State.HIT:
		_maintain_guard_state()


func receive_attack(hit_data: Dictionary) -> Dictionary:
	if _should_guard_attack(hit_data):
		var resolved_hit_data: Dictionary = _build_guarded_hit_data(hit_data)
		_enter_guard_state()
		return resolved_hit_data
	return super.receive_attack(hit_data)


func reset_for_encounter() -> void:
	_guard_timer = 0.0
	_attack_lockout_timer = 0.0
	super.reset_for_encounter()


func _can_attack_target() -> bool:
	if _guard_timer > 0.0 or _attack_lockout_timer > 0.0:
		return false
	return super._can_attack_target()


func _change_state(new_state: State) -> void:
	super._change_state(new_state)
	if _guard_timer > 0.0 and new_state != State.DEAD and new_state != State.HIT:
		_play_guard_animation()


func _update_facing(direction: float) -> void:
	if _guard_timer > 0.0 or _attack_lockout_timer > 0.0:
		var desired_direction := _facing_direction
		if direction > 0.1:
			desired_direction = 1
		elif direction < -0.1:
			desired_direction = -1

		if desired_direction != _facing_direction:
			if not _is_target_valid(_target):
				return
			var target_distance_x := absf(_target.global_position.x - global_position.x)
			if target_distance_x < guard_turn_min_distance:
				return

	super._update_facing(direction)


func _should_guard_attack(hit_data: Dictionary) -> bool:
	if _state == State.DEAD:
		return false
	if not _is_player_melee_attack(hit_data):
		return false
	return _is_attack_from_front(hit_data)


func _is_player_melee_attack(hit_data: Dictionary) -> bool:
	var source = hit_data.get("source")
	if not (source is Node) or not (source as Node).is_in_group("Player"):
		return false
	return hit_data.get("hitbox") is Hitbox2D


func _is_attack_from_front(hit_data: Dictionary) -> bool:
	var attacker_position: Variant = hit_data.get("attacker_global_position", null)
	if not (attacker_position is Vector2):
		var source = hit_data.get("source")
		if source is Node2D:
			attacker_position = (source as Node2D).global_position
		else:
			return false

	var attacker_x_delta := (attacker_position as Vector2).x - global_position.x
	if absf(attacker_x_delta) > 4.0:
		return signf(attacker_x_delta) == float(_facing_direction)

	var attack_direction: Variant = hit_data.get("attack_direction", Vector2(_facing_direction, 0.0))
	if attack_direction is Vector2:
		return (attack_direction as Vector2).x * float(_facing_direction) >= -0.1
	return true


func _build_guarded_hit_data(hit_data: Dictionary) -> Dictionary:
	var resolved_hit_data := hit_data.duplicate(true)
	resolved_hit_data["damage"] = 0
	resolved_hit_data["knockback"] = Vector2.ZERO
	resolved_hit_data["hitstun"] = 0.0
	resolved_hit_data["invuln_time"] = 0.0
	resolved_hit_data["receiver"] = self
	if not resolved_hit_data.has("receiver_global_position"):
		resolved_hit_data["receiver_global_position"] = global_position
	if not resolved_hit_data.has("impact_position") or not (resolved_hit_data["impact_position"] is Vector2):
		resolved_hit_data["impact_position"] = hurtbox.global_position if hurtbox != null else global_position
	resolved_hit_data["tags"] = _append_tag(hit_data.get("tags", PackedStringArray()), "shield_guarded")
	return resolved_hit_data


func _append_tag(existing_tags: Variant, tag: String) -> PackedStringArray:
	var tags := PackedStringArray()
	if existing_tags is PackedStringArray:
		tags = (existing_tags as PackedStringArray).duplicate()
	elif existing_tags is Array:
		for existing_tag in existing_tags:
			tags.append(str(existing_tag))
	if not tags.has(tag):
		tags.append(tag)
	return tags


func _enter_guard_state() -> void:
	_guard_timer = guard_duration
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	if _state == State.WINDUP or _state == State.ATTACK or _state == State.RECOVER or _state == State.HIT:
		super._change_state(State.CHASE if _can_resume_engagement() else State.IDLE)
	_maintain_guard_state()


func _maintain_guard_state() -> void:
	if _is_target_valid(_target):
		var to_target := _target.global_position - global_position
		if absf(to_target.x) > 1.0:
			_update_facing(signf(to_target.x))
	_play_guard_animation()


func _play_guard_animation() -> void:
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("guard"):
		if animated_sprite.animation != &"guard" or not animated_sprite.is_playing():
			animated_sprite.play("guard")
		return
	_play_animation("idle")


func _restore_animation_for_current_state() -> void:
	match _state:
		State.IDLE:
			_play_animation("idle")
		State.PATROL, State.RETURN_HOME:
			_play_animation(_get_patrol_animation())
		State.CHASE:
			_play_animation(_get_chase_animation())
		State.SEARCH, State.RECOVER, State.RESPAWN:
			_play_animation("idle")
		State.WINDUP, State.ATTACK:
			_play_animation("melee_attack")
		State.HIT:
			_play_animation("be_hit")
		State.DEAD:
			_play_animation("die")
