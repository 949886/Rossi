@tool
class_name SpriteStaticBody
extends StaticBody2D

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

var collisions: Dictionary = {}


func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite")
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "Sprite"
			add_child(sprite)
			if Engine.is_editor_hint():
				sprite.owner = get_tree().edited_scene_root

	var has_collision = false
	for child in get_children():
		if child is CollisionPolygon2D:
			has_collision = true
			break

	if not has_collision and sprite.texture != null:
		generate_collider(sprite.texture.get_image(), sprite.centered, self)


static func generate_collider(image: Image, centered: bool = true, body: StaticBody2D = null) -> StaticBody2D:
	if body == null:
		body = StaticBody2D.new()

	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image)

	var polys = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 0.5)

	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = poly
		body.add_child(collision_polygon)

		if Engine.is_editor_hint() and body.get_tree():
			collision_polygon.owner = body.get_tree().edited_scene_root

		if centered:
			var half_size = Vector2(image.get_size()) / 2.0
			collision_polygon.position -= half_size

	return body
