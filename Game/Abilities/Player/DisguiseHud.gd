extends CanvasLayer
class_name DisguiseHud

@onready var _panel: PanelContainer = $MarginContainer/Panel
@onready var _status_label: Label = $MarginContainer/Panel/VBox/Status
@onready var _options_label: Label = $MarginContainer/Panel/VBox/Options

var _ability: DisguiseAbility


func _ready() -> void:
	visible = false
	_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.92)
	_resolve_ability()


func _process(_delta: float) -> void:
	_resolve_ability()
	if _ability == null:
		visible = false
		return

	visible = _ability.is_menu_open or _ability.is_disguised
	if not visible:
		return

	_status_label.text = _ability.get_status_text()
	_options_label.text = "\n".join(_ability.get_menu_lines())


func _resolve_ability() -> void:
	if _ability != null and is_instance_valid(_ability):
		return
	var player: Node = get_parent()
	if player == null:
		return
	_ability = player.get_node_or_null("DisguiseAbility") as DisguiseAbility
