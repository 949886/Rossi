extends Area2D
class_name EnemyProjectile

@export_group("Projectile")
@export var speed := 520.0
@export var lifespan := 2.0
@export var damage := 1
@export var knockback := Vector2(150.0, -18.0)
@export var hitstun := 0.12
@export var invuln_time := 0.0
@export var target_group := "Player"
@export var tags: PackedStringArray = PackedStringArray(["projectile"])
@export_group("Audio")
@export var impact_world_cue: AudioCue
@export var impact_player_cue: AudioCue

var direction := Vector2.RIGHT
var shooter: Node2D
var _life_remaining := 0.0
var _has_impacted := false
var _is_deflected := false

func _ready() -> void:
	add_to_group("ResettableProjectile")
	_life_remaining = lifespan
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()

func configure_projectile(source: Node2D, shot_direction: Vector2) -> void:
	shooter = source
	target_group = "Player"
	tags = PackedStringArray(["projectile"])
	_has_impacted = false
	_is_deflected = false
	if shot_direction.length_squared() >= 0.0001:
		direction = shot_direction.normalized()
	rotation = direction.angle()

func deflect(deflector: Node2D, new_direction: Vector2) -> void:
	shooter = deflector
	target_group = "Enemy"
	_life_remaining = lifespan
	_has_impacted = false
	_is_deflected = true
	if not tags.has("deflect"):
		tags.append("deflect")
	if not tags.has("reflected_projectile"):
		tags.append("reflected_projectile")

	var reflected_direction := new_direction
	if reflected_direction.length_squared() < 0.0001:
		reflected_direction = -direction
	if reflected_direction.length_squared() < 0.0001:
		reflected_direction = Vector2.RIGHT
	direction = reflected_direction.normalized()
	rotation = direction.angle()

func reset_for_encounter() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	var scaled_delta := Chronos.get_delta_for_group(delta, &"projectile")
	_life_remaining -= scaled_delta
	if _life_remaining <= 0.0:
		queue_free()
		return

	var movement := direction * speed * scaled_delta
	var hit := _raycast_world(movement)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if not (collider is Node and target_group != "" and (collider as Node).is_in_group(target_group)):
			global_position = hit["position"]
			_play_impact_world(global_position)
			queue_free()
			return

	global_position += movement

func _raycast_world(movement: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + movement, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if shooter is CollisionObject2D:
		query.exclude = [(shooter as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)

func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox2D):
		return

	var hurtbox := area as Hurtbox2D
	var receiver := hurtbox.get_damage_receiver()
	if receiver == null or receiver == shooter:
		return
	if target_group != "" and not receiver.is_in_group(target_group):
		return
	if receiver.has_method("receive_attack"):
		var targeted_player_before_hit := target_group == "Player"
		var hit_data := _build_hit_data(hurtbox, receiver)
		receiver.receive_attack(hit_data)
		if is_queued_for_deletion():
			return
		if targeted_player_before_hit and _is_deflected:
			return
		_play_impact_player(hit_data.get("impact_position", global_position))
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _has_impacted:
		return
	if body == shooter:
		return
	if target_group != "" and body.is_in_group(target_group):
		return
	_play_impact_world(global_position)
	queue_free()

func _build_hit_data(hurtbox: Hurtbox2D, receiver: Node) -> Dictionary:
	var attack_direction := direction.normalized()
	var horizontal_direction := 1.0 if attack_direction.x >= 0.0 else -1.0
	var projectile_knockback := Vector2(absf(knockback.x) * horizontal_direction, knockback.y)
	var attacker_global_position := global_position
	if shooter != null:
		attacker_global_position = shooter.global_position

	var receiver_global_position := hurtbox.global_position
	if receiver is Node2D:
		receiver_global_position = (receiver as Node2D).global_position

	return {
		"damage": damage,
		"source": self,
		"direction": attack_direction,
		"attack_direction": attack_direction,
		"knockback": projectile_knockback,
		"hitstun": hitstun,
		"invuln_time": invuln_time,
		"tags": tags.duplicate(),
		"impact_position": hurtbox.get_impact_position(global_position),
		"attacker_global_position": attacker_global_position,
		"receiver_global_position": receiver_global_position,
		"receiver": receiver,
	}

func _play_impact_world(position: Vector2) -> void:
	if _has_impacted:
		return
	_has_impacted = true
	SFX.play_cue(impact_world_cue, position)


func _play_impact_player(position: Vector2) -> void:
	if _has_impacted:
		return
	_has_impacted = true
	SFX.play_cue(impact_player_cue, position)
