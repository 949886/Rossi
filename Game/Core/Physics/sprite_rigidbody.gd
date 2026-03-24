@tool
class_name SpriteRigidBody
extends RigidBody2D

class CollisionInfo:
	var collider: Node
	var position: Vector2
	var normal: Vector2

	func _init(_collider: Node, _position: Vector2, _normal: Vector2):
		self.collider = _collider
		self.position = _position
		self.normal = _normal

@export var sprite: Sprite2D

@export var texture: Texture2D:
	get: return sprite.texture if sprite else null
	set(value):
		if sprite == null:
			return

		sprite.texture = value

		for child in get_children():
			if child is CollisionPolygon2D:
				child.queue_free()

		if value != null:
			generate_collider(value.get_image(), sprite.centered, self)

var collisions: Dictionary = {} # Dictionary[Node, CollisionInfo]
var collision_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite")
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "Sprite"
			add_child(sprite)
			if Engine.is_editor_hint():
				sprite.owner = get_tree().edited_scene_root

	if get_child_count() <= 1 and sprite.texture != null:
		generate_collider(sprite.texture.get_image(), sprite.centered, self)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var collision_count = state.get_contact_count()

	collisions.clear()

	if collision_count == 0:
		collision_velocity = linear_velocity

	for i in range(collision_count):
		var collision_position = state.get_contact_local_position(i)
		var collision_normal = state.get_contact_local_normal(i)
		var collider = state.get_contact_collider_object(i)

		if collider == null:
			continue

		collisions[collider] = CollisionInfo.new(collider, collision_position, collision_normal)
		
		
static func generate_collider(image: Image, centered: bool = true, rigid_body: RigidBody2D = null) -> RigidBody2D:
	if rigid_body == null:
		rigid_body = RigidBody2D.new()

	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image)

	var polys = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 0.5)

	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = poly
		rigid_body.add_child(collision_polygon)

		if Engine.is_editor_hint() and rigid_body.get_tree():
			collision_polygon.owner = rigid_body.get_tree().edited_scene_root

		if centered:
			var half_size = Vector2(image.get_size()) / 2.0
			collision_polygon.position -= half_size

	return rigid_body
