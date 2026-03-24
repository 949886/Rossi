# Platformer + Virtual Joystick demo with scene-defined touch controls.
# Unlike PlatformerJoystickDemo.cs, this script does NOT create UI programmatically.
# All touch controls (joystick, buttons, info panel) are defined in PlatformerTouchDemo.tscn.

extends Node2D

# Node references - resolved from the scene tree
@onready var _joystick = $"TouchUI/TouchControls/JoystickArea/Joystick"
@onready var _jump_button = $"TouchUI/TouchControls/ButtonArea/JumpBtn"
@onready var _attack_button = $"TouchUI/TouchControls/ButtonArea/AttackBtn"
@onready var _dash_button = $"TouchUI/TouchControls/ButtonArea/DashBtn"
@onready var _throw_button = $"TouchUI/TouchControls/ButtonArea/ThrowBtn"
@onready var _info_label: Label = $"TouchUI/InfoPanel/InfoLabel"
@onready var _touch_ui: TouchUI = $"TouchUI"
@onready var _info_panel: PanelContainer = $"TouchUI/InfoPanel"

# Player reference for querying state
@onready var _player = $"Playground/CharacterBody2D"

var _show_info := true

func _ready() -> void:
	# Apply a semi-transparent panel style to InfoPanel
	if _info_panel != null:
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.5)
		style_box.set_corner_radius_all(6)
		style_box.set_content_margin_all(8)
		_info_panel.add_theme_stylebox_override("panel", style_box)

	if _attack_button != null and _player != null and _player.has_method("on_virtual_attack_activated"):
		_attack_button.direction_activated.connect(Callable(_player, "on_virtual_attack_activated"))

	# Connect the directional throw button directly to the Player controller.
	if _throw_button != null and _player != null and _player.has_method("on_virtual_throw_activated"):
		_throw_button.direction_activated.connect(Callable(_player, "on_virtual_throw_activated"))

func _process(_delta: float) -> void:
	# Update Skill Button UI
	if _player != null and _dash_button != null:
		_dash_button.charge_count = _player.get("dash_charges")
		_dash_button.max_charge_count = _player.get("max_dash_charges")
		_dash_button.cooldown_progress = _player.get("dash_recharge_progress")

	if _info_label != null and _show_info:
		var output: Vector2 = _joystick.output if _joystick != null else Vector2.ZERO
		_info_label.text = (
			"Joystick: (%.2f, %.2f)\nJump: %s  Attack: %s  Dash: %s  Throw: %s"
			% [
				output.x,
				output.y,
				"ON" if _jump_button != null and _jump_button.is_pressed else "off",
				"ON" if _attack_button != null and _attack_button.is_pressed else "off",
				"ON" if _dash_button != null and _dash_button.is_pressed else "off",
				"ON" if _throw_button != null and _throw_button.is_pressed else "off",
			]
		)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle info panel with F1
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_show_info = not _show_info
		if _info_label != null:
			_info_label.visible = _show_info

	# Toggle touch controls with F2
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		if _touch_ui != null and _touch_ui.has_method("toggle_touch_ui"):
			_touch_ui.toggle_touch_ui()
