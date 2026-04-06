@tool
extends Resource
class_name AbilityData

@export_group("Runtime")
## Only one of script and prefab should be set for an ability, as they are mutually exclusive.
@export var runtime_script: Script
@export var prefab: PackedScene

@export_group("Info")
@export var id: StringName
@export var slot: StringName
@export var priority := 0
@export var input_action: StringName
@export var tags: PackedStringArray = PackedStringArray()
@export var config: Dictionary = {}

func _validate_property(property: Dictionary) -> void:
	var p_name = property.name

	# If id is not set, try to generate one from the file name.
	if p_name == "id" and (not id or id == ""):
		if resource_path != "":
			var file_name := resource_path.get_file().get_basename().replace("_", " ").capitalize()
			id = file_name

	# Prevent setting both runtime_script and prefab at the same time, as they are mutually exclusive.
	if p_name == "prefab" and runtime_script != null:
		property.usage = PROPERTY_USAGE_STORAGE
	if p_name == "runtime_script" and prefab != null:
		property.usage = PROPERTY_USAGE_STORAGE