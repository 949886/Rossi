extends CharacterBody2D

@export var move_speed := 200.0
@export var acceleration := 1000.0
@export var friction := 800.0
@export var jump_velocity := -350.0
@export var gravity := 980.0
@export var joystick_path: NodePath

func _physics_process(delta: float) -> void:
	var vel := velocity

	if not is_on_floor():
		vel.y += gravity * delta

	var input_x := Input.get_axis("move_left", "move_right")
	var joystick = null
	if joystick_path != NodePath(""):
		joystick = get_node_or_null(joystick_path)
	if joystick and joystick.has_method("get"):
		input_x = joystick.output.x

	if absf(input_x) > 0.01:
		vel.x = move_toward(vel.x, input_x * move_speed, acceleration * delta)
	else:
		vel.x = move_toward(vel.x, 0.0, friction * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		vel.y = jump_velocity

	velocity = vel
	move_and_slide()
