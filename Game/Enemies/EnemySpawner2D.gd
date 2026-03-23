extends Node2D
class_name EnemySpawner2D

signal enemy_spawned(enemy: Node)
signal enemy_despawned

@export var enemy_scene: PackedScene
@export var spawn_on_ready := true
@export var respawn_on_reset := true
@export_range(-1, 1, 2) var facing_direction := 1

var _current_enemy: Node

func _ready() -> void:
	add_to_group("EnemySpawner")
	if spawn_on_ready:
		call_deferred("spawn_enemy")

func get_spawned_enemy() -> Node:
	return _current_enemy

func spawn_enemy() -> Node:
	if enemy_scene == null:
		return null
	if is_instance_valid(_current_enemy):
		return _current_enemy

	var enemy := enemy_scene.instantiate()
	get_parent().add_child(enemy)
	if enemy is Node2D:
		enemy.global_position = global_position
	if enemy.has_method("initialize_spawn"):
		enemy.initialize_spawn(global_position, facing_direction)

	_current_enemy = enemy
	enemy_spawned.emit(enemy)
	enemy.tree_exiting.connect(_on_enemy_tree_exiting)
	return enemy

func despawn_enemy() -> void:
	if is_instance_valid(_current_enemy):
		var enemy := _current_enemy
		_current_enemy = null
		enemy.queue_free()
		return
	enemy_despawned.emit()

func reset_spawn() -> void:
	if respawn_on_reset:
		despawn_enemy()
		call_deferred("spawn_enemy")
		return

	if is_instance_valid(_current_enemy) and _current_enemy.has_method("reset_for_encounter"):
		_current_enemy.reset_for_encounter()
	elif spawn_on_ready:
		spawn_enemy()

func _on_enemy_tree_exiting() -> void:
	_current_enemy = null
	enemy_despawned.emit()
