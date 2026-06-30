@tool
extends Resource
class_name QuestObjectiveData

@export var objective_id: StringName
@export_multiline var description := ""
@export var event_key: StringName
@export_range(1, 99, 1) var required_count := 1
@export var target_display_name := ""
@export var auto_complete_on_match := false


func get_effective_required_count() -> int:
	return max(required_count, 1)
