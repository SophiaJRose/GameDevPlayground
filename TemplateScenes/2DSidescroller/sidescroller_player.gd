class_name sidescroller_player extends CharacterBody2D

@export var player_slot: int = -1
@export var device_id: int = -1
var jump_action: String = ""
var left_action: String = ""
var right_action: String = ""

const SPEED = 240.0
const JUMP_VELOCITY = 360.0

@onready var animations = $CharacterSprite

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	jump_action = "Spacebar" if device_id == -1 else "Jump Device %s" % device_id
	left_action = "A" if device_id == -1 else "Left Device %s" % device_id
	right_action = "D" if device_id == -1 else "Right Device %s" % device_id

func _physics_process(delta: float) -> void:
	# Handle jump and gravity
	if Input.is_action_just_pressed(jump_action) and is_on_floor():
		velocity.y -= JUMP_VELOCITY
	if velocity.y <= 0 and !Input.is_action_pressed(jump_action):
		velocity.y /= 2
	if velocity.y <= 0 and Input.is_action_pressed(jump_action):
		velocity.y += (gravity / 2) * delta
	else:
		velocity.y += (gravity) * delta

	var direction := Input.get_axis(left_action, right_action)
	if direction:
		velocity.x = direction * SPEED
		animations.scale.x = -sign(direction)
		animations.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		animations.play("Stand")

	move_and_slide()
