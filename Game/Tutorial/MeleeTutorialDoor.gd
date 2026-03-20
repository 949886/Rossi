@tool
extends StaticBody2D
class_name MeleeTutorialDoor

@export var controller_path: NodePath
@export var step_id := "melee"
@export var linked_enemy_path: NodePath
@export var size := Vector2(40.0, 104.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var door_color := Color(0.66, 0.87, 1.0, 0.95):
	set(value):
		door_color = value
		queue_redraw()
@export var inner_color := Color(0.12, 0.18, 0.25, 0.95):
	set(value):
		inner_color = value
		queue_redraw()
@export var checkpoint_marker_path: NodePath

var _interaction_area: Area2D
var _collision_shape: CollisionShape2D
var _opened := false
var _overlapping_player: PlatformerCharacter2D
var _controller: TutorialProgressController

func _ready() -> void:
	_controller = _resolve_controller()
	_setup_collision()
	_setup_area()
	set_physics_process(true)
	queue_redraw()

func _resolve_controller() -> TutorialProgressController:
	if not controller_path.is_empty():
		return get_node_or_null(controller_path) as TutorialProgressController
	return get_node_or_null("../../ProgressController") as TutorialProgressController

func _resolve_enemy() -> Node:
	if not linked_enemy_path.is_empty():
		return get_node_or_null(linked_enemy_path)
	return get_node_or_null("../DoorEnemy")

func _resolve_checkpoint_marker() -> Node2D:
	if not checkpoint_marker_path.is_empty():
		return get_node_or_null(checkpoint_marker_path) as Node2D
	return get_node_or_null("../MeleeCheckpoint") as Node2D

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _opened or _overlapping_player == null or not is_instance_valid(_overlapping_player):
		return

	if _overlapping_player.has_method("is_attack_active") and _overlapping_player.is_attack_active():
		_open(_overlapping_player)

func _draw() -> void:
	if _opened:
		return

	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, door_color)
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size - Vector2(10.0, 10.0)), inner_color)

func _setup_collision() -> void:
	_collision_shape = get_node_or_null("CollisionShape2D")
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	_update_shape()

func _setup_area() -> void:
	_interaction_area = get_node_or_null("InteractionArea")
	if _interaction_area == null:
		_interaction_area = Area2D.new()
		_interaction_area.name = "InteractionArea"
		add_child(_interaction_area)

		var area_shape := CollisionShape2D.new()
		area_shape.name = "CollisionShape2D"
		_interaction_area.add_child(area_shape)

	var shape := _interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		var area_rect := RectangleShape2D.new()
		area_rect.size = size + Vector2(28.0, 12.0)
		shape.shape = area_rect

	if not _interaction_area.body_entered.is_connected(_on_body_entered):
		_interaction_area.body_entered.connect(_on_body_entered)
	if not _interaction_area.body_exited.is_connected(_on_body_exited):
		_interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is PlatformerCharacter2D:
		_overlapping_player = body

func _on_body_exited(body: Node) -> void:
	if body == _overlapping_player:
		_overlapping_player = null

func _open(player: PlatformerCharacter2D) -> void:
	if _opened:
		return

	_opened = true
	if _collision_shape != null:
		_collision_shape.disabled = true
	if _interaction_area != null:
		_interaction_area.monitoring = false

	var enemy := _resolve_enemy()
	if enemy != null and enemy.has_method("defeat_from"):
		enemy.defeat_from(Vector2.RIGHT if player.global_position.x <= global_position.x else Vector2.LEFT)

	if _controller != null:
		_controller.complete_step(step_id)

	var marker := _resolve_checkpoint_marker()
	if marker != null and player != null and player.has_method("set_checkpoint"):
		player.set_checkpoint(marker.global_position)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(20.0, -6.0), 0.16)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	queue_redraw()

func _update_shape() -> void:
	if _collision_shape == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_collision_shape.shape = rectangle
	if _interaction_area != null:
		var shape := _interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null:
			var area_rect := RectangleShape2D.new()
			area_rect.size = size + Vector2(28.0, 12.0)
			shape.shape = area_rect
