extends Resource
class_name AbilityDefinition

@export var id: StringName
@export var runtime_script: Script
@export var slot: StringName
@export var priority := 0
@export var input_action: StringName
@export var tags: PackedStringArray = PackedStringArray()
@export var config: Dictionary = {}
