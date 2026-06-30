extends Button
class_name QuestListEntry

@onready var _title_label: Label = $Margin/VBox/Title
@onready var _status_label: Label = $Margin/VBox/Status


func apply_view_model(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("title", ""))
	_status_label.text = str(view_model.get("status_label", ""))
	button_pressed = bool(view_model.get("is_selected", false))
	disabled = false
	_apply_styles(bool(view_model.get("is_selected", false)), bool(view_model.get("is_completed", false)))


func _apply_styles(is_selected: bool, is_completed: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.16, 0.20, 0.26, 0.82)
	base.border_color = Color(0.48, 0.58, 0.68, 0.55)
	base.set_border_width_all(1)
	base.set_corner_radius_all(8)
	base.set_content_margin_all(8)

	var hover := base.duplicate()
	hover.bg_color = Color(0.22, 0.27, 0.35, 0.92)

	var pressed := base.duplicate()
	pressed.bg_color = Color(0.80, 0.75, 0.60, 0.90) if is_selected else Color(0.22, 0.27, 0.35, 0.95)
	pressed.border_color = Color(0.95, 0.86, 0.58, 0.95)

	var completed_color := Color(0.82, 0.82, 0.82) if is_completed else Color(0.95, 0.96, 0.99)
	var status_color := Color(0.83, 0.79, 0.60) if is_selected else (Color(0.74, 0.80, 0.92) if not is_completed else Color(0.71, 0.82, 0.71))

	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", pressed)
	add_theme_color_override("font_color", completed_color)
	add_theme_color_override("font_focus_color", completed_color)
	add_theme_color_override("font_hover_color", completed_color)
	add_theme_color_override("font_pressed_color", completed_color)

	_title_label.add_theme_color_override("font_color", completed_color)
	_status_label.add_theme_color_override("font_color", status_color)
