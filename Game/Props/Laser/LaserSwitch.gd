extends Node2D
class_name LaserSwitch

const LASER_BEAM_SCRIPT := preload("res://Game/Props/Laser/LaserBeam.gd")

@export var interaction_area_path: NodePath = NodePath("InteractionArea")
@export var target_laser_paths: Array[NodePath] = []
@export var interact_action := "interact"
@export var prompt_text := "Press F"
@export var prompt_offset := Vector2(0.0, -42.0)
@export var switch_size := Vector2(20.0, 30.0)
@export var active_color := Color(0.3, 1.0, 0.5, 1.0)
@export var inactive_color := Color(0.9, 0.25, 0.25, 1.0)

var _target_lasers: Array[Node2D] = []
var _interaction_area: Area2D
var _prompt_label: Label
var _player_in_range := false

func _ready() -> void:
	add_to_group("EncounterResettable")
	_interaction_area = get_node(interaction_area_path)
	_prompt_label = get_node("PromptLabel")
	_prompt_label.text = prompt_text
	_prompt_label.position = prompt_offset
	_resolve_targets()
	_update_prompt()
	queue_redraw()

func _process(_delta: float) -> void:
	_player_in_range = _has_player_in_range()
	_update_prompt()

	if _player_in_range and Input.is_action_just_pressed(interact_action):
		for laser in _target_lasers:
			if laser != null and laser.has_method("toggle"):
				laser.toggle()

		queue_redraw()

func _draw() -> void:
	var body_color := active_color if _has_any_laser_enabled() else inactive_color
	var body_rect := Rect2(Vector2(-switch_size.x * 0.5, -switch_size.y), switch_size)
	draw_rect(body_rect, body_color)
	draw_rect(Rect2(body_rect.position + Vector2(4.0, 4.0), body_rect.size - Vector2(8.0, 8.0)), body_color.darkened(0.4))

func _resolve_targets() -> void:
	_target_lasers.clear()

	for target_path in target_laser_paths:
		if target_path.is_empty():
			continue

		var laser := get_node_or_null(target_path) as Node2D
		if laser != null and laser.get_script() == LASER_BEAM_SCRIPT:
			_target_lasers.append(laser)

func _has_player_in_range() -> bool:
	for body in _interaction_area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			return true

	return false

func _update_prompt() -> void:
	_prompt_label.visible = _player_in_range

func _has_any_laser_enabled() -> bool:
	if _target_lasers.is_empty():
		return false

	for laser in _target_lasers:
		if bool(laser.get("is_enabled")):
			return true

	return false

func reset_for_encounter() -> void:
	_resolve_targets()
	_player_in_range = _has_player_in_range()
	_update_prompt()
	queue_redraw()
