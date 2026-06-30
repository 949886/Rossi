extends Area2D
class_name QuestInteractTrigger2D

@export var quest_controller_path: NodePath
@export var event_key: StringName
@export var event_payload: Dictionary = {}
@export var interact_action := "interact"
@export var prompt_text := "Press F to interact"
@export var prompt_offset := Vector2(-40.0, -46.0)
@export var one_shot := true
@export var marker_color := Color(0.92, 0.82, 0.45, 0.95)

var _quest_controller: QuestLogController
var _player_inside := false
var _triggered := false
var _prompt_label: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_quest_controller = _resolve_controller()
	_ensure_prompt_label()
	_update_prompt()
	queue_redraw()
	call_deferred("_check_initial_overlap")


func _process(_delta: float) -> void:
	if _triggered and one_shot:
		_update_prompt()
		return

	if _player_inside and Input.is_action_just_pressed(interact_action) and _quest_controller != null:
		_quest_controller.record_event(event_key, event_payload)
		_triggered = true
		_update_prompt()
		queue_redraw()


func _draw() -> void:
	var color := marker_color.darkened(0.45) if _triggered else marker_color
	draw_circle(Vector2.ZERO, 16.0, color)
	draw_circle(Vector2.ZERO, 9.0, color.darkened(0.35))


func _resolve_controller() -> QuestLogController:
	if not quest_controller_path.is_empty():
		return get_node_or_null(quest_controller_path) as QuestLogController
	return get_parent().get_node_or_null("QuestLogController") as QuestLogController


func _ensure_prompt_label() -> void:
	_prompt_label = get_node_or_null("PromptLabel") as Label
	if _prompt_label != null:
		return

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.position = prompt_offset
	_prompt_label.text = prompt_text
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	add_child(_prompt_label)


func _check_initial_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _player_inside:
			return


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	_player_inside = true
	_update_prompt()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	_player_inside = false
	_update_prompt()


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.position = prompt_offset
	_prompt_label.text = prompt_text
	_prompt_label.visible = _player_inside and not (_triggered and one_shot)
