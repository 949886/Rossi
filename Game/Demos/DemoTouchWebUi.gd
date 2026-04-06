extends Node
class_name DemoTouchWebUi

const CHRONOS_ABILITY_ID := "chronos"

@export var player_path: NodePath
@export var touch_ui_path: NodePath = ^"../TouchUI"
@export var show_touch_info_panel := false

var _player: Node
var _touch_ui: TouchUI
var _joystick: Control
var _jump_button: Control
var _attack_button: Control
var _dash_button: Control
var _throw_button: Control
var _chronos_button: Control
var _info_label: Label
var _info_panel: PanelContainer
var _show_info := false
var _chronos_ability: ChronosAbility

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_touch_ui = get_node_or_null(touch_ui_path) as TouchUI
	if _touch_ui == null:
		return

	_joystick = _touch_ui.get_node_or_null("TouchControls/JoystickArea/Joystick") as Control
	_jump_button = _touch_ui.get_node_or_null("TouchControls/ButtonArea/JumpBtn") as Control
	_attack_button = _touch_ui.get_node_or_null("TouchControls/ButtonArea/AttackBtn") as Control
	_dash_button = _touch_ui.get_node_or_null("TouchControls/ButtonArea/DashBtn") as Control
	_throw_button = _touch_ui.get_node_or_null("TouchControls/ButtonArea/ThrowBtn") as Control
	_chronos_button = _touch_ui.get_node_or_null("TouchControls/ButtonArea/ChronosBtn") as Control
	_info_label = _touch_ui.get_node_or_null("InfoPanel/InfoLabel") as Label
	_info_panel = _touch_ui.get_node_or_null("InfoPanel") as PanelContainer
	_show_info = show_touch_info_panel
	_chronos_ability = _resolve_chronos_ability()

	_style_info_panel()
	if _info_panel != null:
		_info_panel.visible = _show_info

	_connect_direction_button(_attack_button, "on_virtual_attack_activated")
	_connect_direction_button(_throw_button, "on_virtual_throw_activated")
	_update_chronos_button()

func _process(_delta: float) -> void:
	_update_dash_button()
	_update_chronos_button()
	_update_info_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_show_info = not _show_info
		if _info_panel != null:
			_info_panel.visible = _show_info

	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		if _touch_ui != null:
			_touch_ui.toggle_touch_ui()
			if _info_panel != null:
				_info_panel.visible = _show_info and _touch_ui.is_touch_ui_visible()

func _style_info_panel() -> void:
	if _info_panel == null:
		return

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(8)
	_info_panel.add_theme_stylebox_override("panel", style_box)

func _connect_direction_button(button: Control, method_name: StringName) -> void:
	if button == null or _player == null or not _player.has_method(method_name):
		return

	var callable := Callable(_player, method_name)
	if not button.is_connected("direction_activated", callable):
		button.connect("direction_activated", callable)

func _update_dash_button() -> void:
	if _player == null or _dash_button == null:
		return

	var dash_charges = _player.get("dash_charges")
	var max_dash_charges = _player.get("max_dash_charges")
	var dash_recharge_progress = _player.get("dash_recharge_progress")
	if dash_charges != null:
		_dash_button.set("charge_count", dash_charges)
	if max_dash_charges != null:
		_dash_button.set("max_charge_count", max_dash_charges)
	if dash_recharge_progress != null:
		_dash_button.set("cooldown_progress", dash_recharge_progress)

func _update_chronos_button() -> void:
	if _chronos_button == null:
		return

	if _chronos_ability == null:
		_chronos_ability = _resolve_chronos_ability()

	var has_chronos := _chronos_ability != null
	_chronos_button.visible = has_chronos
	if not has_chronos:
		return

	if _chronos_ability.is_chronos_running:
		_chronos_button.modulate = Color.WHITE
	elif _chronos_ability.is_chronos_ready:
		_chronos_button.modulate = Color(0.9, 0.98, 1.0, 0.95)
	else:
		_chronos_button.modulate = Color(0.7, 0.7, 0.7, 0.55)

func _update_info_panel() -> void:
	if _info_label == null or not _show_info:
		return

	var output := Vector2.ZERO
	if _joystick != null:
		output = _joystick.get("output")

	_info_label.text = (
		"Joystick: (%.2f, %.2f)\nJump: %s  Attack: %s  Dash: %s\nThrow: %s  Chronos: %s"
		% [
			output.x,
			output.y,
			_on_off(_jump_button),
			_on_off(_attack_button),
			_on_off(_dash_button),
			_on_off(_throw_button),
			_chronos_status_text(),
		]
	)

func _on_off(button: Control) -> String:
	if button == null:
		return "off"
	return "ON" if bool(button.get("is_pressed")) else "off"

func _chronos_status_text() -> String:
	if _chronos_ability == null:
		return "n/a"
	return _on_off(_chronos_button)

func _resolve_chronos_ability() -> ChronosAbility:
	if _player == null:
		return null

	var abilities = _player.get("abilities")
	if abilities is Dictionary:
		return abilities.get(CHRONOS_ABILITY_ID, null) as ChronosAbility
	return null
