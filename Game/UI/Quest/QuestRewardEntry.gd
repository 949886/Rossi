extends PanelContainer
class_name QuestRewardEntry

@onready var _icon_rect: TextureRect = $Margin/HBox/Icon
@onready var _label: Label = $Margin/HBox/TextColumn/Label
@onready var _amount: Label = $Margin/HBox/TextColumn/Amount


func apply_view_model(view_model: Dictionary) -> void:
	_icon_rect.texture = view_model.get("icon") as Texture2D
	_icon_rect.visible = _icon_rect.texture != null
	_label.text = str(view_model.get("label", "Reward"))
	var amount := int(view_model.get("amount", 0))
	_amount.text = "x%d" % amount if amount > 0 else ""
	_label.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92))
	_amount.add_theme_color_override("font_color", Color(0.94, 0.84, 0.55))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.17, 0.21, 0.28, 0.92)
	panel_style.border_color = Color(0.38, 0.46, 0.58, 0.82)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)
