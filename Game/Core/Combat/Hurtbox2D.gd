extends Area2D
class_name Hurtbox2D

@export var receiver_path: NodePath

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true

func get_damage_receiver() -> Node:
	if receiver_path != NodePath():
		var target := get_node_or_null(receiver_path)
		if target != null:
			return target
	return get_parent()
