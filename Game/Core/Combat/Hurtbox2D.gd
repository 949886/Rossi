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

func get_impact_position(reference_global_position: Vector2) -> Vector2:
	var closest_position := global_position
	var closest_distance_squared := INF

	for child in get_children():
		if not (child is CollisionShape2D):
			continue

		var collision_shape := child as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue

		var candidate := _get_closest_point_on_shape(collision_shape, reference_global_position)
		var distance_squared := candidate.distance_squared_to(reference_global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_position = candidate

	return closest_position

func _get_closest_point_on_shape(collision_shape: CollisionShape2D, reference_global_position: Vector2) -> Vector2:
	var local_reference := collision_shape.to_local(reference_global_position)
	var shape := collision_shape.shape

	if shape is RectangleShape2D:
		var extents := (shape as RectangleShape2D).size * 0.5
		var local_clamped := Vector2(
			clampf(local_reference.x, -extents.x, extents.x),
			clampf(local_reference.y, -extents.y, extents.y)
		)
		return collision_shape.to_global(local_clamped)

	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		if local_reference.length_squared() <= radius * radius:
			return reference_global_position
		return collision_shape.to_global(local_reference.normalized() * radius)

	return collision_shape.global_position
