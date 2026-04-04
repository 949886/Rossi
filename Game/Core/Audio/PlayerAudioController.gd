extends Node
class_name PlayerAudioController

@export_group("Cues")
@export var jump_cue: AudioCue
@export var double_jump_cue: AudioCue
@export var wall_jump_cue: AudioCue
@export var land_cue: AudioCue
@export var dash_cue: AudioCue
@export var attack_swing_cue: AudioCue
@export var attack_hit_cue: AudioCue
@export var deflect_cue: AudioCue
@export var shuriken_throw_cue: AudioCue
@export var shuriken_stick_cue: AudioCue
@export var teleport_cue: AudioCue
@export var hurt_cue: AudioCue
@export var death_cue: AudioCue
@export var footstep_cue: AudioCue
@export var chronos_start_cue: AudioCue
@export var chronos_stop_cue: AudioCue

@export_group("Footsteps")
@export var run_footstep_frames: Array[int] = [13, 36]

var _player: PlatformerCharacter2D
var _last_event_time_by_key: Dictionary = {}
var _last_footstep_animation: StringName = &""
var _last_footstep_frame := -1


func _ready() -> void:
	call_deferred("_connect_player")


func _connect_player() -> void:
	_player = get_parent() as PlatformerCharacter2D
	if _player == null:
		push_warning("PlayerAudioController must be a child of PlatformerCharacter2D.")
		return

	if not _player.jumped.is_connected(_on_jumped):
		_player.jumped.connect(_on_jumped)
	if not _player.landed.is_connected(_on_landed):
		_player.landed.connect(_on_landed)
	if not _player.dashed.is_connected(_on_dashed):
		_player.dashed.connect(_on_dashed)
	if not _player.attack_started.is_connected(_on_attack_started):
		_player.attack_started.connect(_on_attack_started)
	if not _player.shuriken_spawned.is_connected(_on_shuriken_spawned):
		_player.shuriken_spawned.connect(_on_shuriken_spawned)
	if not _player.teleported.is_connected(_on_teleported):
		_player.teleported.connect(_on_teleported)
	if not _player.damage_taken.is_connected(_on_damage_taken):
		_player.damage_taken.connect(_on_damage_taken)
	if not _player.died.is_connected(_on_died):
		_player.died.connect(_on_died)
	if not _player.deflect_success.is_connected(_on_deflect_success):
		_player.deflect_success.connect(_on_deflect_success)
	if _player.animated_sprite != null and not _player.animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
		_player.animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	if _player.attack_hitbox != null and not _player.attack_hitbox.hit_connected.is_connected(_on_attack_hit_connected):
		_player.attack_hitbox.hit_connected.connect(_on_attack_hit_connected)
	var chronos_started_callable := Callable(self, "_on_chronos_started")
	if _player.has_signal(&"chronos_started") and not _player.is_connected(&"chronos_started", chronos_started_callable):
		_player.connect(&"chronos_started", chronos_started_callable)
	var chronos_stopped_callable := Callable(self, "_on_chronos_stopped")
	if _player.has_signal(&"chronos_stopped") and not _player.is_connected(&"chronos_stopped", chronos_stopped_callable):
		_player.connect(&"chronos_stopped", chronos_stopped_callable)


func _on_jumped(kind: StringName) -> void:
	match kind:
		&"jump":
			_play_cue(jump_cue, "jump", _player.global_position)
		&"double_jump":
			_play_cue(double_jump_cue, "double_jump", _player.global_position)
		&"wall_jump":
			_play_cue(wall_jump_cue, "wall_jump", _player.global_position)


func _on_landed() -> void:
	_play_cue(land_cue, "land", _player.global_position)


func _on_dashed() -> void:
	_play_cue(dash_cue, "dash", _player.global_position)


func _on_attack_started(_direction: Vector2) -> void:
	_play_cue(attack_swing_cue, "attack_swing", _player.global_position)


func _on_attack_hit_connected(hit_data: Dictionary, _hurtbox: Hurtbox2D, receiver: Node) -> void:
	if receiver == null or not receiver.is_in_group("Enemy"):
		return
	var impact_position: Vector2 = hit_data.get("impact_position", _player.global_position)
	_play_cue(attack_hit_cue, "attack_hit", impact_position)


func _on_shuriken_spawned(shuriken: Shuriken) -> void:
	_play_cue(shuriken_throw_cue, "shuriken_throw", _player.global_position)
	if shuriken != null and not shuriken.stuck.is_connected(_on_shuriken_stuck):
		shuriken.stuck.connect(_on_shuriken_stuck)


func _on_shuriken_stuck(impact_position: Vector2, _normal: Vector2, _target: Node) -> void:
	_play_cue(shuriken_stick_cue, "shuriken_stick", impact_position)


func _on_teleported(_from_position: Vector2, to_position: Vector2) -> void:
	_play_cue(teleport_cue, "teleport", to_position)


func _on_damage_taken(_hit_data: Dictionary, _current_health: int) -> void:
	_play_cue(hurt_cue, "hurt", _player.global_position)


func _on_died() -> void:
	_play_cue(death_cue, "death", _player.global_position)

func _on_deflect_success(context: Dictionary) -> void:
	var impact_position: Vector2 = context.get("impact_position", _player.global_position)
	_play_cue(deflect_cue if deflect_cue != null else attack_hit_cue, "deflect", impact_position)

func _on_chronos_started() -> void:
	_play_cue(chronos_start_cue, "chronos_start", _player.global_position)

func _on_chronos_stopped() -> void:
	_play_cue(chronos_stop_cue, "chronos_stop", _player.global_position)


func _on_animated_sprite_frame_changed() -> void:
	if _player == null or _player.animated_sprite == null:
		return

	var animation_name := _player.animated_sprite.animation
	var frame := _player.animated_sprite.frame
	if animation_name != _last_footstep_animation:
		_last_footstep_animation = animation_name
		_last_footstep_frame = -1

	if animation_name != &"run":
		return
	if run_footstep_frames.has(frame) and frame != _last_footstep_frame:
		_last_footstep_frame = frame
		_play_cue(footstep_cue, "footstep", _player.global_position)


func _play_cue(cue: AudioCue, key: String, position: Vector2) -> void:
	if cue == null or not cue.has_audio():
		return
	if not _can_trigger_event(key, cue.cooldown_sec):
		return
	SFX.play_cue(cue, position)


func _can_trigger_event(key: String, cooldown_sec: float) -> bool:
	if cooldown_sec <= 0.0:
		return true

	var now_sec := Time.get_ticks_msec() / 1000.0
	var next_allowed_sec := float(_last_event_time_by_key.get(key, -INF))
	if now_sec < next_allowed_sec:
		return false

	_last_event_time_by_key[key] = now_sec + cooldown_sec
	return true
