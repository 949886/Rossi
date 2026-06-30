extends Area2D
class_name QuestEventTrigger2D

@export var quest_controller_path: NodePath
@export var event_key: StringName
@export var one_shot := true
@export var event_payload: Dictionary = {}

var _quest_controller: QuestLogController
var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_quest_controller = _resolve_controller()
	call_deferred("_check_initial_overlap")


func _resolve_controller() -> QuestLogController:
	if not quest_controller_path.is_empty():
		return get_node_or_null(quest_controller_path) as QuestLogController
	return get_parent().get_node_or_null("QuestLogController") as QuestLogController


func _check_initial_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _triggered and one_shot:
			return


func _on_body_entered(body: Node) -> void:
	if _triggered and one_shot:
		return
	if not body.is_in_group("Player"):
		return
	if _quest_controller == null:
		return

	_quest_controller.record_event(event_key, event_payload)
	_triggered = true
