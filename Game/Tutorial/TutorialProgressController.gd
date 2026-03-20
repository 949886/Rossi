extends Node
class_name TutorialProgressController

signal step_started(step_id: String)
signal step_completed(step_id: String)

@export var prompt_layer_path: NodePath
@export var player_path: NodePath

var _prompt_layer: TutorialPromptLayer
var _player: PlatformerCharacter2D
var _current_step := ""
var _completed_steps: Dictionary = {}
var _step_prompts: Dictionary = {}
var _visible_prompt_text := ""

func _ready() -> void:
	_prompt_layer = get_node_or_null(prompt_layer_path)
	_player = get_node_or_null(player_path)

	if _player != null and _player.has_signal("respawned"):
		_player.respawned.connect(_on_player_respawned)



func start_step(step_id: String, prompt_text: String, key_labels: Array) -> void:
	if step_id.is_empty() or _completed_steps.get(step_id, false):
		return

	_current_step = step_id
	_step_prompts[step_id] = {
		"text": prompt_text,
		"keys": key_labels.duplicate(),
	}

	if _prompt_layer != null:
		_prompt_layer.show_prompt(prompt_text, key_labels)
		_visible_prompt_text = prompt_text

	step_started.emit(step_id)

func complete_step(step_id: String) -> void:
	if step_id.is_empty() or _completed_steps.get(step_id, false):
		return

	_completed_steps[step_id] = true
	if _current_step == step_id:
		_current_step = ""
		if _prompt_layer != null:
			_prompt_layer.hide_prompt()
			_visible_prompt_text = ""

	step_completed.emit(step_id)

func is_step_completed(step_id: String) -> bool:
	return _completed_steps.get(step_id, false)

func show_current_prompt() -> void:
	if _current_step.is_empty() or _prompt_layer == null:
		return

	var prompt_data: Dictionary = _step_prompts.get(_current_step, {})
	if prompt_data.is_empty():
		return

	_prompt_layer.show_prompt(prompt_data.get("text", ""), prompt_data.get("keys", []))
	_visible_prompt_text = str(prompt_data.get("text", ""))

func show_prompt_text(prompt_text: String, key_labels: Array) -> void:
	if _prompt_layer == null:
		return
	_prompt_layer.show_prompt(prompt_text, key_labels)
	_visible_prompt_text = prompt_text

func hide_prompt_text(prompt_text: String = "") -> void:
	if _prompt_layer == null:
		return
	if not prompt_text.is_empty() and _visible_prompt_text != prompt_text:
		return
	_prompt_layer.hide_prompt()
	_visible_prompt_text = ""

func _on_player_respawned(_spawn_position: Vector2) -> void:
	show_current_prompt()
