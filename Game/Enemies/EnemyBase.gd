extends CharacterBody2D
class_name EnemyBase

signal hit_taken(hit_data: Dictionary)
signal died
signal respawned
signal target_acquired(target: Node)
signal alert_started(target: Node)
signal health_changed(current_health: int, max_health: int)
signal state_changed(state_name: String)
signal attack_windup_started
signal attack_performed

@export_group("Stats")
@export_subgroup("Vitality")
## Enemy maximum health. When health reaches 0, the enemy dies and enters the DEAD state.
@export var max_health := 1
## Base horizontal movement speed used by patrol, chase acceleration, and hit recovery damping.
@export var move_speed := 90.0

@export_subgroup("Combat")
## Horizontal range within which the enemy can start a melee attack.
@export var attack_range := 26.0
## Cooldown between completed attacks.
@export var attack_cooldown := 0.8
## Delay before the hitbox becomes active after the attack starts.
@export var windup_duration := 0.25
## How long the attack hitbox stays active.
@export var attack_active_duration := 0.12
## Recovery time after an attack finishes before the enemy can act again.
@export var recover_duration := 0.2
## Duration of the HIT state applied to victims and this enemy after taking damage.
@export var hitstun_duration := 0.18
## Temporary invulnerability applied after taking a hit to prevent immediate repeated damage.
@export var invuln_duration := 0.0
## Damage dealt by the enemy's melee hitbox.
@export var contact_damage := 1
## Knockback applied to the victim on hit. The X direction is flipped automatically with facing.
@export var contact_knockback := Vector2(160.0, -20.0)

@export_subgroup("Investigation")
## Enables moving to the player's last seen position and briefly searching after losing sight.
@export var enable_investigation := true
## How long the enemy remains in SEARCH state before giving up and returning home.
@export_range(0.0, 10.0, 0.1) var investigate_duration := 1.5
## How often the enemy turns around while searching the last seen location.
@export_range(0.0, 5.0, 0.05) var investigate_turn_interval := 0.4
## Horizontal tolerance for considering the last seen position reached.
@export_range(0.0, 64.0, 1.0) var investigate_arrival_tolerance := 8.0

@export_subgroup("Physics")
## Downward acceleration applied while the enemy is airborne.
@export var gravity := 980.0
## Maximum falling speed clamp while airborne.
@export var max_fall_speed := 800.0

@export_group("Movement")
## Multiplier applied to move_speed while actively chasing a target or investigation point.
@export var chase_speed_multiplier := 1.35
## Distance to the spawn point at which RETURN_HOME snaps the enemy back onto its home X position.
@export var return_tolerance := 6.0
## Pause duration after reaching a patrol edge or obstacle before walking the other way.
@export var patrol_pause_duration := 0.2
## Downward ray length used to detect missing ground ahead.
@export var ground_probe_length := 28.0
## Forward ray length used to detect walls or blockers ahead.
@export var wall_probe_length := 14.0
## Local position of the attack hitbox relative to the enemy. X is mirrored by facing direction.
@export var attack_hitbox_offset := Vector2(18.0, -32.0)
## Size of the rectangular melee hitbox collision shape.
@export var attack_hitbox_size := Vector2(26.0, 18.0)

@export_subgroup("Detection")
## Patrol radius measured from the spawn point. Set to 0 to keep the enemy idle in place.
@export var patrol_distance := 96.0
## Maximum distance from the spawn point before the enemy gives up pursuit and returns home.
@export var lose_target_range := 260.0
## Small grace window after losing line of sight before the target is fully dropped.
@export_range(0.0, 1.0, 0.01) var target_loss_grace_duration := 0.18
## Distance from home within which suspended targeting can be restored while returning.
@export_range(0.0, 128.0, 1.0) var leash_reacquire_distance := 16.0

@export_group("Feedback")
## Sprite tint applied briefly when the enemy takes damage.
@export var hit_flash_color := Color(1.0, 0.55, 0.55, 1.0)
## Duration of the hit flash tween back to the base sprite color.
@export var hit_flash_duration := 0.07
## Final tint applied when the enemy dies.
@export var dead_tint := Color(0.45, 0.45, 0.45, 0.9)
## Enables spawning blood VFX on hit and death.
@export var blood_enabled := true
## Scale multiplier for blood VFX spawned from non-lethal hits.
@export var blood_hit_scale := 1.0
## Scale multiplier for blood VFX spawned on death.
@export var blood_death_scale := 1.0

@export_group("Debug")
## Shows a runtime label above the enemy with current state, health, and target information.
@export var show_debug_label := true
## Local offset of the debug label relative to the enemy origin.
@export var debug_label_offset := Vector2(0.0, -118.0)

@onready var animated_sprite: AnimatedSprite2D = $"AnimatedSprite2D"
@onready var animation_player: AnimationPlayer = $"AnimationPlayer"
@onready var collision_shape: CollisionShape2D = $"CollisionShape2D"
@onready var hurtbox: Hurtbox2D = $"Hurtbox"
@onready var attack_hitbox: Hitbox2D = $"AttackHitbox"
@onready var vision_sensor: VisionSensor2D = $"VisionArea"
@onready var front_wall_ray_cast: RayCast2D = $"FrontWallRayCast2D"
@onready var front_ground_ray_cast: RayCast2D = $"FrontGroundRayCast2D"

enum State {
	IDLE,
	PATROL,
	CHASE,
	SEARCH,
	WINDUP,
	ATTACK,
	RECOVER,
	HIT,
	DEAD,
	RESPAWN,
	RETURN_HOME,
}

var _state := State.IDLE
var _current_health := 1
var _facing_direction := 1
var _spawn_position := Vector2.ZERO
var _spawn_facing_direction := 1
var _target: Node2D
var _state_timer := 0.0
var _attack_cooldown_timer := 0.0
var _invulnerable_timer := 0.0
var _target_loss_grace_timer := 0.0
var _investigation_turn_timer := 0.0
var _suspend_targeting_until_home := false
var _investigation_position := Vector2.ZERO
var _has_investigation_position := false
var _alert_cycle_active := false
var _patrol_origin_x := 0.0
var _patrol_direction := 1
var _debug_label: Label
var _base_sprite_modulate := Color.WHITE
var _last_damage_context: Dictionary = {}

var current_health: int:
	get: return _current_health

var is_dead: bool:
	get: return _state == State.DEAD

var state_name: String:
	get: return String(State.keys()[_state]).to_lower()

func _ready() -> void:
	add_to_group("Enemy")
	_spawn_position = global_position
	_patrol_origin_x = global_position.x
	_current_health = max_health
	_patrol_direction = _spawn_facing_direction
	if animated_sprite != null:
		_base_sprite_modulate = animated_sprite.modulate

	if attack_hitbox != null:
		attack_hitbox.target_group = "Player"
		attack_hitbox.damage = contact_damage
		attack_hitbox.knockback = contact_knockback
		attack_hitbox.hitstun = hitstun_duration
		attack_hitbox.invuln_time = invuln_duration
		attack_hitbox.set_active(false)
		_configure_attack_hitbox()

	if hurtbox != null and hurtbox.receiver_path == NodePath():
		hurtbox.receiver_path = NodePath("..")

	if vision_sensor != null:
		vision_sensor.target_group = "Player"
		vision_sensor.set_sensor_enabled(true)
		vision_sensor.set_visual_state(state_name)
		vision_sensor.set_facing_direction(_spawn_facing_direction)

	if front_ground_ray_cast != null:
		front_ground_ray_cast.enabled = true
		front_ground_ray_cast.exclude_parent = true
	if front_wall_ray_cast != null:
		front_wall_ray_cast.enabled = true
		front_wall_ray_cast.exclude_parent = true

	_ensure_debug_label()
	_emit_health_changed()
	_update_facing(_spawn_facing_direction)
	_change_state(State.PATROL if patrol_distance > 0.0 else State.IDLE)

func initialize_spawn(spawn_position: Vector2, facing_direction: int) -> void:
	_spawn_position = spawn_position
	_patrol_origin_x = spawn_position.x
	_spawn_facing_direction = 1 if facing_direction >= 0 else -1
	_patrol_direction = _spawn_facing_direction
	global_position = spawn_position
	_update_facing(_spawn_facing_direction)

func _physics_process(delta: float) -> void:
	delta = Chronos.get_delta_for_group(delta, Chronos.ENEMY_GROUP)
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	if _target_loss_grace_timer > 0.0:
		_target_loss_grace_timer = maxf(0.0, _target_loss_grace_timer - delta)
	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)

	if _state != State.DEAD:
		_update_target()

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
		State.WINDUP:
			_process_windup()
		State.ATTACK:
			_process_attack()
		State.RECOVER:
			_process_recover()
		State.HIT:
			_process_hit(delta)
		State.RETURN_HOME:
			_process_return_home(delta)
		State.RESPAWN:
			_process_respawn()
		State.DEAD:
			_process_dead(delta)

	_apply_gravity(delta)
	move_and_slide()
	_update_debug_label()

func receive_attack(hit_data: Dictionary) -> void:
	if _state == State.DEAD or _invulnerable_timer > 0.0:
		return

	var damage := int(hit_data.get("damage", 1))
	var blood_context := _build_blood_context(hit_data)
	_current_health = max(0, _current_health - damage)
	_invulnerable_timer = maxf(invuln_duration, float(hit_data.get("invuln_time", invuln_duration)))
	velocity = hit_data.get("knockback", Vector2.ZERO)
	_emit_health_changed()
	_play_hit_feedback()
	hit_taken.emit(hit_data)

	if _current_health <= 0:
		_last_damage_context = blood_context
		die()
		return

	if not _should_suppress_hit_blood(hit_data, damage):
		_emit_hit_blood(blood_context)
	_change_state(State.HIT)

func interact_with(node: Node) -> void:
	if node is LaserBeam:
		die()

func InteractWith(node: Node) -> void:
	interact_with(node)

func die() -> void:
	if _state == State.DEAD:
		return

	_emit_death_blood(_last_damage_context if not _last_damage_context.is_empty() else _build_fallback_blood_context())
	_last_damage_context.clear()
	_target = null
	_target_loss_grace_timer = 0.0
	_investigation_turn_timer = 0.0
	_suspend_targeting_until_home = false
	_has_investigation_position = false
	_alert_cycle_active = false
	velocity = Vector2.ZERO
	_disable_combat_nodes()
	if collision_shape != null:
		_set_collision_shape_disabled(collision_shape, true)
	_apply_dead_visuals()
	_change_state(State.DEAD)
	died.emit()

func reset_for_encounter() -> void:
	_last_damage_context.clear()
	_current_health = max_health
	_invulnerable_timer = 0.0
	_attack_cooldown_timer = 0.0
	_target = null
	_target_loss_grace_timer = 0.0
	_investigation_turn_timer = 0.0
	_suspend_targeting_until_home = false
	_has_investigation_position = false
	_alert_cycle_active = false
	velocity = Vector2.ZERO
	global_position = _spawn_position
	_patrol_direction = _spawn_facing_direction
	if animated_sprite != null:
		animated_sprite.modulate = _base_sprite_modulate
	if collision_shape != null:
		_set_collision_shape_disabled(collision_shape, false)
	if vision_sensor != null:
		vision_sensor.set_sensor_enabled(true)
		vision_sensor.clear_visual_persistence()
		vision_sensor.set_debug_target(null)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", true)
		hurtbox.set_deferred("monitoring", false)
		_set_area_collision_shapes_disabled(hurtbox, false)
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_emit_health_changed()
	_configure_attack_hitbox()
	_update_facing(_spawn_facing_direction)
	_change_state(State.RESPAWN)
	respawned.emit()

func _process_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	if _can_detect_target():
		_change_state(State.CHASE)
		return
	if patrol_distance > 0.0 and _state_timer <= 0.0:
		_change_state(State.PATROL)

func _process_patrol(_delta: float) -> void:
	if _can_detect_target():
		_change_state(State.CHASE)
		return

	var left_bound := _patrol_origin_x - patrol_distance
	var right_bound := _patrol_origin_x + patrol_distance
	var out_of_bounds := (_patrol_direction < 0 and global_position.x <= left_bound) or (_patrol_direction > 0 and global_position.x >= right_bound)
	if out_of_bounds or _is_blocked_forward():
		_patrol_direction *= -1
		_update_facing(_patrol_direction)
		_change_state(State.IDLE)
		_state_timer = patrol_pause_duration
		return

	_update_facing(_patrol_direction)
	velocity.x = _patrol_direction * move_speed * 0.55

func _process_chase(_delta: float) -> void:
	var distance_to_home := global_position.distance_to(_spawn_position)
	if distance_to_home > lose_target_range:
		if not _is_target_valid(_target) and _can_finish_investigation_before_return():
			pass
		else:
			_target = null
			_target_loss_grace_timer = 0.0
			_suspend_targeting_until_home = true
			_clear_investigation_target()
			_change_state(State.RETURN_HOME)
			return

	if _is_target_valid(_target):
		var to_target := _target.global_position - global_position
		if absf(to_target.x) > 1.0:
			_update_facing(sign(to_target.x))

		if _can_attack_target():
			_change_state(State.WINDUP)
			return

		if _is_blocked_forward():
			velocity.x = 0.0
			return

		velocity.x = _facing_direction * move_speed * chase_speed_multiplier
		return

	if not _has_investigation_target():
		_clear_investigation_target()
		_change_state(State.RETURN_HOME)
		return

	var to_last_seen := _get_investigation_position() - global_position
	if absf(to_last_seen.x) <= _get_investigation_arrival_tolerance():
		velocity.x = 0.0
		global_position.x = _get_investigation_position().x
		if enable_investigation and investigate_duration > 0.0:
			_change_state(State.SEARCH)
		else:
			_clear_investigation_target()
			_change_state(State.RETURN_HOME)
		return

	if absf(to_last_seen.x) > 1.0:
		_update_facing(sign(to_last_seen.x))

	if _is_blocked_forward():
		velocity.x = 0.0
		if enable_investigation and investigate_duration > 0.0:
			_change_state(State.SEARCH)
		else:
			_clear_investigation_target()
			_change_state(State.RETURN_HOME)
		return

	velocity.x = _facing_direction * move_speed * chase_speed_multiplier

func _process_search(delta: float) -> void:
	velocity.x = 0.0
	if _can_detect_target():
		_change_state(State.CHASE)
		return
	if not _has_investigation_target():
		_change_state(State.RETURN_HOME)
		return
	if _state_timer <= 0.0:
		_clear_investigation_target()
		_change_state(State.RETURN_HOME)
		return
	if investigate_turn_interval <= 0.0:
		return

	_investigation_turn_timer = maxf(0.0, _investigation_turn_timer - delta)
	if _investigation_turn_timer > 0.0:
		return

	_update_facing(-_facing_direction)
	_investigation_turn_timer = investigate_turn_interval

func _process_windup() -> void:
	velocity.x = 0.0
	if not _is_target_valid(_target):
		_change_state(State.CHASE if _can_resume_engagement() else State.RETURN_HOME)
		return
	if _state_timer <= 0.0:
		_change_state(State.ATTACK)

func _process_attack() -> void:
	velocity.x = 0.0
	if _state_timer <= 0.0:
		if attack_hitbox != null:
			attack_hitbox.set_active(false)
		_change_state(State.RECOVER)

func _process_recover() -> void:
	velocity.x = 0.0
	if _state_timer <= 0.0:
		_change_state(State.CHASE if _can_resume_engagement() else State.IDLE)

func _process_hit(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 3.0)
	if _state_timer <= 0.0:
		_change_state(State.CHASE if _can_resume_engagement() else State.RETURN_HOME)

func _process_return_home(_delta: float) -> void:
	if _suspend_targeting_until_home:
		_target = null
	if _can_detect_target():
		_change_state(State.CHASE)
		return

	var to_home := _spawn_position - global_position
	if absf(to_home.x) <= return_tolerance:
		_suspend_targeting_until_home = false
		_clear_investigation_target()
		_alert_cycle_active = false
		global_position.x = _spawn_position.x
		_change_state(State.PATROL if patrol_distance > 0.0 else State.IDLE)
		return

	_update_facing(sign(to_home.x))
	if _is_blocked_forward():
		velocity.x = 0.0
		return
	velocity.x = _facing_direction * move_speed * 0.7

func _process_respawn() -> void:
	velocity.x = 0.0
	if _state_timer <= 0.0:
		_change_state(State.PATROL if patrol_distance > 0.0 else State.IDLE)

func _process_dead(_delta: float) -> void:
	velocity = Vector2.ZERO
	if attack_hitbox != null:
		attack_hitbox.set_active(false)

func _apply_gravity(delta: float) -> void:
	if _state == State.DEAD:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	else:
		velocity.y = 0.0

func _change_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(state_name)
	if vision_sensor != null:
		vision_sensor.set_visual_state(state_name)
	match new_state:
		State.IDLE:
			_play_animation("idle")
		State.PATROL:
			_play_animation(_get_patrol_animation())
		State.CHASE:
			_play_animation(_get_chase_animation())
		State.SEARCH:
			_state_timer = investigate_duration
			_on_enter_search_state()
		State.WINDUP:
			_state_timer = windup_duration
			_on_enter_windup_state()
			attack_windup_started.emit()
		State.ATTACK:
			_state_timer = attack_active_duration
			_attack_cooldown_timer = attack_cooldown
			_on_enter_attack_state()
			attack_performed.emit()
		State.RECOVER:
			_state_timer = recover_duration
			_on_enter_recover_state()
		State.HIT:
			_state_timer = hitstun_duration
			_on_enter_hit_state()
		State.DEAD:
			_on_enter_dead_state()
		State.RESPAWN:
			_state_timer = 0.15
			_play_animation("idle")
		State.RETURN_HOME:
			_play_animation(_get_patrol_animation())
	_update_debug_label()

func _play_animation(animation_name: String) -> void:
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
		if animation_name == "die":
			animated_sprite.sprite_frames.set_animation_loop(animation_name, false)
		animated_sprite.play(animation_name)
	elif animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func _on_enter_windup_state() -> void:
	_play_animation("melee_attack")

func _on_enter_search_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_investigation_turn_timer = investigate_turn_interval
	_play_animation("idle")

func _on_enter_attack_state() -> void:
	if attack_hitbox == null:
		return

	var attack_knockback := contact_knockback
	attack_knockback.x = absf(contact_knockback.x) * _facing_direction
	attack_hitbox.damage = contact_damage
	attack_hitbox.knockback = attack_knockback
	attack_hitbox.hitstun = hitstun_duration
	attack_hitbox.invuln_time = invuln_duration
	attack_hitbox.set_active(true)

func _on_enter_recover_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_play_animation("idle")

func _on_enter_hit_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_play_animation("be_hit")

func _on_enter_dead_state() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	_play_animation("die")

func _get_patrol_animation() -> String:
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation("walk"):
			return "walk"
		if animated_sprite.sprite_frames.has_animation("run"):
			return "run"
	return "idle"

func _get_chase_animation() -> String:
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation("run"):
			return "run"
		if animated_sprite.sprite_frames.has_animation("walk"):
			return "walk"
	return "idle"

func _update_target() -> void:
	if _state == State.DEAD:
		if vision_sensor != null:
			vision_sensor.clear_visual_persistence()
			vision_sensor.set_debug_target(null)
		return

	if _suspend_targeting_until_home:
		if global_position.distance_to(_spawn_position) > leash_reacquire_distance:
			_target = null
			_target_loss_grace_timer = 0.0
			if vision_sensor != null:
				vision_sensor.set_debug_target(null)
			return
		_suspend_targeting_until_home = false

	if _is_target_valid(_target):
		var distance_to_target := global_position.distance_to(_target.global_position)
		if distance_to_target <= lose_target_range and _can_retain_target(_target):
			_target_loss_grace_timer = target_loss_grace_duration
			_remember_investigation_position(_target.global_position)
			if vision_sensor != null:
				vision_sensor.track_visible_target(_target)
				vision_sensor.set_debug_target(_target)
			return
		if distance_to_target <= lose_target_range and _target_loss_grace_timer > 0.0:
			if vision_sensor != null:
				vision_sensor.set_debug_target(_target)
			return

	_target = null
	_target_loss_grace_timer = 0.0
	var new_target := _find_visible_target()
	if new_target != null:
		_target = new_target
		_target_loss_grace_timer = target_loss_grace_duration
		_remember_investigation_position(new_target.global_position)
		if not _alert_cycle_active:
			_alert_cycle_active = true
			alert_started.emit(new_target)
		target_acquired.emit(new_target)
	if vision_sensor != null:
		vision_sensor.set_debug_target(_target)

func _find_visible_target() -> Node2D:
	if vision_sensor == null:
		return null
	return vision_sensor.find_best_target(Callable(self, "_is_target_valid"))

func _is_target_valid(candidate: Variant) -> bool:
	if not (candidate is Node2D) or not is_instance_valid(candidate):
		return false
	if not candidate.is_in_group("Player"):
		return false
	var dead_state = candidate.get("is_dead")
	return dead_state == null or dead_state == false

func _has_line_of_sight(target: Node2D) -> bool:
	if vision_sensor == null:
		return true
	return vision_sensor.has_line_of_sight(target)

func _can_retain_target(target: Node2D) -> bool:
	if vision_sensor == null:
		return _has_line_of_sight(target)
	return vision_sensor.can_retain_target(target, Callable(self, "_is_target_valid"))

func _can_detect_target() -> bool:
	return _is_target_valid(_target) and _can_retain_target(_target)

func _can_resume_engagement() -> bool:
	return _is_target_valid(_target) or _has_investigation_target()

func _can_attack_target() -> bool:
	if not _is_target_valid(_target):
		return false
	if _attack_cooldown_timer > 0.0:
		return false
	if not _has_line_of_sight(_target):
		return false

	var to_target := _target.global_position - global_position
	if absf(to_target.x) > attack_range:
		return false
	if absf(to_target.y) > 36.0:
		return false
	if sign(to_target.x) != _facing_direction and absf(to_target.x) > 4.0:
		return false
	return true

func _is_blocked_forward() -> bool:
	if front_wall_ray_cast == null or front_ground_ray_cast == null:
		return false
	_update_probe_positions()
	front_wall_ray_cast.force_raycast_update()
	front_ground_ray_cast.force_raycast_update()
	return front_wall_ray_cast.is_colliding() or not front_ground_ray_cast.is_colliding()

func _update_facing(direction: float) -> void:
	if direction > 0.1:
		_facing_direction = 1
	elif direction < -0.1:
		_facing_direction = -1

	if animated_sprite != null:
		animated_sprite.flip_h = _facing_direction < 0
	if vision_sensor != null:
		vision_sensor.set_facing_direction(_facing_direction)
	_configure_attack_hitbox()
	_update_probe_positions()

func _configure_attack_hitbox() -> void:
	if attack_hitbox == null:
		return

	var local_offset := attack_hitbox_offset
	local_offset.x *= _facing_direction
	attack_hitbox.position = local_offset
	attack_hitbox.rotation = 0.0 if _facing_direction >= 0 else PI
	var collision := attack_hitbox.get_node_or_null("CollisionShape2D")
	if collision != null and collision.shape is RectangleShape2D:
		(collision.shape as RectangleShape2D).size = attack_hitbox_size

func _update_probe_positions() -> void:
	if front_wall_ray_cast != null:
		front_wall_ray_cast.position = Vector2(6.0 * _facing_direction, attack_hitbox_offset.y + 10.0)
		front_wall_ray_cast.target_position = Vector2(wall_probe_length * _facing_direction, 0.0)
	if front_ground_ray_cast != null:
		front_ground_ray_cast.position = Vector2(10.0 * _facing_direction, 0.0)
		front_ground_ray_cast.target_position = Vector2(0.0, ground_probe_length)

func _disable_combat_nodes() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)
	if vision_sensor != null:
		vision_sensor.clear_visual_persistence()
		vision_sensor.set_sensor_enabled(false)
		vision_sensor.set_debug_target(null)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)
		_set_area_collision_shapes_disabled(hurtbox, true)

func _set_collision_shape_disabled(shape: CollisionShape2D, disabled: bool) -> void:
	if shape == null:
		return
	shape.set_deferred("disabled", disabled)

func _set_area_collision_shapes_disabled(area: Area2D, disabled: bool) -> void:
	if area == null:
		return
	for child in area.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", disabled)

func _play_hit_feedback() -> void:
	if animated_sprite == null:
		return

	animated_sprite.modulate = hit_flash_color
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", _base_sprite_modulate, hit_flash_duration)

func _apply_dead_visuals() -> void:
	if animated_sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", dead_tint, 0.12)

func _ensure_debug_label() -> void:
	if not show_debug_label or _debug_label != null:
		return

	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.position = debug_label_offset
	_debug_label.size = Vector2(180.0, 42.0)
	add_child(_debug_label)
	_update_debug_label()

func _update_debug_label() -> void:
	if _debug_label == null:
		return

	_debug_label.position = debug_label_offset
	var target_text := "none"
	if is_instance_valid(_target):
		target_text = _target.name
	elif _has_investigation_target():
		target_text = "last seen"
	elif _has_visual_persistence_target():
		target_text = "last seen"
	_debug_label.text = "%s  HP %d/%d\nTarget: %s" % [state_name, _current_health, max_health, target_text]

func _emit_health_changed() -> void:
	health_changed.emit(_current_health, max_health)
	_update_debug_label()

func _has_visual_persistence_target() -> bool:
	return vision_sensor != null and vision_sensor.has_visual_persistence_target()

func _get_visual_persistence_position() -> Vector2:
	if vision_sensor == null:
		return Vector2.ZERO
	return vision_sensor.get_visual_persistence_position()

func _get_visual_persistence_arrival_tolerance() -> float:
	if vision_sensor == null:
		return return_tolerance
	return vision_sensor.get_visual_persistence_arrival_tolerance()

func _clear_visual_persistence_target() -> void:
	if vision_sensor == null:
		return
	vision_sensor.clear_visual_persistence()
	vision_sensor.set_debug_target(null)

func _remember_investigation_position(investigation_position: Vector2) -> void:
	if not enable_investigation:
		return
	_investigation_position = investigation_position
	_has_investigation_position = true

func _has_investigation_target() -> bool:
	return enable_investigation and _has_investigation_position

func _get_investigation_position() -> Vector2:
	return _investigation_position

func _get_investigation_arrival_tolerance() -> float:
	return maxf(investigate_arrival_tolerance, return_tolerance)

func _clear_investigation_target() -> void:
	_has_investigation_position = false
	_clear_visual_persistence_target()

func _can_finish_investigation_before_return() -> bool:
	if not _has_investigation_target():
		return false
	var max_investigation_distance := lose_target_range + _get_investigation_arrival_tolerance()
	return _investigation_position.distance_to(_spawn_position) <= max_investigation_distance

func _emit_hit_blood(context: Dictionary) -> void:
	if not blood_enabled:
		return
	var blood_fx := _get_blood_fx_layer()
	if blood_fx == null:
		return
	var payload := context.duplicate(true)
	payload["blood_scale"] = blood_hit_scale
	blood_fx.spawn_hit_blood(payload)

func _emit_death_blood(context: Dictionary) -> void:
	if not blood_enabled:
		return
	var blood_fx := _get_blood_fx_layer()
	if blood_fx == null:
		return
	var payload := context.duplicate(true)
	payload["blood_scale"] = blood_death_scale
	payload["facing_direction"] = _facing_direction
	blood_fx.spawn_death_blood(payload)

func _build_blood_context(hit_data: Dictionary) -> Dictionary:
	var context := hit_data.duplicate(true)
	context["receiver"] = self
	context["receiver_global_position"] = global_position
	if not context.has("impact_position") or not (context["impact_position"] is Vector2):
		if hurtbox != null:
			context["impact_position"] = hurtbox.global_position
		else:
			context["impact_position"] = global_position
	if not context.has("attack_direction") or not (context["attack_direction"] is Vector2):
		context["attack_direction"] = Vector2(_facing_direction, 0.0)
	return context

func _should_suppress_hit_blood(hit_data: Dictionary, damage: int) -> bool:
	if damage > 0:
		return false
	var tags_variant = hit_data.get("tags", PackedStringArray())
	if tags_variant is PackedStringArray:
		return (tags_variant as PackedStringArray).has("deflect")
	if tags_variant is Array:
		return (tags_variant as Array).has("deflect")
	return false

func _build_fallback_blood_context() -> Dictionary:
	return {
		"receiver": self,
		"source": self,
		"impact_position": hurtbox.global_position if hurtbox != null else global_position,
		"attack_direction": Vector2(_facing_direction, 0.0),
		"receiver_global_position": global_position,
		"attacker_global_position": global_position - Vector2(24.0 * _facing_direction, 0.0),
	}

func _get_blood_fx_layer() -> BloodFxLayer:
	for node in get_tree().get_nodes_in_group("BloodFxLayer"):
		if node is BloodFxLayer:
			return node as BloodFxLayer
	return null
