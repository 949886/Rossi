# Platformer + Virtual Joystick demo with scene-defined touch controls.
# Unlike PlatformerJoystickDemo.cs, this script does NOT create UI programmatically.
# All touch controls (joystick, buttons, info panel) are defined in PlatformerTouchDemo.tscn.

extends Node2D

# Node references - resolved from the scene tree
var _joystick
var _jump_button
var _attack_button
var _dash_button
var _throw_button
var _info_label: Label
var _touch_controls: Control
var _touch_ui: CanvasLayer

# Player reference for querying state
var _player

var _show_info := true

func _ready() -> void:
	# Resolve nodes placed in the .tscn scene
	_joystick = get_node_or_null("TouchUI/TouchControls/JoystickArea/Joystick")
	_jump_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/JumpBtn")
	_attack_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/AttackBtn")
	_dash_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/DashBtn")
	_throw_button = get_node_or_null("TouchUI/TouchControls/ButtonArea/ThrowBtn")
	_info_label = get_node_or_null("TouchUI/InfoPanel/InfoLabel")
	_touch_controls = get_node_or_null("TouchUI/TouchControls")
	_touch_ui = get_node_or_null("TouchUI")

	if _touch_ui != null:
		_touch_ui.visible = _should_show_touch_ui()

	# Apply a semi-transparent panel style to InfoPanel
	var info_panel := get_node_or_null("TouchUI/InfoPanel") as PanelContainer
	if info_panel != null:
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.5)
		style_box.set_corner_radius_all(6)
		style_box.set_content_margin_all(8)
		info_panel.add_theme_stylebox_override("panel", style_box)

	_player = get_node_or_null("Playground/CharacterBody2D")

	if _attack_button != null and _player != null and _player.has_method("on_virtual_attack_activated"):
		_attack_button.direction_activated.connect(Callable(_player, "on_virtual_attack_activated"))

	# Connect the directional throw button directly to the Player controller.
	if _throw_button != null and _player != null and _player.has_method("on_virtual_throw_activated"):
		_throw_button.direction_activated.connect(Callable(_player, "on_virtual_throw_activated"))

func _should_show_touch_ui() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true

	if OS.has_feature("web"):
		return _is_mobile_web_browser()

	return false

func _is_mobile_web_browser() -> bool:
	var result = JavaScriptBridge.eval("""
		(() => {
			const ua = navigator.userAgent || "";
			const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua);
			const touchPoints = navigator.maxTouchPoints || 0;
			const shortSide = Math.min(window.screen.width || 0, window.screen.height || 0);
			return mobileUa || (touchPoints > 1 && shortSide > 0 && shortSide <= 1024);
		})()
	""", true)
	return bool(result)

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
		if _touch_controls != null:
			_touch_controls.visible = not _touch_controls.visible
