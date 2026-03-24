extends Node
class_name EncounterController

@export var reset_keycode: Key = KEY_R
@export var toggle_vision_debug_keycode: Key = KEY_V
@export var player_path: NodePath
@export var reset_player_on_reset := true
@export var clear_projectiles_on_reset := true
@export var vision_debug_enabled := true

var _player: Node
var _player_spawn_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("EncounterController")
	_player = _resolve_player()
	if _player is Node2D:
		_player_spawn_position = (_player as Node2D).global_position
	_apply_vision_debug_state()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == reset_keycode:
		reset_encounter()
		return
	if event.keycode == toggle_vision_debug_keycode:
		set_vision_debug_enabled(not vision_debug_enabled)

func reset_encounter() -> void:
	var handled_enemies: Dictionary = {}

	for spawner in get_tree().get_nodes_in_group("EnemySpawner"):
		if spawner.has_method("get_spawned_enemy"):
			var enemy: Node = spawner.get_spawned_enemy()
			if enemy != null:
				handled_enemies[enemy.get_instance_id()] = true
		if spawner.has_method("reset_spawn"):
			spawner.reset_spawn()

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if handled_enemies.has(enemy.get_instance_id()):
			continue
		if enemy.has_method("reset_for_encounter"):
			enemy.reset_for_encounter()

	if clear_projectiles_on_reset:
		for projectile in get_tree().get_nodes_in_group("ResettableProjectile"):
			if projectile.has_method("reset_for_encounter"):
				projectile.reset_for_encounter()
			elif projectile is Node:
				projectile.queue_free()

	if reset_player_on_reset:
		_reset_player()

	for node in get_tree().get_nodes_in_group("EncounterResettable"):
		if node.has_method("reset_for_encounter"):
			node.reset_for_encounter()

func _resolve_player() -> Node:
	if player_path != NodePath():
		var explicit_player := get_node_or_null(player_path)
		if explicit_player != null:
			return explicit_player

	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		return players[0]
	return null

func _reset_player() -> void:
	if not is_instance_valid(_player):
		_player = _resolve_player()
	if not is_instance_valid(_player):
		return

	if _player.has_method("respawn"):
		var target_position := _player_spawn_position
		var checkpoint = _player.get("current_respawn_position")
		if checkpoint is Vector2 and checkpoint != Vector2.ZERO:
			target_position = checkpoint
		_player.respawn(target_position)
	elif _player is Node2D:
		(_player as Node2D).global_position = _player_spawn_position

func set_vision_debug_enabled(enabled: bool) -> void:
	vision_debug_enabled = enabled
	_apply_vision_debug_state()

func _apply_vision_debug_state() -> void:
	for sensor in get_tree().get_nodes_in_group("VisionSensor"):
		if sensor.has_method("set_visual_debug_enabled"):
			sensor.set_visual_debug_enabled(vision_debug_enabled)
