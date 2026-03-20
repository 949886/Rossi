extends Node2D

var _joystick
var _jump_button
var _attack_button
var _dash_button
var _throw_button
var _info_label: Label
var _touch_controls: Control
var _player: CharacterBody2D
var _show_info := true

func _ready() -> void:
	_joystick = get_node_or_null("TouchUI/TouchControls/JoystickArea/Joystick")
	_jump_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/JumpBtn")
	_attack_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/AttackBtn")
	_dash_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/DashBtn")
	_throw_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/ThrowBtn")
	_info_label = get_node_or_null("TouchUI/InfoPanel/InfoLabel")
	_touch_controls = get_node_or_null("TouchUI/TouchControls")
	_player = get_node_or_null("Playground/CharacterBody2D")

	var info_panel := get_node_or_null("TouchUI/InfoPanel") as PanelContainer
	if info_panel:
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.5)
		style_box.set_corner_radius_all(6)
		style_box.set_content_margin_all(8)
		info_panel.add_theme_stylebox_override("panel", style_box)

	if _throw_button and _player and _player.has_method("on_virtual_throw_activated"):
		_throw_button.direction_activated.connect(Callable(_player, "on_virtual_throw_activated"))

func _process(_delta: float) -> void:
	if _player and _dash_button:
		_dash_button.charge_count = _player.get("dash_charges")
		_dash_button.max_charge_count = _player.get("max_dash_charges")
		_dash_button.cooldown_progress = _player.get("dash_recharge_progress")

	if _info_label and _show_info:
		var current_output: Vector2 = Vector2.ZERO
		if _joystick:
			current_output = _joystick.output
		_info_label.text = (
			"Joystick: (%.2f, %.2f)\nJump: %s  Attack: %s  Dash: %s  Throw: %s"
			% [
				current_output.x,
				current_output.y,
				"ON" if _jump_button and _jump_button.is_pressed else "off",
				"ON" if _attack_button and _attack_button.is_pressed else "off",
				"ON" if _dash_button and _dash_button.is_pressed else "off",
				"ON" if _throw_button and _throw_button.is_pressed else "off",
			]
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_show_info = not _show_info
		if _info_label:
			_info_label.visible = _show_info

	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		if _touch_controls:
			_touch_controls.visible = not _touch_controls.visible
