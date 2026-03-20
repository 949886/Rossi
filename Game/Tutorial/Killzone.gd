extends Area2D
class_name Killzone

@export var reset_target_path: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	var target := get_node_or_null(reset_target_path)
	if target != null and target.has_method("reset_platform"):
		target.reset_platform()

	if body.has_method("die"):
		body.die()
