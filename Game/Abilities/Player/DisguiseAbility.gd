extends Ability
class_name DisguiseAbility

signal disguise_started(profile_id: StringName)
signal disguise_changed(profile_id: StringName)
signal disguise_broken(reason: String)
signal disguise_menu_opened
signal disguise_menu_closed

const ABILITY_ID := &"disguise"
const HARD_BREAK_STATES := [
	PlatformerCharacter2D.State.ATTACK,
	PlatformerCharacter2D.State.DASH,
	PlatformerCharacter2D.State.THROW,
	PlatformerCharacter2D.State.AIR_THROW,
	PlatformerCharacter2D.State.WALL_SLIDE,
]
const SAFE_CAST_STATES := [
	PlatformerCharacter2D.State.IDLE,
	PlatformerCharacter2D.State.IDLE_TO_RUN,
	PlatformerCharacter2D.State.RUN,
	PlatformerCharacter2D.State.RUN_TO_IDLE,
	PlatformerCharacter2D.State.LANDING,
]
const DEFAULT_PROFILE_PATHS := [
	"res://Game/Abilities/Player/Profiles/GangsterDisguiseProfile.tres",
	"res://Game/Abilities/Player/Profiles/ShieldSwatDisguiseProfile.tres",
]

@export var profiles: Array[DisguiseProfile] = []
@export_range(0.0, 2.0, 0.01) var transform_duration := 0.45
@export_range(0.0, 5.0, 0.01) var recognition_threshold := 1.0
@export_range(0.0, 4.0, 0.01) var suspicion_decay_per_second := 0.35
@export_range(0.0, 4.0, 0.01) var suspicion_gain_per_second := 0.45
@export_range(0.0, 4.0, 0.01) var suspicion_fast_move_bonus := 0.65
@export_range(0.0, 4.0, 0.01) var suspicion_close_range_bonus := 0.65
@export_range(0.0, 4.0, 0.01) var suspicion_airborne_bonus := 0.9

@onready var _player: PlatformerCharacter2D = get_parent() as PlatformerCharacter2D
@onready var _avatar_controller: DisguiseAvatarController = get_node_or_null("../DisguiseAvatarController") as DisguiseAvatarController

var _current_profile: DisguiseProfile
var _selected_index := 0
var _menu_open := false
var _base_move_speed := 0.0
var _recognition_by_enemy: Dictionary = {}

var is_menu_open: bool:
	get: return _menu_open

var is_disguised: bool:
	get: return _current_profile != null


func _ready() -> void:
	if ability_id == StringName():
		ability_id = ABILITY_ID
	_ensure_default_profiles()
	_base_move_speed = _player.move_speed if _player != null else 0.0
	_connect_player_signals()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var real_delta := Chronos.get_real_delta()
	_update_menu_input()
	_decay_recognition(real_delta)
	_break_for_incompatible_abilities()


func get_current_profile() -> DisguiseProfile:
	return _current_profile


func get_current_faction_id() -> StringName:
	if _current_profile == null:
		return StringName()
	return _current_profile.faction_id


func get_profiles() -> Array[DisguiseProfile]:
	return profiles


func get_selected_profile() -> DisguiseProfile:
	if profiles.is_empty():
		return null
	_selected_index = clampi(_selected_index, 0, profiles.size() - 1)
	return profiles[_selected_index]


func get_selected_index() -> int:
	return _selected_index


func set_selected_index(index: int) -> void:
	if profiles.is_empty():
		_selected_index = 0
		return
	_selected_index = clampi(index, 0, profiles.size() - 1)


func can_activate(_payload: Dictionary = {}) -> bool:
	return _can_transform_now()


func get_status_text() -> String:
	if _player == null:
		return "Disguise unavailable"
	if is_disguised:
		return "Current disguise: %s" % _current_profile.display_name
	if _menu_open and not _can_transform_now():
		return "Unsafe to transform"
	return "No disguise"


func get_menu_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for index in range(profiles.size()):
		var profile := profiles[index]
		var prefix := ">"
		if index != _selected_index:
			prefix = " "
		var suffix := ""
		if _current_profile == profile:
			suffix = "  [Active]"
		lines.append("%s %s%s" % [prefix, profile.display_name, suffix])
	return lines


func can_be_identified_by(enemy: EnemyBase) -> bool:
	if not is_disguised or enemy == null:
		return true
	if enemy.faction_id != _current_profile.faction_id:
		return true
	return false


func register_scrutiny(enemy: EnemyBase, delta: float) -> bool:
	if not is_disguised or enemy == null or delta <= 0.0:
		return false
	if enemy.faction_id != _current_profile.faction_id:
		return true

	var enemy_id: int = enemy.get_instance_id()
	var next_value: float = float(_recognition_by_enemy.get(enemy_id, 0.0))
	next_value += suspicion_gain_per_second * delta

	if _player.velocity.length() > _current_profile.suspicion_move_speed:
		next_value += suspicion_fast_move_bonus * delta
	if not _player.is_on_floor():
		next_value += suspicion_airborne_bonus * delta
	if enemy.global_position.distance_to(_player.global_position) <= 42.0:
		next_value += suspicion_close_range_bonus * delta

	_recognition_by_enemy[enemy_id] = minf(next_value, recognition_threshold)
	if next_value >= recognition_threshold:
		break_disguise("identified")
		return true
	return false


func break_disguise(reason := "manual") -> void:
	if not is_disguised:
		_menu_open = false
		return

	_current_profile = null
	_recognition_by_enemy.clear()
	_restore_base_move_speed()
	if _player != null and _player.animated_sprite != null:
		_player.animated_sprite.visible = true
		_player.animated_sprite.modulate = Color.WHITE
	if _avatar_controller != null:
		_avatar_controller.begin_reveal()
	disguise_broken.emit(reason)


func on_owner_state_changed(_previous_state: Variant, new_state: Variant) -> void:
	if not is_disguised:
		return
	if HARD_BREAK_STATES.has(new_state):
		break_disguise("action")


func _update_menu_input() -> void:
	if profiles.is_empty():
		return
	if Input.is_action_just_pressed(&"disguise_menu"):
		if is_disguised:
			break_disguise("manual")
			return
		_menu_open = true
		_selected_index = clampi(_selected_index, 0, max(0, profiles.size() - 1))
		disguise_menu_opened.emit()
		return
	if not _menu_open:
		return

	if Input.is_action_just_pressed(&"move_left"):
		_selected_index = wrapi(_selected_index - 1, 0, profiles.size())
	elif Input.is_action_just_pressed(&"move_right"):
		_selected_index = wrapi(_selected_index + 1, 0, profiles.size())

	if Input.is_action_just_released(&"disguise_menu"):
		_confirm_selection()


func _confirm_selection() -> void:
	_menu_open = false
	disguise_menu_closed.emit()
	var selected_profile: DisguiseProfile = get_selected_profile()
	if selected_profile == null:
		return
	if _current_profile == selected_profile:
		break_disguise("manual")
		return
	if not _can_transform_now():
		return
	_apply_disguise(selected_profile)


func _apply_disguise(profile: DisguiseProfile) -> void:
	if _player == null or profile == null:
		return
	var source_texture: Texture2D = _capture_player_texture()
	var source_flip_h: bool = _player.animated_sprite.flip_h if _player.animated_sprite != null else false
	_current_profile = profile
	_recognition_by_enemy.clear()
	_player.move_speed = _base_move_speed * maxf(0.1, profile.move_speed_multiplier)
	if _avatar_controller != null:
		_avatar_controller.transition_duration = transform_duration
		_avatar_controller.begin_transform(profile, source_texture, source_flip_h)
	if _player.animated_sprite != null:
		_player.animated_sprite.visible = false
	disguise_started.emit(profile.id)
	disguise_changed.emit(profile.id)


func _can_transform_now() -> bool:
	if _player == null or _player.is_dead:
		return false
	if not _player.is_on_floor():
		return false
	if not SAFE_CAST_STATES.has(_player.current_state):
		return false
	if _is_chronos_running():
		return false
	return not _is_enemy_observing_player()


func _is_enemy_observing_player() -> bool:
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not (node is EnemyBase):
			continue
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy.is_dead:
			continue
		if enemy.can_currently_see_candidate(_player):
			return true
	return false


func _break_for_incompatible_abilities() -> void:
	if not is_disguised:
		return
	if _is_chronos_running():
		break_disguise("chronos")


func _is_chronos_running() -> bool:
	if _player == null:
		return false
	var chronos_ability: Ability = _player.abilities.get("chronos", null) as Ability
	if chronos_ability == null:
		return false
	return bool(chronos_ability.get("is_chronos_running"))


func _decay_recognition(delta: float) -> void:
	if delta <= 0.0 or _recognition_by_enemy.is_empty():
		return

	var keys_to_remove: Array[int] = []
	for enemy_id in _recognition_by_enemy.keys():
		var next_value: float = maxf(0.0, float(_recognition_by_enemy[enemy_id]) - suspicion_decay_per_second * delta)
		if next_value <= 0.0:
			keys_to_remove.append(enemy_id)
		else:
			_recognition_by_enemy[enemy_id] = next_value
	for enemy_id in keys_to_remove:
		_recognition_by_enemy.erase(enemy_id)


func _capture_player_texture() -> Texture2D:
	if _player == null or _player.animated_sprite == null or _player.animated_sprite.sprite_frames == null:
		return null
	return _player.animated_sprite.sprite_frames.get_frame_texture(
		_player.animated_sprite.animation,
		_player.animated_sprite.frame
	)


func _restore_base_move_speed() -> void:
	if _player != null:
		_player.move_speed = _base_move_speed


func _connect_player_signals() -> void:
	if _player == null:
		return
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	if not _player.damage_taken.is_connected(_on_player_damaged):
		_player.damage_taken.connect(_on_player_damaged)
	if not _player.teleported.is_connected(_on_player_teleported):
		_player.teleported.connect(_on_player_teleported)
	if not _player.respawned.is_connected(_on_player_respawned):
		_player.respawned.connect(_on_player_respawned)


func _ensure_default_profiles() -> void:
	if not profiles.is_empty():
		return
	for profile_path in DEFAULT_PROFILE_PATHS:
		var loaded_profile: Resource = load(profile_path)
		if loaded_profile is DisguiseProfile:
			profiles.append(loaded_profile as DisguiseProfile)


func _on_player_died() -> void:
	break_disguise("death")


func _on_player_damaged(_hit_data: Dictionary, _current_health: int) -> void:
	break_disguise("damage")


func _on_player_teleported(_from_position: Vector2, _to_position: Vector2) -> void:
	break_disguise("teleport")


func _on_player_respawned(_spawn_position: Vector2) -> void:
	break_disguise("respawn")
