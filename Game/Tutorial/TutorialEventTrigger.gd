extends Area2D
class_name TutorialEventTrigger

@export var controller_path: NodePath
@export var step_id := ""
@export var checkpoint_marker_path: NodePath
@export var one_shot := true
@export var gate_to_remove_path: NodePath

var _controller: TutorialProgressController
var _activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_controller = _resolve_controller()
	call_deferred("_check_initial_overlap")

func _resolve_controller() -> TutorialProgressController:
	if not controller_path.is_empty():
		return get_node_or_null(controller_path) as TutorialProgressController
	return get_node_or_null("../../ProgressController") as TutorialProgressController

func _resolve_checkpoint_marker() -> Node2D:
	if not checkpoint_marker_path.is_empty():
		return get_node_or_null(checkpoint_marker_path) as Node2D
	if step_id.is_empty():
		return null
	var marker_name := "%sCheckpoint" % _to_pascal_case(step_id)
	return get_node_or_null("../%s" % marker_name) as Node2D

func _resolve_gate_to_remove() -> Node:
	if not gate_to_remove_path.is_empty():
		return get_node_or_null(gate_to_remove_path)
	match step_id:
		"move":
			return get_node_or_null("../MoveGate")
		"dash":
			return get_node_or_null("../DashGate")
		_:
			return null

func _to_pascal_case(value: String) -> String:
	var parts := value.split("_")
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result

func _check_initial_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _activated and one_shot:
			return

func _on_body_entered(body: Node) -> void:
	if _activated and one_shot:
		return
	if not body.is_in_group("Player"):
		return
	if _controller == null:
		return

	_controller.complete_step(step_id)

	var marker := _resolve_checkpoint_marker()
	if marker != null and body.has_method("set_checkpoint"):
		body.set_checkpoint(marker.global_position)

	var gate := _resolve_gate_to_remove()
	if gate != null:
		if gate.has_method("open_gate"):
			gate.open_gate()
		elif gate.has_method("queue_free"):
			gate.queue_free()

	_activated = true
