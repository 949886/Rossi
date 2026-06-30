extends Node
class_name QuestDemoController

@export var quest_controller_path: NodePath = ^"../QuestLogController"
@export var enemy_paths: Array[NodePath] = []
@export var enemy_event_keys: PackedStringArray = PackedStringArray()

var _quest_controller: QuestLogController


func _ready() -> void:
	_quest_controller = get_node_or_null(quest_controller_path) as QuestLogController
	_connect_enemy_events()


func _connect_enemy_events() -> void:
	if _quest_controller == null:
		return

	for index in range(enemy_paths.size()):
		var enemy := get_node_or_null(enemy_paths[index]) as EnemyBase
		if enemy == null:
			continue
		var event_key := &""
		if index < enemy_event_keys.size():
			event_key = StringName(enemy_event_keys[index])
		if String(event_key).is_empty():
			continue

		var callable := Callable(self, "_on_enemy_died").bind(event_key)
		if not enemy.died.is_connected(callable):
			enemy.died.connect(callable)


func _on_enemy_died(event_key: StringName) -> void:
	if _quest_controller == null:
		return
	_quest_controller.record_event(event_key)
