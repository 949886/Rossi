extends Area2D
class_name Hitbox2D

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
		if not (area is Hurtbox2D):
			continue

		var hurtbox := area as Hurtbox2D
		var receiver := hurtbox.get_damage_receiver()
		if receiver == null:
			continue
		if target_group != "" and not receiver.is_in_group(target_group):
			continue

		var receiver_id := receiver.get_instance_id()
		if one_hit_per_activation and _already_hit.has(receiver_id):
			continue

		if receiver.has_method("receive_attack"):
			receiver.receive_attack(_build_hit_data(hurtbox, receiver))
			_already_hit[receiver_id] = true

func set_active(value: bool) -> void:
	_active = value
	monitoring = value
	monitorable = false
	if not value:
		_already_hit.clear()

func _build_hit_data(hurtbox: Hurtbox2D, receiver: Node) -> Dictionary:
	var direction := Vector2.RIGHT.rotated(global_rotation).normalized()
	var rotated_knockback := knockback.rotated(global_rotation)
	var source := get_parent()
	var attacker_global_position := global_position
	if source is Node2D:
		attacker_global_position = (source as Node2D).global_position

	var receiver_global_position := hurtbox.global_position
	if receiver is Node2D:
		receiver_global_position = (receiver as Node2D).global_position

	var impact_position := hurtbox.global_position
	if hurtbox != null:
		impact_position = hurtbox.get_impact_position(global_position)

	return {
		"damage": damage,
		"source": source,
		"direction": direction,
		"attack_direction": direction,
		"knockback": rotated_knockback,
		"hitstun": hitstun,
		"invuln_time": invuln_time,
		"tags": tags,
		"impact_position": impact_position,
		"attacker_global_position": attacker_global_position,
		"receiver_global_position": receiver_global_position,
		"receiver": receiver,
	}
