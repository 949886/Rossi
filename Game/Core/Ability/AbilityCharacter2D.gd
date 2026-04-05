extends CharacterBody2D
class_name AbilityCharacter2D

@export var ability_definitions: Array[AbilityDefinition] = []

var _abilities_by_id: Dictionary = {}
var _ability_list: Array[Ability] = []
var _ability_dependencies: Dictionary = {}


func _ready() -> void:
	_initialize_abilities()


func _physics_process(delta: float) -> void:
	_process_abilities(delta)


func get_ability(id: StringName) -> Ability:
	return _abilities_by_id.get(id, null) as Ability


func has_ability(id: StringName) -> bool:
	return _abilities_by_id.has(id)


func grant_ability(ability_definition: AbilityDefinition) -> Ability:
	if ability_definition == null or ability_definition.runtime_script == null:
		push_warning("Cannot grant ability without runtime script.")
		return null

	var ability_instance = ability_definition.runtime_script.new()
	if not (ability_instance is Ability):
		push_warning("Runtime script does not inherit Ability: %s" % [ability_definition.runtime_script])
		if ability_instance is Node:
			(ability_instance as Node).queue_free()
		return null

	var ability := ability_instance as Ability
	ability.name = String(ability_definition.id) if ability_definition.id != StringName() else ability.name
	add_child(ability)
	if not _register_ability(ability, ability_definition):
		ability.queue_free()
		return null
	return ability


func remove_ability(id: StringName) -> void:
	var ability := get_ability(id)
	if ability == null:
		return
	_abilities_by_id.erase(id)
	_ability_list.erase(ability)
	ability.queue_free()


func try_activate_ability(id: StringName, payload: Dictionary = {}) -> bool:
	var ability := get_ability(id)
	if ability == null:
		return false
	return ability.activate(payload)


func resolve_ability_dependency(key: StringName, fallback: Variant = null) -> Variant:
	if _ability_dependencies.has(key):
		return _ability_dependencies[key]
	return fallback


func set_ability_dependency(key: StringName, value: Variant) -> void:
	_ability_dependencies[key] = value


func get_abilities() -> Array[Ability]:
	return _ability_list.duplicate()


func _initialize_abilities() -> void:
	_abilities_by_id.clear()
	_ability_list.clear()

	for child in get_children():
		if child is Ability:
			_register_ability(child as Ability, null)

	for definition in ability_definitions:
		grant_ability(definition)


func _register_ability(ability: Ability, ability_definition: AbilityDefinition) -> bool:
	if ability == null:
		return false

	ability.setup(self, ability_definition)
	var id := ability.get_ability_id()
	if id == StringName():
		push_warning("Encountered ability without id on %s." % [name])
		return false
	if _abilities_by_id.has(id):
		push_warning("Duplicate ability id '%s' on %s. The duplicate ability was ignored." % [id, name])
		return false

	_abilities_by_id[id] = ability
	_ability_list.append(ability)
	_ability_list.sort_custom(func(a, b) -> bool:
		if a.priority == b.priority:
			return String(a.get_ability_id()) < String(b.get_ability_id())
		return a.priority < b.priority
	)
	return true


func _process_abilities(delta: float) -> void:
	for ability in _ability_list:
		ability.tick(delta)


func _notify_abilities_state_changed(previous_state: Variant, new_state: Variant) -> void:
	for ability in _ability_list:
		ability.on_owner_state_changed(previous_state, new_state)
