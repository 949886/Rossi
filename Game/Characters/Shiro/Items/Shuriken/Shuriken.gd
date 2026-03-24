extends Area2D
class_name Shuriken

@export var speed := 1000.0
@export var lifespan := 5.0
@export var afterimage_interval := 0.033334
@export var afterimage_duration := 0.25
@export var afterimage_color := Color(0.1, 0.5, 1.0, 0.6)

@onready var _sprite: Sprite2D = $"Sprite2D"

var direction := Vector2.RIGHT

var is_stuck: bool:
	get: return _stuck

var stick_normal: Vector2:
	get: return _stick_normal

var _stuck := false
var _stick_normal := Vector2.ZERO
var _afterimage_timer := 0.0
var _attached_target: Node2D
var _attached_local_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("ResettableProjectile")

	# Face the correct direction based on throw direction
	rotation = direction.angle()

func reset_for_encounter() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if _stuck:
		if is_instance_valid(_attached_target):
			global_position = _attached_target.to_global(_attached_local_position)
		elif _attached_target != null:
			queue_free()
		return

	var movement := direction * speed * delta

	# Raycast ahead to see if we hit a wall this frame
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + movement, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		var collider = result.get("collider")
		if collider is Node and collider.has_method("can_accept_shuriken") and collider.can_accept_shuriken():
			global_position = collider.get_shuriken_attach_position(result["position"], result["normal"])
			_stick_normal = collider.get_shuriken_attach_normal(result["normal"])
			if collider is Node2D:
				_attached_target = collider
				_attached_local_position = collider.to_local(global_position)
			_stick_to_surface()
			return
		if collider is StaticBody2D or collider is TileMapLayer or collider is TileMap:
			# Move exactly to the hit point and stick
			global_position = result["position"]
			_stick_normal = result["normal"]
			_stick_to_surface()
			return

	# Move normally
	position += movement

	# Spawn afterimages
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		spawn_afterimage()
		_afterimage_timer = afterimage_interval

func _stick_to_surface() -> void:
	_stuck = true

	# Disable further collisions
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Start stick lifespan timer
	get_tree().create_timer(lifespan).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

func spawn_afterimage() -> void:
	if _sprite == null or _sprite.texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.global_position = _sprite.global_position
	ghost.rotation = rotation
	ghost.modulate = afterimage_color
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Add to main scene tree so it stays behind when shuriken moves/dies
	get_tree().current_scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, afterimage_duration)
	tween.tween_callback(ghost.queue_free)
