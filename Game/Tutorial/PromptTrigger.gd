extends Area2D
class_name PromptTrigger

@export var controller_path: NodePath
@export var step_id := ""
@export_multiline var prompt_text := ""
@export var key_labels: Array[String] = []

var _controller: TutorialProgressController
var _player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_controller = _resolve_controller()
	if _controller != null:
		var player := _controller.get_node_or_null(_controller.player_path)
		if player != null and player.has_signal("respawned"):
			player.respawned.connect(_on_player_respawned)
	call_deferred("_check_initial_overlap")

func _resolve_controller() -> TutorialProgressController:
	if not controller_path.is_empty():
		return get_node_or_null(controller_path) as TutorialProgressController
	return get_node_or_null("../../ProgressController") as TutorialProgressController

func _check_initial_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _player_inside:
			return

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	if _controller == null:
		return
	if not step_id.is_empty() and _controller.is_step_completed(step_id):
		return

	_player_inside = true
	_controller.show_prompt_text(prompt_text, key_labels)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	if _controller == null:
		return

	_player_inside = false
	_controller.hide_prompt_text(prompt_text)

func _on_player_respawned(_spawn_position: Vector2) -> void:
	_player_inside = false
	call_deferred("_check_initial_overlap")
