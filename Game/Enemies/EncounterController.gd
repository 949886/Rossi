extends Node
class_name EncounterController

@export var reset_keycode: Key = KEY_R

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == reset_keycode:
		reset_encounter()

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
