extends Area2D
class_name CombatHitbox2D

@export var damage := 1
@export var knockback := Vector2(180.0, -35.0)
@export var hitstun := 0.12
@export var invuln_time := 0.0
@export var target_group := ""
@export var one_hit_per_activation := true
@export var tags: PackedStringArray = []

var _active := false
var _already_hit: Dictionary = {}

var active: bool:
	get: return _active
	set(value): set_active(value)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	monitorable = false
	set_physics_process(true)
	set_active(false)

func _physics_process(_delta: float) -> void:
	if not _active:
		return

	for area in get_overlapping_areas():
		if not (area is CombatHurtbox2D):
			continue

		var hurtbox := area as CombatHurtbox2D
		var receiver := hurtbox.get_damage_receiver()
		if receiver == null:
			continue
		if target_group != "" and not receiver.is_in_group(target_group):
			continue

		var receiver_id := receiver.get_instance_id()
		if one_hit_per_activation and _already_hit.has(receiver_id):
			continue

		if receiver.has_method("receive_attack"):
			receiver.receive_attack(_build_hit_data())
			_already_hit[receiver_id] = true

func set_active(value: bool) -> void:
	_active = value
	monitoring = value
	monitorable = false
	if not value:
		_already_hit.clear()

func _build_hit_data() -> Dictionary:
	var direction := Vector2.RIGHT.rotated(global_rotation).normalized()
	var rotated_knockback := knockback.rotated(global_rotation)
	return {
		"damage": damage,
		"source": get_parent(),
		"direction": direction,
		"knockback": rotated_knockback,
		"hitstun": hitstun,
		"invuln_time": invuln_time,
		"tags": tags,
	}
