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

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.22, 0.28, 0.85)
	panel_style.border_color = Color(0.76, 0.67, 0.42, 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)
