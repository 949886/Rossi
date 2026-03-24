extends Node2D

var _joystick
var _jump_button
var _attack_button
var _player: ColorRect
var _info_label: Label

var _player_velocity := Vector2.ZERO
var _is_jumping := false
var _jump_timer := 0.0
var _original_scale := Vector2.ONE
var _current_mode := 0

const MOVE_SPEED := 300.0
const FRICTION := 8.0

func _ready() -> void:
	_create_ui()
	_create_player()

func _process(delta: float) -> void:
	if _joystick:
		var input: Vector2 = _joystick.output
		_player_velocity = _player_velocity.lerp(input * MOVE_SPEED, FRICTION * delta)
		_player.position += _player_velocity * delta

		var screen_size := get_viewport_rect().size
		_player.position = Vector2(
			clampf(_player.position.x, 0.0, screen_size.x - _player.size.x),
			clampf(_player.position.y, 0.0, screen_size.y - _player.size.y)
		)

		_info_label.text = "Output: (%.2f, %.2f)\nStrength: %.2f\nAngle: %.1f deg\nPressed: %s" % [
			input.x,
			input.y,
			_joystick.strength,
			rad_to_deg(_joystick.angle),
			str(_joystick.is_pressed),
		]

	if _is_jumping:
		_jump_timer += delta * 6.0
		var jump_height := sin(_jump_timer * PI) * 30.0
		_player.scale = _original_scale * (1.0 + jump_height / 100.0)
		if _jump_timer >= 1.0:
			_is_jumping = false
			_player.scale = _original_scale

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = -1
	canvas_layer.add_child(bg)
	add_child(canvas_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	_info_label = Label.new()
	_info_label.position = Vector2(20, 20)
	_info_label.add_theme_color_override("font_color", Color.WHITE)
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.text = "Touch the joystick to start"
	ui_layer.add_child(_info_label)

	var title := Label.new()
	title.text = "Virtual Joystick Demo"
	title.position = Vector2(20, 0)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(title)

	var joystick_container := Control.new()
	joystick_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_container.size = Vector2(300, 300)
	joystick_container.position = Vector2(20, -320)
	joystick_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(joystick_container)

	_joystick = VirtualJoystick.new()
	_joystick.mode = VirtualJoystick.JoystickMode.FIXED
	_joystick.visibility_mode = VirtualJoystick.VisibilityMode.FADE_IN_OUT
	_joystick.base_radius = 80.0
	_joystick.handle_radius = 35.0
	_joystick.dead_zone = 0.15
	_joystick.base_color = Color(0.2, 0.25, 0.35, 0.7)
	_joystick.handle_color = Color(0.6, 0.7, 0.9, 0.8)
	_joystick.handle_pressed_color = Color(0.8, 0.9, 1.0, 1.0)
	_joystick.position = Vector2(70, 70)
	_joystick.size = Vector2(160, 160)
	joystick_container.add_child(_joystick)

	_jump_button = VirtualButton.new()
	_jump_button.label = "B"
	_jump_button.button_radius = 40.0
	_jump_button.normal_color = Color(0.2, 0.35, 0.5, 0.7)
	_jump_button.pressed_color = Color(0.3, 0.6, 0.9, 0.95)
	_jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jump_button.size = Vector2(80, 80)
	_jump_button.position = Vector2(-200, -220)
	_jump_button.button_down.connect(_on_jump_pressed)
	ui_layer.add_child(_jump_button)

	_attack_button = VirtualButton.new()
	_attack_button.label = "A"
	_attack_button.button_radius = 40.0
	_attack_button.normal_color = Color(0.5, 0.2, 0.2, 0.7)
	_attack_button.pressed_color = Color(0.9, 0.3, 0.3, 0.95)
	_attack_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_attack_button.size = Vector2(80, 80)
	_attack_button.position = Vector2(-110, -130)
	_attack_button.button_down.connect(_on_attack_pressed)
	ui_layer.add_child(_attack_button)

	var mode_button := Button.new()
	mode_button.text = "Switch Mode"
	mode_button.position = Vector2(20, 110)
	mode_button.custom_minimum_size = Vector2(120, 35)
	mode_button.pressed.connect(_on_mode_switch_pressed)
	ui_layer.add_child(mode_button)

func _create_player() -> void:
	_player = ColorRect.new()
	_player.size = Vector2(50, 50)
	_player.color = Color(0.4, 0.7, 1.0)
	_player.position = get_viewport_rect().size / 2.0 - _player.size / 2.0
	_player.pivot_offset = _player.size / 2.0
	add_child(_player)

	var indicator := ColorRect.new()
	indicator.size = Vector2(10, 10)
	indicator.color = Color.WHITE
	indicator.position = Vector2(20, 5)
	_player.add_child(indicator)

func _on_jump_pressed() -> void:
	if not _is_jumping:
		_is_jumping = true
		_jump_timer = 0.0

func _on_attack_pressed() -> void:
	var original_color := _player.color
	_player.color = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_player, "color", original_color, 0.3)

func _on_mode_switch_pressed() -> void:
	_current_mode = (_current_mode + 1) % 3
	_joystick.mode = _current_mode
	print("Joystick Mode: %s" % _joystick.mode)
