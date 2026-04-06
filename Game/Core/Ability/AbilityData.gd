@tool
extends Resource
class_name AbilityData

const CONFIG_PREFIX := "config/"

@export var id: StringName
@export var slot: StringName
@export var priority := 0
@export var input_action: StringName
@export var tags: PackedStringArray = PackedStringArray()
@export_storage var config_overrides: Dictionary = {}

## Only one of script and prefab should be set for an ability, as they are mutually exclusive.
@export var runtime_script: Script:
	set(value):
		if runtime_script == value: return
		runtime_script = value
		if runtime_script != null and prefab != null:
			prefab = null
		_notify_inspector_changed()
@export var prefab: PackedScene:
	set(value):
		if prefab == value: return
		prefab = value
		if prefab != null and runtime_script != null:
			runtime_script = null
		_notify_inspector_changed()


func get_overrided_config() -> Dictionary:
	return _get_effective_config()

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var runtime_properties := _get_runtime_configurable_properties()
	if runtime_properties.is_empty():
		return properties

	# These are not real member variables on AbilityData. They are virtual editor
	# properties that proxy into the `config` dictionary via _get/_set below.
#	properties.append({
#		"name": "Runtime",
#		"type": TYPE_NIL,
#		"usage": PROPERTY_USAGE_GROUP,
#	})
	properties.append({
		"name": "Config Override",
		"type": TYPE_NIL,
		"hint_string": CONFIG_PREFIX,
		"usage": PROPERTY_USAGE_SUBGROUP,
	})

	for property_info in runtime_properties:
		var editor_property := property_info.duplicate(true)
		editor_property.name = "%s%s" % [CONFIG_PREFIX, property_info.name]
		editor_property.usage = PROPERTY_USAGE_EDITOR | (int(property_info.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY)
		properties.append(editor_property)

	return properties

func _set(property: StringName, value) -> bool:
	var property_name := String(property)
	if not property_name.begins_with(CONFIG_PREFIX):
		return false

	# Persist only explicit overrides so the .tres file stays compact and keeps
	# following runtime-script defaults for untouched values.
	var config_key := property_name.trim_prefix(CONFIG_PREFIX)
	var default_value = _get_runtime_property_default(config_key)
	if value == default_value:
		config_overrides.erase(config_key)
	else:
		config_overrides[config_key] = value
	emit_changed()
	return true

func _get(property: StringName):
	var property_name := String(property)
	if not property_name.begins_with(CONFIG_PREFIX):
		return null

	var config_key := property_name.trim_prefix(CONFIG_PREFIX)
	if config_overrides.has(config_key):
		return config_overrides[config_key]
	# If the field has not been overridden in config yet, show the runtime script's
	# own exported default so the inspector behaves like a normal object editor.
	return _get_runtime_property_default(config_key)

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
	# Only the raw override dictionary is serialized. The public `config` view is
	# synthesized at runtime and shown in the editor through `config/<property>`.
	if p_name == "config_overrides":
		property.usage = PROPERTY_USAGE_STORAGE

func _property_can_revert(property: StringName) -> bool:
	var property_name := String(property)
	return property_name.begins_with(CONFIG_PREFIX)

func _property_get_revert(property: StringName):
	var property_name := String(property)
	if not property_name.begins_with(CONFIG_PREFIX):
		return null
	return _get_runtime_property_default(property_name.trim_prefix(CONFIG_PREFIX))

func _get_runtime_configurable_properties() -> Array[Dictionary]:
	if runtime_script == null:
		return []
	if not runtime_script.has_method("get_script_property_list"):
		return []

	var properties: Array[Dictionary] = []
	# Reuse the runtime script's own exported property metadata so the generated
	# inspector fields inherit types, hints, ranges, enums, etc.
	for property_info in runtime_script.get_script_property_list():
		if not _is_runtime_config_property(property_info):
			continue
		properties.append(property_info)
	return properties

func _is_runtime_config_property(property_info: Dictionary) -> bool:
	var usage := int(property_info.get("usage", 0))
	# Only expose properties that are both editor-visible and serializable.
	if (usage & PROPERTY_USAGE_EDITOR) == 0:
		return false
	if (usage & PROPERTY_USAGE_STORAGE) == 0:
		return false

	var type := int(property_info.get("type", TYPE_NIL))
	if type == TYPE_NIL:
		return false

	var property_name := String(property_info.get("name", ""))
	if property_name.is_empty():
		return false
	# These fields are already owned by AbilityData itself, so mirroring them from
	# the runtime script would create duplicate/conflicting inspector entries.
	if _get_reserved_config_keys().has(property_name):
		return false
	return true

func _get_runtime_property_default(property_name: String):
	if runtime_script == null:
		return null

	# Ask the script resource for the exported property's declared default value.
	# This is more reliable than instantiating a temporary node/resource and
	# reading back the property, especially for script classes with custom setup.
	var default_value = runtime_script.get_property_default_value(StringName(property_name))
	if default_value != null:
		return default_value

	if not runtime_script.can_instantiate():
		return null

	# Fallback for script types where the default value API doesn't yield a value.
	var instance = runtime_script.new()
	if instance == null:
		return null

	var value = instance.get(property_name)
	if instance is Object and not (instance is RefCounted):
		instance.free()
	return value

func _get_effective_config() -> Dictionary:
	var effective_config := {}
	for property_info in _get_runtime_configurable_properties():
		var property_name := String(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		effective_config[property_name] = _get_runtime_property_default(property_name)

	for property_name in config_overrides.keys():
		effective_config[property_name] = config_overrides[property_name]

	return effective_config

func _get_reserved_config_keys() -> Dictionary:
	var reserved_config_keys: Dictionary = {}

	var ability := Ability.new()
	if ability == null:
		return reserved_config_keys

	for property_info in ability.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		reserved_config_keys[property_name] = true

	ability.free()

	return reserved_config_keys

func _notify_inspector_changed() -> void:
	# Changing the runtime source changes the synthetic property list, so the
	# inspector must be told to rebuild itself immediately.
	notify_property_list_changed()
	emit_changed()
