extends CanvasLayer
class_name TutorialPromptLayer

@export var prompt_position := Vector2(40.0, 36.0)
@export var prompt_width := 320.0
@export var letter_key_texture: Texture2D = preload("res://Game/Sprites/Input Devices/keyboard_Ui_Free_16x16.png")
@export var special_key_texture: Texture2D = preload("res://Game/Sprites/Input Devices/Keyboard_Ui_Free_32x32.png")
@export var mouse_texture: Texture2D = preload("res://Game/Sprites/Input Devices/Animation_clic_01_16x16.png")

var _ui_root: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _text_label: Label
var _keys_row: HBoxContainer

func _ready() -> void:
	layer = 32
	_build_ui()
	hide_prompt()

func show_prompt(prompt_text: String, key_labels: Array) -> void:
	if _panel == null:
		_build_ui()

	_text_label.text = prompt_text

	for child in _keys_row.get_children():
		child.queue_free()

	for key_label in key_labels:
		_keys_row.add_child(_create_key_badge(str(key_label)))

	visible = true
	_ui_root.visible = true
	_panel.visible = true
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)

func hide_prompt() -> void:
	if _ui_root != null:
		_ui_root.visible = false
	if _panel != null:
		_panel.visible = false
		_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = false

func _build_ui() -> void:
	if _ui_root != null:
		return

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_panel = PanelContainer.new()
	_panel.name = "PromptPanel"
	_panel.position = prompt_position
	_panel.custom_minimum_size = Vector2(prompt_width, 92.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_panel)

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.07, 0.11, 0.88)
	background.border_width_left = 2
	background.border_width_top = 2
	background.border_width_right = 2
	background.border_width_bottom = 2
	background.border_color = Color(0.54, 0.76, 1.0, 0.95)
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_right = 8
	background.corner_radius_bottom_left = 8
	background.content_margin_left = 12.0
	background.content_margin_top = 10.0
	background.content_margin_right = 12.0
	background.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", background)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_panel.add_child(_content)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.modulate = Color(0.95, 0.97, 1.0)
	_content.add_child(_text_label)

	_keys_row = HBoxContainer.new()
	_keys_row.add_theme_constant_override("separation", 8)
	_content.add_child(_keys_row)

func _create_key_badge(key_label: String) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(44.0, 44.0)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(44.0, 44.0)
	icon.texture = _get_texture_for_key(key_label)
	badge.add_child(icon)

	var text := Label.new()
	text.text = key_label
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size = Vector2(44.0, 44.0)
	text.add_theme_font_size_override("font_size", 15)
	text.modulate = Color(0.97, 0.98, 1.0)
	badge.add_child(text)

	return badge

func _get_texture_for_key(key_label: String) -> Texture2D:
	var label := key_label.to_upper()
	if label in ["LMB", "MOUSE1"]:
		return mouse_texture

	var special_texture := _get_special_key_texture(label)
	if special_texture != null:
		return special_texture

	return _get_letter_key_texture(label)

func _get_special_key_texture(label: String) -> Texture2D:
	if special_key_texture == null:
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = special_key_texture

	match label:
		"SHIFT":
			atlas.region = Rect2(0.0, 32.0, 32.0, 16.0)
			return atlas
		"SPACE":
			atlas.region = Rect2(192.0, 0.0, 96.0, 32.0)
			return atlas
		_:
			return null

func _get_letter_key_texture(label: String) -> Texture2D:
	if letter_key_texture == null:
		return null

	var index_map := {
		"A": Vector2i(0, 4),
		"D": Vector2i(0, 7),
		"Q": Vector2i(4, 4),
		"S": Vector2i(4, 5),
		"W": Vector2i(4, 7),
	}

	if not index_map.has(label):
		return null

	var cell: Vector2i = index_map[label]
	var atlas := AtlasTexture.new()
	atlas.atlas = letter_key_texture
	atlas.region = Rect2(float(cell.x * 48), float(cell.y * 16), 16.0, 16.0)
	return atlas
