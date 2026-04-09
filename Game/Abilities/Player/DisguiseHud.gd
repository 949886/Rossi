extends CanvasLayer
class_name DisguiseHud

@onready var _status_label: Label = $Overlay/Status
@onready var _hint_label: Label = $Overlay/Hint
@onready var _wheel: DisguiseRadialMenu = $Overlay/Wheel

var _ability: DisguiseAbility


func _ready() -> void:
	visible = false
	_resolve_ability()


func _process(_delta: float) -> void:
	_resolve_ability()
	if _ability == null:
		visible = false
		return

	visible = _ability.is_menu_open
	if not visible:
		return

	_status_label.text = _ability.get_status_text()
	_hint_label.text = "Hold E, aim with mouse, release to confirm"
	_wheel.set_ability(_ability)


func _resolve_ability() -> void:
	if _ability != null and is_instance_valid(_ability):
		return
	var player: Node = get_parent()
	if player == null:
		return
	_ability = player.get_node_or_null("DisguiseAbility") as DisguiseAbility
	if _ability != null:
		_wheel.set_ability(_ability)
