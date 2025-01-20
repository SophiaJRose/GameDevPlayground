class_name sidescroller_player extends CharacterBody2D

const SPEED = 240.0
const JUMP_VELOCITY = 360.0

@onready var animations = $CharacterSprite

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	# Handle jump and gravity
	if Input.is_action_just_pressed("Spacebar") and is_on_floor():
		velocity.y -= JUMP_VELOCITY
	if velocity.y <= 0 and !Input.is_action_pressed("Spacebar"):
		velocity.y /= 2
	if velocity.y <= 0 and Input.is_action_pressed("Spacebar"):
		velocity.y += (gravity / 2) * delta
	else:
		velocity.y += (gravity) * delta

	var direction := Input.get_axis("A", "D")
	if direction:
		velocity.x = direction * SPEED
		animations.scale.x = -sign(direction)
		animations.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		animations.play("Stand")

	move_and_slide()
