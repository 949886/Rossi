extends Button
class_name QuestListEntry

@onready var _accent: ColorRect = $Margin/Row/Accent
@onready var _title_label: Label = $Margin/Row/VBox/Title
@onready var _subtitle_label: Label = $Margin/Row/VBox/Subtitle
@onready var _status_label: Label = $Margin/Row/Status


func apply_view_model(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("title", ""))
	_subtitle_label.text = str(view_model.get("list_preview_text", ""))
	_status_label.text = str(view_model.get("status_label", ""))
	button_pressed = bool(view_model.get("is_selected", false))
	disabled = false
	_apply_styles(bool(view_model.get("is_selected", false)), bool(view_model.get("is_completed", false)))


func _apply_styles(is_selected: bool, is_completed: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.10, 0.14, 0.20, 0.42)
	base.border_color = Color(0.00, 0.00, 0.00, 0.0)
	base.set_border_width_all(1)
	base.set_corner_radius_all(12)
	base.set_content_margin_all(10)

	var hover := base.duplicate()
	hover.bg_color = Color(0.17, 0.22, 0.31, 0.68)

	var pressed := base.duplicate()
	pressed.bg_color = Color(0.32, 0.36, 0.49, 0.96) if is_selected else Color(0.17, 0.22, 0.31, 0.76)
	pressed.border_color = Color(0.91, 0.82, 0.55, 0.95) if is_selected else Color(0.00, 0.00, 0.00, 0.0)
	pressed.set_border_width_all(1 if is_selected else 0)

	var title_color := Color(0.97, 0.97, 0.98) if is_selected else Color(0.82, 0.85, 0.91)
	var subtitle_color := Color(0.72, 0.78, 0.88, 0.95) if is_selected else Color(0.54, 0.62, 0.74, 0.95)
	var status_color := Color(0.94, 0.84, 0.50) if not is_completed else Color(0.72, 0.84, 0.76)

	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", pressed)
	add_theme_color_override("font_color", title_color)
	add_theme_color_override("font_focus_color", title_color)
	add_theme_color_override("font_hover_color", title_color)
	add_theme_color_override("font_pressed_color", title_color)

	_accent.color = Color(0.93, 0.84, 0.55, 1.0) if is_selected else Color(0.53, 0.62, 0.76, 0.8)
	_title_label.add_theme_color_override("font_color", title_color)
	_subtitle_label.add_theme_color_override("font_color", subtitle_color)
	_status_label.add_theme_color_override("font_color", status_color)
