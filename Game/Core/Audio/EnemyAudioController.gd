extends Node
class_name EnemyAudioController

@export_group("Cues")
@export var alert_cue: AudioCue
@export var attack_windup_cue: AudioCue
@export var melee_attack_cue: AudioCue
@export var ranged_attack_cue: AudioCue
@export var hit_cue: AudioCue
@export var death_cue: AudioCue
@export var footstep_cue: AudioCue

@export_group("Footsteps")
@export var footstep_frames: PackedInt32Array = PackedInt32Array([2, 6])
@export var footstep_animations: PackedStringArray = PackedStringArray(["walk", "run"])

var _enemy: EnemyBase
var _last_event_time_by_key: Dictionary = {}
var _last_footstep_animation: StringName = &""
var _last_footstep_frame := -1


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	if _enemy == null:
		push_warning("EnemyAudioController must be a child of EnemyBase.")
		return

	if not _enemy.alert_started.is_connected(_on_alert_started):
		_enemy.alert_started.connect(_on_alert_started)
	if not _enemy.attack_windup_started.is_connected(_on_attack_windup_started):
		_enemy.attack_windup_started.connect(_on_attack_windup_started)
	if not _enemy.attack_performed.is_connected(_on_attack_performed):
		_enemy.attack_performed.connect(_on_attack_performed)
	if not _enemy.hit_taken.is_connected(_on_hit_taken):
		_enemy.hit_taken.connect(_on_hit_taken)
	if not _enemy.died.is_connected(_on_died):
		_enemy.died.connect(_on_died)
	if _enemy.animated_sprite != null and not _enemy.animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
		_enemy.animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)


func _on_alert_started(_target: Node) -> void:
	_play_cue(alert_cue, "alert", _enemy.global_position)


func _on_attack_windup_started() -> void:
	_play_cue(attack_windup_cue, "attack_windup", _enemy.global_position)


func _on_attack_performed() -> void:
	var cue := melee_attack_cue
	if _enemy is EnemyGangsterRanged and ranged_attack_cue != null:
		cue = ranged_attack_cue
	_play_cue(cue, "attack_performed", _enemy.global_position)


func _on_hit_taken(hit_data: Dictionary) -> void:
	var impact_position: Vector2 = hit_data.get("impact_position", _enemy.global_position)
	_play_cue(hit_cue, "hit", impact_position)


func _on_died() -> void:
	_play_cue(death_cue, "death", _enemy.global_position)


func _on_animated_sprite_frame_changed() -> void:
	if _enemy == null or _enemy.animated_sprite == null:
		return

	var animation_name := _enemy.animated_sprite.animation
	var frame := _enemy.animated_sprite.frame
	if animation_name != _last_footstep_animation:
		_last_footstep_animation = animation_name
		_last_footstep_frame = -1

	if not footstep_animations.has(String(animation_name)):
		return
	if footstep_frames.has(frame) and frame != _last_footstep_frame:
		_last_footstep_frame = frame
		_play_cue(footstep_cue, "footstep", _enemy.global_position)


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
