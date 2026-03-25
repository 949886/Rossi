extends Node2D

@export var enemy_max_health := 2
@export var enemy_hit_scale := 1.0
@export var enemy_death_scale := 1.15

func _ready() -> void:
	var spawn_callback := Callable(self, "_on_enemy_spawned")
	for spawner in get_tree().get_nodes_in_group("EnemySpawner"):
		if not (spawner is EnemySpawner2D):
			continue
		var typed_spawner := spawner as EnemySpawner2D
		if not typed_spawner.enemy_spawned.is_connected(spawn_callback):
			typed_spawner.enemy_spawned.connect(spawn_callback)
		var existing_enemy := typed_spawner.get_spawned_enemy()
		if existing_enemy != null:
			_configure_enemy(existing_enemy)

func _on_enemy_spawned(enemy: Node) -> void:
	_configure_enemy(enemy)

func _configure_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	enemy.set("max_health", enemy_max_health)
	enemy.set("blood_hit_scale", enemy_hit_scale)
	enemy.set("blood_death_scale", enemy_death_scale)
	enemy.set("show_debug_label", false)
	var debug_label := enemy.get_node_or_null("DebugLabel")
	if debug_label != null:
		debug_label.queue_free()
	if enemy.has_method("reset_for_encounter"):
		enemy.reset_for_encounter()
