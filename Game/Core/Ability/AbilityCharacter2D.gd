extends CharacterBody2D
class_name AbilityCharacter2D

@export var ability_data_list: Array[AbilityData] = []
var abilities: Dictionary[String, Ability] = {}:
	get: return abilities
	

func _ready() -> void:
	_initialize_abilities()

func _physics_process(_delta: float) -> void:
	pass

func has_ability(id: StringName) -> bool:
	return abilities.has(String(id))


func add_ability(ability_data: AbilityData) -> Ability:
	if ability_data == null or ability_data.runtime_script == null:
		push_warning("Cannot grant ability without runtime script.")
		return null

	var ability_instance = ability_data.runtime_script.new()
	if not (ability_instance is Ability):
		push_warning("Runtime script does not inherit Ability: %s" % [ability_data.runtime_script])
		if ability_instance is Node:
			(ability_instance as Node).queue_free()
		return null

	var ability := ability_instance as Ability
	if ability_data.id != StringName():
		ability.name = String(ability_data.id)
	add_child(ability)
	if not _register_ability(ability, ability_data):
		ability.queue_free()
		return null
	return ability


func remove_ability(id: StringName) -> void:
	var ability := abilities.get(String(id), null) as Ability
	if ability == null:
		return
	abilities.erase(String(id))
	ability.queue_free()


func try_activate_ability(id: StringName, payload: Dictionary = {}) -> bool:
	var ability := abilities.get(String(id), null) as Ability
	if ability == null:
		return false
	return ability.activate(payload)

func get_abilities() -> Array[Ability]:
	return get_sorted_abilities()	

func get_sorted_abilities() -> Array[Ability]:
	var sorted_abilities: Array[Ability] = []
	for value in self.abilities.values():
		if value is Ability:
			sorted_abilities.append(value as Ability)
	sorted_abilities.sort_custom(func(a: Ability, b: Ability) -> bool:
		if a.priority == b.priority:
			return String(a.get_ability_id()) < String(b.get_ability_id())
		return a.priority < b.priority
	)
	return sorted_abilities

func _initialize_abilities() -> void:
	abilities.clear()

	for child in get_children():
		if child is Ability:
			_register_ability(child as Ability, null)

	for ability_data in ability_data_list:
		add_ability(ability_data)


func _register_ability(ability: Ability, ability_data: AbilityData = null) -> bool:
	if ability == null:
		return false

	ability.setup(self, ability_data)
	var id := ability.get_ability_id()
	if id.is_empty():
		push_warning("Encountered ability without id on %s." % [name])
		return false
	var id_key := String(id)
	if abilities.has(id_key):
		push_warning("Duplicate ability id '%s' on %s. The duplicate ability was ignored." % [id, name])
		return false

	abilities[id_key] = ability
	return true


func _notify_abilities_state_changed(previous_state: Variant, new_state: Variant) -> void:
	for ability in get_sorted_abilities():
		ability.on_owner_state_changed(previous_state, new_state)
		

