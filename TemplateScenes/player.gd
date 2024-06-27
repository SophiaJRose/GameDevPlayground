extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const CAMERA_X_SENS = 4
const CAMERA_Y_SENS = 2
const CAMERA_PIVOT = Vector3(0, 1.5, 0)

@export var camera_zoom_levels = [5.0, 7.5, 10.0]

@onready var camera = $Camera3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Variables related to camera lerping
var desired_camera_rot = Vector2(-PI/8,0)
var camera_rot = Vector2(-PI/8,0)
var desired_camera_zoom_level = 0
var camera_zoom_dist = camera_zoom_levels[desired_camera_zoom_level]
var camera_target = position

func _ready():
	var camera_pos = Transform3D(Basis(), CAMERA_PIVOT).rotated_local(Vector3(0,1,0), camera_rot.y).rotated_local(Vector3(1,0,0),camera_rot.x).orthonormalized()
	camera_pos = camera_pos.translated(camera_pos.basis.z * camera_zoom_dist)
	camera.transform = camera_pos

func _physics_process(delta):
	# Handle camera controls
	var camera_dir = Input.get_vector("RS Left", "RS Right", "RS Up", "RS Down")
	desired_camera_rot.y = wrapf(desired_camera_rot.y - camera_dir.x * delta * CAMERA_X_SENS, -PI, PI)
	camera_rot.y = lerp_angle(camera_rot.y, desired_camera_rot.y, 0.2)
	desired_camera_rot.x = clamp(desired_camera_rot.x - (camera_dir.y * delta * CAMERA_Y_SENS), -3*PI/8, PI/16)
	camera_rot.x = lerp_angle(camera_rot.x, desired_camera_rot.x, 0.2)
	# Reset camera behind player
	if Input.is_action_just_pressed("R Button"):
		desired_camera_rot.y = rotation.y
	# Handle camera zoom controls
	if Input.is_action_just_pressed("RS Click"):
		desired_camera_zoom_level = (desired_camera_zoom_level + 1) % camera_zoom_levels.size()
	camera_zoom_dist = lerp(camera_zoom_dist, camera_zoom_levels[desired_camera_zoom_level], 0.2)
	# Save camera y-rotation for use in movement
	camera_target = camera_target.lerp(position, 0.05)
	var camera_y_rot = Transform3D(Basis(), camera_target + CAMERA_PIVOT).rotated_local(Vector3.UP, camera_rot.y)
	var camera_pos = camera_y_rot.rotated_local(Vector3.RIGHT,camera_rot.x)
	camera_pos = camera_pos.translated(camera_pos.basis.z * camera_zoom_dist)
	camera.transform = camera_pos
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("A Button") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("LS Left", "LS Right", "LS Up", "LS Down")
	var direction = (camera_y_rot.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var target_angle = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
		rotation.y = rotate_toward(rotation.y, target_angle, 0.2)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
