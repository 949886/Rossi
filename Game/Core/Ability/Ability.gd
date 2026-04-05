extends Node
class_name Ability

@export var ability_id: StringName
@export var slot: StringName
@export var priority := 0
@export var input_action: StringName
@export var tags: PackedStringArray = PackedStringArray()

var ability_owner
var definition: AbilityDefinition


func setup(next_owner, next_definition: AbilityDefinition = null) -> void:
	ability_owner = next_owner
	definition = next_definition

	if definition != null:
		if definition.id != StringName():
			ability_id = definition.id
		if definition.slot != StringName():
			slot = definition.slot
		priority = definition.priority
		if definition.input_action != StringName():
			input_action = definition.input_action
		if definition.tags.size() > 0:
			tags = definition.tags
		_apply_definition_config(definition.config)

	_resolve_dependencies()
	_on_setup()


func get_ability_id() -> StringName:
	return ability_id


func tick(_delta: float) -> void:
	pass


func can_activate(_payload: Dictionary = {}) -> bool:
	return ability_owner != null


func activate(payload: Dictionary = {}) -> bool:
	if not can_activate(payload):
		return false
	return _activate(payload)


func deactivate(reason := "") -> void:
	_on_deactivate(reason)


func get_public_state() -> Dictionary:
	return {}


func on_owner_state_changed(_previous_state: Variant, _new_state: Variant) -> void:
	pass


func resolve_dependency(key: StringName, fallback: Variant = null) -> Variant:
	if ability_owner == null:
		return fallback
	@warning_ignore("unsafe_method_access")
	return ability_owner.resolve_ability_dependency(key, fallback)


func _activate(_payload: Dictionary) -> bool:
	return true


func _on_setup() -> void:
	pass


func _on_deactivate(_reason: String) -> void:
	pass


func _resolve_dependencies() -> void:
	pass


func _apply_definition_config(config: Dictionary) -> void:
	for property_name in config.keys():
		set(property_name, config[property_name])
