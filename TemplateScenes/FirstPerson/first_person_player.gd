class_name first_person_player extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 10.0
const ACCEL = 1.0
const AIR_DECEL = 0.2
const JUMP_VELOCITY = 4.5

@export var sensitivity = 3
@onready var camera = $Camera3D

var rot = Vector3.ZERO
var speed = 0
var prev_dir = Vector3.ZERO
var direction = Vector3.ZERO

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		var mouse_axis = event.relative / 1000 * sensitivity
		rot.y -= mouse_axis.x
		rot.x = clamp(rot.x - mouse_axis.y, -PI/2, PI/2)
		camera.rotation.x = rot.x
		rotation.y = rot.y
	# Handle jump.
	elif event.is_action_pressed("Spacebar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	var input_dir = Input.get_vector("A", "D", "W", "S")
	direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, rotation.y)
	var isSprinting = Input.is_action_pressed("Shift")
	if direction:
		speed = clamp(speed + ACCEL, 0, SPRINT_SPEED if isSprinting else WALK_SPEED)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		prev_dir = direction
	elif not is_on_floor():
		speed = clamp(speed - AIR_DECEL, 0, SPRINT_SPEED if isSprinting else WALK_SPEED)
		velocity.x = prev_dir.x * speed
		velocity.z = prev_dir.z * speed
	else:
		speed = 0
		velocity.x = 0
		velocity.z = 0
		prev_dir = direction
	move_and_slide()
