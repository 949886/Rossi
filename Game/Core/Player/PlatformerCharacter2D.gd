extends AbilityCharacter2D
class_name PlatformerCharacter2D

signal attack_started(direction: Vector2)
signal died
signal respawned(spawn_position: Vector2)
signal checkpoint_set(checkpoint_position: Vector2)
signal shuriken_spawned(shuriken: Shuriken)
signal teleported(from_position: Vector2, to_position: Vector2)
signal jumped(kind: StringName)
signal landed
signal dashed
signal damage_taken(hit_data: Dictionary, current_health: int)
signal deflect_success(context: Dictionary)

@export_group("Movement")
@export var move_speed := 200.0
@export var acceleration := 1200.0
@export var friction := 1000.0
@export var air_acceleration := 600.0
@export var air_friction := 200.0

@export_group("Jump")
@export var enable_double_jump := true
@export var jump_velocity := -400.0
@export var double_jump_velocity := -350.0
@export var gravity := 980.0
@export var max_fall_speed := 600.0
@export var jump_cut_multiplier := 0.5

@export_group("Wall Jump")
@export var enable_wall_jump := true
@export var wall_slide_gravity := 150.0
@export var wall_jump_horizontal_speed := 300.0
@export var wall_jump_vertical_speed := -380.0

@export_group("Dash")
@export var dash_speed := 1000.0
@export var dash_duration := 0.15
@export var dash_invulnerability_duration := 0.15
@export var dash_cooldown := 0.8
@export var max_dash_charges := 2
@export var afterimage_fade_duration := 0.3
@export var afterimage_color := Color(0.4, 0.8, 1.0, 0.6)

@export_group("Attack")
@export var attack_speed := 720.0
@export var attack_duration := 0.12
@export var attack_cooldown := 0.0
@export var attack_gravity_scale := 0.35
@export var attack_exit_momentum_scale := 0.28
@export var attack_afterimage_interval := 0.035
@export var air_attack_lift_decay := 0.4 # Decreases lift by this ratio per air attack
@export var attack_hitbox_origin_offset := Vector2(0.0, -18.0)
@export var attack_hitbox_distance := 18.0
@export var attack_hitbox_size := Vector2(32.0, 18.0)
@export var attack_hitbox_delay := 0.02
@export var attack_hitbox_active_duration := 0.08
@export var attack_damage := 1
@export var attack_knockback := Vector2(220.0, -35.0)
@export var attack_hitstun := 0.12
@export var attack_invuln_time := 0.0

@export_group("Deflect")
@export var deflect_hitstop_duration := 0.045
@export_range(0.001, 1.0, 0.001) var deflect_hitstop_time_scale := 0.03

@export_group("Shuriken")
@export var shuriken_scene: PackedScene
@export var shuriken_spawn_offset := Vector2(10.0, -15.0)
@export var teleport_afterimage_count := 6
@export var teleport_afterimage_fade_duration := 0.16
@export var teleport_afterimage_color := Color(1.0, 0.35, 0.35, 0.72)
@export var teleport_flash_color := Color(1.0, 0.18, 0.18, 0.95)
@export var teleport_flash_core_color := Color(1.0, 1.0, 1.0, 0.98)
@export var teleport_flash_width := 14.0
@export var teleport_flash_duration := 0.05
@export var teleport_spark_count := 18
@export var teleport_spark_scatter := 18.0
@export var teleport_spark_duration := 0.16
@export var teleport_arrival_offset := 12.0

@export_group("Survival")
@export var respawn_delay := 0.6
@export var default_respawn_position := Vector2.ZERO
@export var max_health := 1

@onready var animated_sprite: AnimatedSprite2D = $"AnimatedSprite2D"
@onready var animation_player: AnimationPlayer = $"AnimationPlayer"
@onready var animation_tree: AnimationTree = $"AnimationTree"

var hurtbox: Hurtbox2D
var attack_hitbox: Hitbox2D

enum State {
	IDLE,
	IDLE_TO_RUN,
	RUN,
	RUN_TO_IDLE,
	JUMP,
	JUMP_TO_FALL,
	DOUBLE_JUMP,
	FALL,
	LANDING,
	FALL_TO_IDLE,
	ATTACK,
	DASH,
	WALL_SLIDE,
	THROW,
	AIR_THROW,
	DIE,
	RESPAWN,
}

var _current_state: State = State.IDLE
var _facing_direction := 1 # 1 = right, -1 = left
var _has_double_jump := true

# Dash tracking
var _dash_charges := 0
var _dash_recharge_timer := 0.0
var _dash_timer := 0.0
var _invulnerability_timer := 0.0
var _is_dead := false
var _current_respawn_position := Vector2.ZERO
var _respawn_time_left := 0.0
var _floor_snap_restore_time_left := 0.0
var _floor_snap_restore_value := 0.0

# Attack tracking
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_afterimage_timer := 0.0
var _attack_hitbox_delay_timer := 0.0
var _attack_hitbox_remaining_timer := 0.0
var _attack_direction := Vector2.RIGHT
var _air_attack_count := 0
var current_health := 1
var _parried_projectile_ids: Dictionary = {}

# Wall slide tracking
var _wall_direction := 0 # -1 = wall on left, 1 = wall on right

# Animations that should loop (all others play once)
const LOOPING_ANIMATIONS := ["idle", "run", "fall"]

var _pending_attack_angle = null
var _pending_throw_angle = null
var _active_shuriken: Shuriken
var _rng := RandomNumberGenerator.new()

# Public API for UI to display dash cooldown and charges
var dash_charges: int:
	get: return _dash_charges

var dash_recharge_progress: float:
	get: return (_dash_recharge_timer / dash_cooldown) if _dash_charges < max_dash_charges and dash_cooldown > 0.0 else 0.0

var is_dead: bool:
	get: return _is_dead

var is_invulnerable: bool:
	get: return not _is_dead and _invulnerability_timer > 0.0

var current_state: State:
	get: return _current_state

var invulnerable_timer: float:
	get: return _invulnerability_timer
	set(value): _invulnerability_timer = maxf(0.0, value)

var current_respawn_position: Vector2:
	get: return _current_respawn_position

func _get(property: StringName):
	match String(property):
		"max_dash_charges":
			return max_dash_charges
	return null

func _ready() -> void:
	super._ready()
	
	hurtbox = get_node_or_null("Hurtbox")
	attack_hitbox = get_node_or_null("PlayerAttackHitbox")
	
	_ensure_combat_nodes()

	# Disable AnimationTree - it overrides AnimationPlayer.play() calls.
	# We drive animations entirely from code via AnimationPlayer.
	if animation_tree != null:
		animation_tree.active = false

	animation_player.animation_finished.connect(_on_animation_finished)

	_dash_charges = max_dash_charges
	_dash_recharge_timer = dash_cooldown
	_current_respawn_position = global_position if default_respawn_position == Vector2.ZERO else default_respawn_position
	current_health = max_health
	_rng.randomize()

	# Start in idle
	_change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	delta = get_time_scaled_delta(delta)

	if _floor_snap_restore_time_left > 0.0:
		_floor_snap_restore_time_left = maxf(0.0, _floor_snap_restore_time_left - delta)
		if _floor_snap_restore_time_left <= 0.0:
			floor_snap_length = _floor_snap_restore_value

	if _respawn_time_left > 0.0:
		_respawn_time_left = maxf(0.0, _respawn_time_left - delta)
		if _respawn_time_left <= 0.0:
			_on_respawn_timer_timeout()

	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)

	if _is_dead:
		_process_die(delta)
		move_and_slide()
		return

	if is_on_floor():
		_air_attack_count = 0

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# Recharge dash charges
	if _dash_charges < max_dash_charges:
		_dash_recharge_timer -= delta
		if _dash_recharge_timer <= 0.0:
			_dash_charges += 1
			_dash_recharge_timer = dash_cooldown

	if _current_state != State.RESPAWN and Input.is_action_just_pressed("throw") and _try_flying_thunder_god_teleport():
		return

	# Handle state-specific logic
	match _current_state:
		State.IDLE:
			_process_idle(delta)
		State.IDLE_TO_RUN:
			_process_idle_to_run(delta)
		State.RUN:
			_process_run(delta)
		State.RUN_TO_IDLE:
			_process_run_to_idle(delta)
		State.JUMP:
			_process_jump(delta)
		State.JUMP_TO_FALL:
			_process_jump_to_fall(delta)
		State.DOUBLE_JUMP:
			_process_double_jump(delta)
		State.FALL:
			_process_fall(delta)
		State.LANDING:
			_process_landing(delta)
		State.WALL_SLIDE:
			_process_wall_slide(delta)
		State.THROW:
			_process_throw(delta)
		State.AIR_THROW:
			_process_air_throw(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DASH:
			_process_dash(delta)
		State.DIE:
			_process_die(delta)
		State.RESPAWN:
			_process_respawn(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, true)
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.THROW)
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# Drop through one-way platform: S + Space
		if Input.is_action_pressed("move_down") and _try_drop_through_platform():
			_change_state(State.FALL)
			return
		_change_state(State.JUMP)
		return
	if not is_on_floor():
		_change_state(State.FALL)
		return
	var input_dir := _get_move_input()
	if absf(input_dir) > 0.1:
		_update_facing(input_dir)
		_change_state(State.IDLE_TO_RUN)

func _process_idle_to_run(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, true)
	if not is_on_floor():
		_change_state(State.FALL)
		return
	if Input.is_action_just_pressed("jump"):
		_change_state(State.JUMP)
		return
	# AnimationFinished callback sets state to Run when transition completes

func _process_run(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, true)
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.THROW)
		return
	if not is_on_floor():
		_change_state(State.FALL)
		return
	if Input.is_action_just_pressed("jump"):
		# Drop through one-way platform: S + Space
		if Input.is_action_pressed("move_down") and _try_drop_through_platform():
			_change_state(State.FALL)
			return
		_change_state(State.JUMP)
		return
	var input_dir := _get_move_input()
	if absf(input_dir) < 0.1:
		_change_state(State.RUN_TO_IDLE)
		return
	_update_facing(input_dir)

func _process_run_to_idle(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, true)
	if not is_on_floor():
		_change_state(State.FALL)
		return
	if Input.is_action_just_pressed("jump"):
		_change_state(State.JUMP)
		return
	var input_dir := _get_move_input()
	if absf(input_dir) > 0.1:
		_update_facing(input_dir)
		_change_state(State.IDLE_TO_RUN)
		return
	# AnimationFinished callback handles transition to Idle

func _process_jump(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, false)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	if Input.is_action_just_pressed("jump") and _has_double_jump and enable_double_jump:
		_change_state(State.DOUBLE_JUMP)
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.AIR_THROW)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if velocity.y > 0.0:
		_change_state(State.JUMP_TO_FALL)
		return
	if is_on_floor():
		_change_state(State.LANDING)

func _process_jump_to_fall(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, false)
	if Input.is_action_just_pressed("jump") and _has_double_jump and enable_double_jump:
		_change_state(State.DOUBLE_JUMP)
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.AIR_THROW)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if is_on_floor():
		_change_state(State.LANDING)
		return
	_detect_wall_slide()
	# AnimationFinished callback handles transition to Fall

func _process_double_jump(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, false)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.AIR_THROW)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if velocity.y > 0.0:
		_change_state(State.FALL)
		return
	if is_on_floor():
		_change_state(State.LANDING)

func _process_fall(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, false)
	if Input.is_action_just_pressed("jump") and _has_double_jump and enable_double_jump:
		_change_state(State.DOUBLE_JUMP)
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.AIR_THROW)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	if is_on_floor():
		_change_state(State.LANDING)
		return
	# Wall slide detection
	_detect_wall_slide()

func _process_wall_slide(delta: float) -> void:
	# Slow gravity while on wall
	velocity.y = minf(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
	velocity.x = 0.0

	# Face away from wall
	_update_facing(-_wall_direction)

	# Wall jump
	if Input.is_action_just_pressed("jump"):
		velocity.x = -_wall_direction * wall_jump_horizontal_speed
		velocity.y = wall_jump_vertical_speed
		_has_double_jump = true # Restore double jump
		_update_facing(-_wall_direction)
		_change_state(State.JUMP)
		return
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("throw"):
		_change_state(State.AIR_THROW)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return

	# Let go of wall
	var input_dir := _get_move_input()
	var still_on_wall := is_on_wall() and ((_wall_direction == -1 and input_dir < -0.1) or (_wall_direction == 1 and input_dir > 0.1))
	if not still_on_wall:
		_change_state(State.FALL)
		return
	if is_on_floor():
		_change_state(State.LANDING)

func _process_landing(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, true)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		return
	if Input.is_action_just_pressed("attack") and _try_attack():
		return
	var input_dir := _get_move_input()
	if absf(input_dir) > 0.1:
		_update_facing(input_dir)
		_change_state(State.IDLE_TO_RUN)
		return
	# AnimationFinished callback handles transition to Idle

func _process_attack(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, is_on_floor())
	_update_attack_hitbox(delta)
	if _attack_timer > 0.0:
		_attack_timer -= delta
		_attack_afterimage_timer -= delta
		if _attack_afterimage_timer <= 0.0:
			spawn_afterimage()
			_attack_afterimage_timer = attack_afterimage_interval
		var next_velocity := _attack_direction * attack_speed
		if _attack_timer <= 0.0:
			next_velocity *= attack_exit_momentum_scale
		# Apply decay to upward lift in air
		if not is_on_floor() and next_velocity.y 	< 0.0:
			var lift_multiplier := maxf(-attack_gravity_scale, 1.0 - (_air_attack_count * air_attack_lift_decay))
			next_velocity.y *= lift_multiplier
		velocity = next_velocity

	# Dash cancels attack -> leave afterimage
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		spawn_afterimage()
		_change_state(State.DASH)
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		spawn_afterimage()
		_change_state(State.JUMP)
		return

func _process_throw(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, is_on_floor())
	# Dash cancels throw
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		spawn_afterimage()
		_change_state(State.DASH)
		return
	if not is_on_floor():
		_change_state(State.AIR_THROW)
		return

func _process_air_throw(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta, false)
	# Dash cancels air throw
	if Input.is_action_just_pressed("dash") and _dash_charges > 0:
		spawn_afterimage()
		_change_state(State.DASH)
		return
	if is_on_floor():
		_change_state(State.LANDING)
		return

func _instantiate_shuriken(override_angle = null) -> void:
	if shuriken_scene == null:
		push_error("Shuriken Scene is null! You need to drag 'Shuriken.tscn' into the 'Shuriken Scene' property in the Inspector on your character!")
		return
	if is_instance_valid(_active_shuriken):
		_active_shuriken.queue_free()

	var shuriken := shuriken_scene.instantiate() as Shuriken
	get_tree().current_scene.add_child(shuriken)
	var flip_offset := Vector2(shuriken_spawn_offset.x * _facing_direction, shuriken_spawn_offset.y)
	shuriken.global_position = global_position + flip_offset
	if override_angle != null:
		shuriken.direction = Vector2.RIGHT.rotated(override_angle)
	else:
		var mouse_pos := get_global_mouse_position()
		shuriken.direction = (mouse_pos - shuriken.global_position).normalized()
	shuriken.rotation = shuriken.direction.angle()
	_active_shuriken = shuriken
	shuriken_spawned.emit(shuriken)
	shuriken.tree_exiting.connect(func() -> void:
		if _active_shuriken == shuriken:
			_active_shuriken = null
	)

func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	# Override velocity during dash (no gravity)
	velocity.x = _facing_direction * dash_speed
	velocity.y = 0.0
	if _dash_timer <= 0.0:
		# Kill dash momentum so the character doesn't slide
		velocity = Vector2.ZERO
		_change_state(State.IDLE if is_on_floor() else State.FALL)

func _process_die(delta: float) -> void:
	# ApplyGravity(dt);
	_apply_friction(delta, is_on_floor())

func _process_respawn(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta, is_on_floor())

func _change_state(new_state: State) -> void:
	var previous_state := _current_state
	if new_state != State.ATTACK:
		_deactivate_attack_hitbox()
	_current_state = new_state
	match new_state:
		State.IDLE:
			play_animation("idle")
			_has_double_jump = true
		State.IDLE_TO_RUN:
			play_animation("idle_to_run")
		State.RUN:
			play_animation("run")
		State.RUN_TO_IDLE:
			play_animation("run_to_idle")
		State.JUMP:
			# Wall jump already sets velocity, only set jump velocity for ground jumps
			if previous_state != State.WALL_SLIDE:
				velocity.y = jump_velocity
			play_animation("jump")
			jumped.emit(&"wall_jump" if previous_state == State.WALL_SLIDE else &"jump")
		State.JUMP_TO_FALL:
			play_animation("jump_to_fall")
		State.DOUBLE_JUMP:
			_has_double_jump = false
			velocity.y = double_jump_velocity
			play_animation("double_jump")
			jumped.emit(&"double_jump")
		State.FALL:
			play_animation("fall")
		State.LANDING:
			_has_double_jump = true
			play_animation("landing")
			landed.emit()
		State.FALL_TO_IDLE:
			play_animation("fall_to_idle")
		State.ATTACK:
			_attack_direction = _get_slash_direction()
			_attack_timer = attack_duration
			_attack_afterimage_timer = 0.0
			_attack_hitbox_delay_timer = attack_hitbox_delay
			_attack_hitbox_remaining_timer = attack_hitbox_active_duration
			_configure_attack_hitbox()
			if not is_on_floor():
				_air_attack_count += 1
			_update_facing(_attack_direction.x)
			spawn_afterimage()
			attack_started.emit(_attack_direction)
			play_animation(_get_slash_animation_name())
		State.DASH:
			_dash_charges -= 1
			_dash_recharge_timer = dash_cooldown
			_dash_timer = dash_duration
			_invulnerability_timer = maxf(_invulnerability_timer, dash_invulnerability_duration)
			play_animation("dash")
			dashed.emit()
		State.THROW:
			if _pending_throw_angle != null:
				_update_facing(cos(_pending_throw_angle))
				play_animation("shuriken")
				_instantiate_shuriken(_pending_throw_angle)
				_pending_throw_angle = null
			else:
				var mouse_pos_throw := get_global_mouse_position()
				_update_facing(mouse_pos_throw.x - global_position.x)
				play_animation("shuriken")
				_instantiate_shuriken()
		State.AIR_THROW:
			if _pending_throw_angle != null:
				_update_facing(cos(_pending_throw_angle))
				play_animation("shuriken_air")
				_instantiate_shuriken(_pending_throw_angle)
				_pending_throw_angle = null
			else:
				var mouse_pos_air_throw := get_global_mouse_position()
				_update_facing(mouse_pos_air_throw.x - global_position.x)
				play_animation("shuriken_air")
				_instantiate_shuriken()
		State.WALL_SLIDE:
			play_animation("fall") # Reuse fall animation for wall slide
		State.DIE:
			_is_dead = true
			_invulnerability_timer = 0.0
			velocity = Vector2.ZERO
			play_animation("die")
		State.RESPAWN:
			velocity = Vector2.ZERO
			play_animation("respawn")

func _try_attack() -> bool:
	if _is_dead or _attack_cooldown_timer > 0.0:
		return false
	_change_state(State.ATTACK)
	return true

func die() -> void:
	if _is_dead or _current_state == State.RESPAWN:
		return
	_respawn_time_left = 0.0
	if is_instance_valid(_active_shuriken):
		_active_shuriken.queue_free()
	_pending_attack_angle = null
	_pending_throw_angle = null
	_attack_timer = 0.0
	_attack_cooldown_timer = 0.0
	_attack_afterimage_timer = 0.0
	_deactivate_attack_hitbox()
	current_health = 0
	_change_state(State.DIE)
	died.emit()
	_respawn_time_left = respawn_delay

func respawn(spawn_position: Vector2) -> void:
	_respawn_time_left = 0.0
	_is_dead = false
	_invulnerability_timer = 0.0
	_attack_timer = 0.0
	_attack_cooldown_timer = 0.0
	_attack_afterimage_timer = 0.0
	_deactivate_attack_hitbox()
	_dash_timer = 0.0
	_dash_charges = max_dash_charges
	_dash_recharge_timer = dash_cooldown
	_has_double_jump = true
	_air_attack_count = 0
	_pending_attack_angle = null
	_pending_throw_angle = null
	current_health = max_health
	velocity = Vector2.ZERO
	global_position = spawn_position
	set_checkpoint(spawn_position)
	_change_state(State.RESPAWN)
	respawned.emit(spawn_position)

func set_checkpoint(checkpoint_position: Vector2) -> void:
	_current_respawn_position = checkpoint_position
	checkpoint_set.emit(checkpoint_position)

func _on_respawn_timer_timeout() -> void:
	if is_instance_valid(self):
		respawn(_current_respawn_position)

func _try_flying_thunder_god_teleport() -> bool:
	if not is_instance_valid(_active_shuriken):
		return false
	var start_pos := global_position
	var target_pos := _active_shuriken.global_position
	if _active_shuriken.is_stuck:
		target_pos += _active_shuriken.stick_normal * teleport_arrival_offset
	_spawn_teleport_trail(start_pos, target_pos)
	_spawn_teleport_flash(start_pos, target_pos)
	global_position = target_pos
	velocity = Vector2.ZERO
	var delta_x := target_pos.x - start_pos.x
	if absf(delta_x) > 0.01:
		_update_facing(delta_x)
	if is_instance_valid(_active_shuriken):
		_active_shuriken.queue_free()
	teleported.emit(start_pos, target_pos)
	_change_state(State.IDLE if is_on_floor() else State.FALL)
	return true

func is_attack_active() -> bool:
	return _current_state == State.ATTACK and _attack_timer > 0.0

func is_deflect_window_active() -> bool:
	return _current_state == State.ATTACK and attack_hitbox != null and attack_hitbox.active

func receive_attack(hit_data: Dictionary) -> void:
	if _is_dead or _current_state == State.RESPAWN or is_invulnerable:
		return
	if _try_deflect_projectile_from_hit_data(hit_data):
		return
	if _try_deflect_melee(hit_data):
		return

	var damage := int(hit_data.get("damage", 1))
	current_health = max(0, current_health - damage)
	_invulnerability_timer = maxf(_invulnerability_timer, float(hit_data.get("invuln_time", 0.0)))
	velocity += hit_data.get("knockback", Vector2.ZERO)
	damage_taken.emit(hit_data, current_health)

	if current_health <= 0:
		die()

func _spawn_teleport_trail(from: Vector2, to: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if texture == null:
		return
	var count := maxi(2, teleport_afterimage_count)
	for i in range(count):
		var t := 1.0 if count == 1 else float(i) / float(count - 1)
		var ghost_color := teleport_afterimage_color
		ghost_color.a *= 1.0 - t * 0.6
		var ghost := Sprite2D.new()
		ghost.texture = texture
		ghost.flip_h = animated_sprite.flip_h
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.global_position = from.lerp(to, t)
		ghost.modulate = ghost_color
		get_tree().current_scene.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, teleport_afterimage_fade_duration)
		tween.tween_callback(ghost.queue_free)

func _spawn_teleport_flash(from: Vector2, to: Vector2) -> void:
	var diff := to - from
	if diff.length_squared() < 0.0001:
		return
	var dir := diff.normalized()
	var normal := dir.orthogonal()
	var flash_root := Node2D.new()
	get_tree().current_scene.add_child(flash_root)

	# Outer glow layers for impact.
	var glow_wide_color := teleport_flash_color
	glow_wide_color.a = 0.35
	var glow_mid_color := teleport_flash_color
	glow_mid_color.a = 0.72
	var glow_wide_start := glow_wide_color
	glow_wide_start.a = 0.03
	var glow_wide_end := glow_wide_color
	glow_wide_end.a = 0.78
	var glow_mid_start := glow_mid_color
	glow_mid_start.a = 0.05
	var glow_mid_end := glow_mid_color
	glow_mid_end.a = 0.92
	var core_start := teleport_flash_core_color
	core_start.a = 0.08
	var core_end := Color(1.0, 1.0, 1.0, 1.0)
	var hot_start := Color(1.0, 0.96, 0.96, 0.02)
	var hot_end := Color(1.0, 1.0, 1.0, 1.0)

	# Sharp wedge profile: needle-like start and much thicker destination.
	var glow_wide := _create_flash_line(from + normal * 2.0, to + normal * 2.0, teleport_flash_width * 2.9, glow_wide_color, 0.04, 2.1, glow_wide_start, glow_wide_end)
	var glow_mid := _create_flash_line(from - normal * 1.5, to - normal * 1.5, teleport_flash_width * 2.0, glow_mid_color, 0.045, 2.25, glow_mid_start, glow_mid_end)
	var core := _create_flash_line(from, to, teleport_flash_width * 0.21, teleport_flash_core_color, 0.03, 3.8, core_start, core_end)
	var core_hot := _create_flash_line(from, to, teleport_flash_width * 0.11, Color(1.0, 1.0, 1.0, 1.0), 0.02, 4.2, hot_start, hot_end)
	flash_root.add_child(glow_wide)
	flash_root.add_child(glow_mid)
	flash_root.add_child(core)
	flash_root.add_child(core_hot)
	_spawn_teleport_sparks(flash_root, from, to, dir, normal)
	var tween := flash_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash_root, "modulate:a", 0.0, teleport_flash_duration)
	tween.tween_property(glow_wide, "width", 0.0, teleport_flash_duration)
	tween.tween_property(glow_mid, "width", 0.0, teleport_flash_duration)
	tween.tween_property(core, "width", 0.0, teleport_flash_duration)
	tween.tween_property(core_hot, "width", 0.0, teleport_flash_duration)
	tween.set_parallel(false)
	tween.tween_callback(flash_root.queue_free)

func _create_flash_line(from: Vector2, to: Vector2, width: float, color: Color, start_width_scale := 1.0, end_width_scale := 1.0, start_color = null, end_color = null) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true

	# Make the beam thinner at the origin and thicker at the destination.
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, maxf(0.01, start_width_scale)))
	width_curve.add_point(Vector2(1.0, maxf(0.01, end_width_scale)))
	line.width_curve = width_curve

	var gradient := Gradient.new()
	gradient.add_point(0.0, start_color if start_color != null else color)
	gradient.add_point(1.0, end_color if end_color != null else color)
	line.gradient = gradient
	line.add_point(from)
	line.add_point(to)
	return line

func _spawn_teleport_sparks(parent: Node2D, from: Vector2, to: Vector2, dir: Vector2, normal: Vector2) -> void:
	var spark_count := maxi(0, teleport_spark_count)
	for _i in range(spark_count):
		var t := _rng.randf_range(0.0, 1.0)
		var side := _rng.randf_range(-teleport_spark_scatter, teleport_spark_scatter)
		var center := from.lerp(to, t) + normal * side
		var length := _rng.randf_range(8.0, 20.0)
		var angle := _rng.randf_range(-0.9, 0.9)
		var spark_dir := dir.rotated(angle)
		var p1 := center - spark_dir * (length * 0.5)
		var p2 := center + spark_dir * (length * 0.5)
		var spark_color := teleport_flash_core_color
		spark_color.a = _rng.randf_range(0.6, 1.0)
		var spark := _create_flash_line(p1, p2, _rng.randf_range(1.3, 3.0), spark_color)
		parent.add_child(spark)
		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "modulate:a", 0.0, teleport_spark_duration)
		tw.tween_property(spark, "width", 0.0, teleport_spark_duration)

func spawn_afterimage() -> void:
	# Create a ghost sprite at the current position
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = animated_sprite.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Position the ghost in world space
	ghost.global_position = animated_sprite.global_position
	ghost.modulate = afterimage_color

	# Add to the scene tree (as sibling of root, so it doesn't move with character)
	get_tree().current_scene.add_child(ghost)

	# Fade out and remove
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, afterimage_fade_duration)
	tween.tween_callback(ghost.queue_free)

func play_animation(anim_name: String) -> void:
	# Set correct loop mode before playing:
	# Only idle, run, fall should loop. Everything else plays once.
	if animation_player.has_animation(anim_name):
		var anim := animation_player.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING_ANIMATIONS else Animation.LOOP_NONE
	animation_player.play(anim_name)

func _on_animation_finished(anim_name: StringName) -> void:
	match String(anim_name):
		# Transition animations - advance to next state
		"idle_to_run":
			if _current_state == State.IDLE_TO_RUN:
				_change_state(State.RUN)
		"run_to_idle":
			if _current_state == State.RUN_TO_IDLE:
				_change_state(State.IDLE)
		"jump_to_fall":
			if _current_state == State.JUMP_TO_FALL:
				_change_state(State.FALL)
		"landing", "fall_to_idle":
			if _current_state == State.LANDING or _current_state == State.FALL_TO_IDLE:
				_change_state(State.IDLE)

		# Jump finishes - transition to fall if descending
		"jump":
			if _current_state == State.JUMP and velocity.y >= 0.0:
				_change_state(State.JUMP_TO_FALL)
		"double_jump":
			if _current_state == State.DOUBLE_JUMP and velocity.y >= 0.0:
				_change_state(State.FALL)
		"attack1", "jump_attack":
			if _current_state == State.ATTACK:
				_deactivate_attack_hitbox()
				_change_state(State.IDLE if is_on_floor() else State.FALL)
		"shuriken":
			if _current_state == State.THROW:
				_change_state(State.IDLE)
		"shuriken_air":
			if _current_state == State.AIR_THROW:
				_change_state(State.FALL)
		"dash":
			if _current_state == State.DASH:
				velocity = Vector2.ZERO
				_change_state(State.IDLE if is_on_floor() else State.FALL)
		"respawn":
			if _current_state == State.RESPAWN:
				_change_state(State.IDLE if is_on_floor() else State.FALL)

func _get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")

func get_time_scaled_delta(delta: float) -> float:
	if Engine.is_editor_hint():
		return delta
	return Chronos.get_delta_for_group(delta, Chronos.PLAYER_GROUP)

func _apply_gravity(delta: float, gravity_scale := 1.0) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * gravity_scale * delta, max_fall_speed)

func _apply_movement(delta: float, grounded: bool) -> void:
	var input_dir := _get_move_input()
	var accel := acceleration if grounded else air_acceleration
	var fric := friction if grounded else air_friction
	if absf(input_dir) > 0.1:
		velocity.x = move_toward(velocity.x, input_dir * move_speed, accel * delta)
		if grounded:
			_update_facing(input_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

func _apply_friction(delta: float, grounded: bool) -> void:
	var fric := friction if grounded else air_friction
	velocity.x = move_toward(velocity.x, 0.0, fric * delta)

func _update_facing(direction: float) -> void:
	if direction > 0.1:
		_facing_direction = 1
	elif direction < -0.1:
		_facing_direction = -1
	animated_sprite.flip_h = _facing_direction < 0

func _get_slash_direction() -> Vector2:
	if _pending_attack_angle != null:
		var pending_direction := Vector2.RIGHT.rotated(_pending_attack_angle)
		_pending_attack_angle = null
		if pending_direction.length_squared() >= 0.0001:
			return pending_direction.normalized()
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 0.0001:
		to_mouse = Vector2(_facing_direction, 0.0)
	return to_mouse.normalized()

func _get_slash_animation_name() -> String:
	if animation_player.has_animation("jump_attack"):
		return "jump_attack"
	if animation_player.has_animation("attack1"):
		return "attack1"
	return "dash"

func _ensure_combat_nodes() -> void:
	if hurtbox == null:
		hurtbox = Hurtbox2D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.position = Vector2(6.0, -20.0)
		var hurtbox_shape := CollisionShape2D.new()
		var hurtbox_rect := RectangleShape2D.new()
		hurtbox_rect.size = Vector2(18.0, 40.0)
		hurtbox_shape.shape = hurtbox_rect
		hurtbox.add_child(hurtbox_shape)
		add_child(hurtbox)

	if attack_hitbox == null:
		attack_hitbox = Hitbox2D.new()
		attack_hitbox.name = "PlayerAttackHitbox"
		var attack_shape := CollisionShape2D.new()
		var attack_rect := RectangleShape2D.new()
		attack_rect.size = attack_hitbox_size
		attack_shape.shape = attack_rect
		attack_hitbox.add_child(attack_shape)
		add_child(attack_hitbox)

	attack_hitbox.target_group = "Enemy"
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback = attack_knockback
	attack_hitbox.hitstun = attack_hitstun
	attack_hitbox.invuln_time = attack_invuln_time
	attack_hitbox.set_active(false)
	_configure_attack_hitbox()

func _configure_attack_hitbox() -> void:
	if attack_hitbox == null:
		return

	var direction := _attack_direction if _attack_direction.length_squared() >= 0.001 else Vector2(_facing_direction, 0.0)
	var normalized_direction := direction.normalized()
	attack_hitbox.position = attack_hitbox_origin_offset + normalized_direction * attack_hitbox_distance
	attack_hitbox.rotation = normalized_direction.angle()
	var collision := attack_hitbox.get_node_or_null("CollisionShape2D")
	if collision != null and collision.shape is RectangleShape2D:
		(collision.shape as RectangleShape2D).size = attack_hitbox_size

func _update_attack_hitbox(delta: float) -> void:
	if attack_hitbox == null:
		return

	if _attack_hitbox_delay_timer > 0.0:
		_attack_hitbox_delay_timer -= delta
		if _attack_hitbox_delay_timer <= 0.0 and _attack_hitbox_remaining_timer > 0.0:
			attack_hitbox.damage = attack_damage
			attack_hitbox.knockback = attack_knockback
			attack_hitbox.hitstun = attack_hitstun
			attack_hitbox.invuln_time = attack_invuln_time
			attack_hitbox.set_active(true)
	elif not attack_hitbox.active and _attack_hitbox_remaining_timer > 0.0:
		attack_hitbox.damage = attack_damage
		attack_hitbox.knockback = attack_knockback
		attack_hitbox.hitstun = attack_hitstun
		attack_hitbox.invuln_time = attack_invuln_time
		attack_hitbox.set_active(true)

	if attack_hitbox.active:
		_attack_hitbox_remaining_timer -= delta
		_process_projectile_parries()
		if _attack_hitbox_remaining_timer <= 0.0:
			_deactivate_attack_hitbox()

func _deactivate_attack_hitbox() -> void:
	_attack_hitbox_delay_timer = 0.0
	_attack_hitbox_remaining_timer = 0.0
	_parried_projectile_ids.clear()
	if attack_hitbox != null:
		attack_hitbox.set_active(false)

func _process_projectile_parries() -> void:
	if attack_hitbox == null or not attack_hitbox.active:
		return

	for area in attack_hitbox.get_overlapping_areas():
		if not (area is EnemyProjectile):
			continue
		_try_deflect_projectile(area as EnemyProjectile)

func _try_deflect_projectile_from_hit_data(hit_data: Dictionary) -> bool:
	var source = hit_data.get("source")
	if not (source is EnemyProjectile):
		return false
	return _try_deflect_projectile(source as EnemyProjectile)

func _try_deflect_projectile(projectile: EnemyProjectile) -> bool:
	if not is_deflect_window_active():
		return false
	if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
		return false
	if projectile.target_group != "Player":
		return false

	var projectile_id := projectile.get_instance_id()
	if _parried_projectile_ids.has(projectile_id):
		return false
	_parried_projectile_ids[projectile_id] = true

	var deflect_direction := -projectile.direction
	if deflect_direction.length_squared() < 0.0001:
		deflect_direction = Vector2(_facing_direction, 0.0)
	projectile.deflect(self, deflect_direction)
	_emit_deflect_success({
		"kind": "projectile",
		"source": projectile,
		"impact_position": projectile.global_position,
		"attack_direction": deflect_direction.normalized(),
	})
	return true

func _try_deflect_melee(hit_data: Dictionary) -> bool:
	if not is_deflect_window_active():
		return false

	var hitbox_variant = hit_data.get("hitbox")
	if not (hitbox_variant is Hitbox2D):
		return false

	var incoming_hitbox := hitbox_variant as Hitbox2D
	if incoming_hitbox.target_group != "Player":
		return false

	var attacker := incoming_hitbox.get_parent()
	if attacker == null or not attacker.is_in_group("Enemy") or not attacker.has_method("receive_attack"):
		return false

	incoming_hitbox.set_active(false)

	var deflect_direction := Vector2(_facing_direction, 0.0)
	var receiver_global_position := global_position + deflect_direction * 12.0
	if attacker is Node2D:
		var attacker_node := attacker as Node2D
		receiver_global_position = attacker_node.global_position
		var to_attacker := attacker_node.global_position - global_position
		if to_attacker.length_squared() >= 0.0001:
			deflect_direction = to_attacker.normalized()

	var incoming_knockback: Vector2 = hit_data.get("knockback", Vector2.ZERO)
	var deflect_knockback := Vector2(-incoming_knockback.x, incoming_knockback.y)
	if absf(deflect_knockback.x) < 0.01:
		var horizontal_sign := signf(deflect_direction.x)
		if absf(horizontal_sign) < 0.01:
			horizontal_sign = float(_facing_direction)
		deflect_knockback.x = 180.0 * horizontal_sign
	if deflect_knockback.y >= -1.0:
		deflect_knockback.y = -28.0

	var deflect_hit_data := {
		"damage": 0,
		"source": self,
		"direction": deflect_direction,
		"attack_direction": deflect_direction,
		"knockback": deflect_knockback,
		"hitstun": maxf(0.12, float(hit_data.get("hitstun", 0.12))),
		"invuln_time": 0.0,
		"tags": PackedStringArray(["deflect"]),
		"impact_position": receiver_global_position,
		"attacker_global_position": global_position,
		"receiver_global_position": receiver_global_position,
		"receiver": attacker,
	}
	attacker.receive_attack(deflect_hit_data)

	_emit_deflect_success({
		"kind": "melee",
		"source": incoming_hitbox,
		"receiver": attacker,
		"impact_position": receiver_global_position,
		"attack_direction": deflect_direction,
	})
	return true

func _emit_deflect_success(context: Dictionary) -> void:
	Chronos.play_hitstop(deflect_hitstop_duration, deflect_hitstop_time_scale)
	deflect_success.emit(context)

func _detect_wall_slide() -> void:
	if enable_wall_jump and is_on_wall() and not is_on_floor():
		var input_dir := _get_move_input()
		var wall_normal := get_wall_normal()
		# Only wall slide if player is pressing toward the wall
		if (wall_normal.x > 0.0 and input_dir < -0.1) or (wall_normal.x < 0.0 and input_dir > 0.1):
			_wall_direction = -1 if wall_normal.x > 0.0 else 1
			_change_state(State.WALL_SLIDE)

func _try_drop_through_platform() -> bool:
	# Check if standing on a one-way collision platform
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		var is_one_way := false
		# StaticBody2D: check children for OneWayCollision shapes
		if collider is StaticBody2D:
			for child in collider.get_children():
				if child is CollisionShape2D and child.one_way_collision:
					is_one_way = true
					break
		# TileMapLayer / TileMap: assume one-way if player intentionally presses down+jump
		elif collider is TileMap:
			var map_pos: Vector2i = collider.local_to_map(collider.to_local(collision.get_position()))
			var tile_data: TileData = collider.get_cell_tile_data(0, map_pos)
			if tile_data != null:
				var polygon_count: int = tile_data.get_collision_polygons_count(0)
				for j in range(polygon_count):
					is_one_way = tile_data.is_collision_polygon_one_way(0, j)
		elif collider is TileMapLayer:
			var map_pos_layer: Vector2i = collider.local_to_map(collider.to_local(collision.get_position()))
			var tile_data_layer: TileData = collider.get_cell_tile_data(map_pos_layer)
			if tile_data_layer != null:
				var polygon_count_layer: int = tile_data_layer.get_collision_polygons_count(0)
				for j in range(polygon_count_layer):
					is_one_way = tile_data_layer.is_collision_polygon_one_way(0, j)

		if is_one_way:
			# Disable floor snap to prevent snapping back onto the platform
			var prev_snap := floor_snap_length
			floor_snap_length = 0.0
			position += Vector2(0.0, 4.0)
			velocity = Vector2(velocity.x, 50.0)
			_floor_snap_restore_value = prev_snap
			_floor_snap_restore_time_left = 0.15
			return true
	return false

func on_virtual_attack_activated(aim_angle: float) -> void:
	if _is_dead or _current_state == State.RESPAWN or _current_state == State.ATTACK:
		return
	if not can_start_attack_from_current_state():
		return
	_pending_attack_angle = aim_angle
	if not _try_attack():
		_pending_attack_angle = null

## Handles throw event triggered directly by the on-screen Virtual Direction Button.
## Needs an angle in Radians from the button.
func on_virtual_throw_activated(aim_angle: float) -> void:
	if _try_flying_thunder_god_teleport():
		return
	# Don't throw if already throwing
	if _current_state == State.THROW or _current_state == State.AIR_THROW:
		return
	_pending_throw_angle = aim_angle
	if is_on_floor():
		_change_state(State.THROW)
	else:
		_change_state(State.AIR_THROW)

func can_start_attack_from_current_state() -> bool:
	match _current_state:
		State.IDLE, State.RUN, State.JUMP, State.JUMP_TO_FALL, State.DOUBLE_JUMP, State.FALL, State.WALL_SLIDE, State.LANDING:
			return true
		_:
			return false

func interact_with(node: Node) -> void:
	if node is LaserBeam:
		if not (is_dead or is_invulnerable):
			die()
