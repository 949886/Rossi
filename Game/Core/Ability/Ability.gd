extends Node
class_name Ability

@export var ability_id: StringName
@export var slot: StringName
@export var priority := 0
@export var input_action: StringName
@export var tags: PackedStringArray = PackedStringArray()

var ability_owner
var data: AbilityData


func setup(next_owner, next_data: AbilityData = null) -> void:
	ability_owner = next_owner
	data = next_data

	if data != null:
		if data.id != StringName():
			ability_id = data.id
		if data.slot != StringName():
			slot = data.slot
		priority = data.priority
		if data.input_action != StringName():
			input_action = data.input_action
		if data.tags.size() > 0:
			tags = data.tags
		_apply_data_config(data.get_overrided_config())

	_on_setup()


func get_ability_id() -> StringName:
	return ability_id


func tick(_delta: float) -> void:
	pass


func can_activate(_payload: Dictionary = {}) -> bool:
	return ability_owner != null


func activate(payload: Dictionary = {}) -> bool:
	_on_activate(payload)
	if can_activate(payload):
		return true
	return false


func deactivate(reason := "") -> void:
	_on_deactivate(reason)

func on_owner_state_changed(_previous_state: Variant, _new_state: Variant) -> void:
	pass
	
func _on_setup() -> void:
	pass
	
func _on_activate(_payload: Dictionary) -> void:	
	pass

func _on_deactivate(_reason: String) -> void:
	pass

func _apply_data_config(config: Dictionary) -> void:
	for property_name in config.keys():
		set(property_name, config[property_name])
