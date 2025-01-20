class_name ThirdPersonPlayer extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const CAMERA_X_SENS = 4
const CAMERA_Y_SENS = 2
const CAMERA_PIVOT = Vector3(0, 1.5, 0)
enum CameraModes {
	FOLLOW_PLAYER,
	FIXED,
	FIXED_POS,
	FIXED_PERSPECTIVE
}

@export var camera_zoom_levels = [5.0, 7.5, 10.0]

@onready var player_cam_point = $CameraPoint
@onready var camera = $Camera3D

# Variables related to camera
var desired_camera_rot = Vector2(-PI/8,0)
var camera_rot = Vector2(-PI/8,0)
var desired_camera_zoom_level = 0
var camera_zoom_dist = camera_zoom_levels[desired_camera_zoom_level]
var player_cam_target = position + CAMERA_PIVOT
var camera_mode = CameraModes.FOLLOW_PLAYER
var active_cam_areas = []
var current_cam_area = null
var cam_settle_timer = NAN
var fixed_camera_cooldown = NAN

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Set initial camera position
	var player_cam_pos = Transform3D(Basis(), CAMERA_PIVOT).rotated_local(Vector3.UP, camera_rot.y).rotated_local(Vector3.RIGHT,camera_rot.x).orthonormalized()
	player_cam_pos = player_cam_pos.translated(player_cam_pos.basis.z * camera_zoom_dist)
	player_cam_point.transform = player_cam_pos
	camera.transform = player_cam_point.transform

func _unhandled_input(event):
	# Handle jump.
	if event.is_action_pressed("A Button") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Reset camera behind player
	elif event.is_action_pressed("R Button"):
		desired_camera_rot.y = rotation.y
	# Handle camera zoom controls
	elif event.is_action_pressed("RS Click") and camera_mode == CameraModes.FOLLOW_PLAYER:
		desired_camera_zoom_level = (desired_camera_zoom_level + 1) % camera_zoom_levels.size()
	elif event.is_action_pressed("RS Click") and camera_mode == CameraModes.FIXED_PERSPECTIVE:
		desired_camera_zoom_level = (desired_camera_zoom_level + 1) % current_cam_area.camera_dist_levels.size()

func _physics_process(delta):
	handle_camera(delta)
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("LS Left", "LS Right", "LS Up", "LS Down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera.rotation.y)
	if direction:
		var target_angle = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
		rotation.y = rotate_toward(rotation.y, target_angle, 0.2)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
	
func handle_camera(delta):
	match camera_mode:
		# Default camera mode, following player
		CameraModes.FOLLOW_PLAYER:
			# Don't allow camera rotation if camera still settling back into place after other mode
			if is_nan(cam_settle_timer):
				var rs_dir = Input.get_vector("RS Left", "RS Right", "RS Up", "RS Down")
				desired_camera_rot.y = wrapf(desired_camera_rot.y - rs_dir.x * delta * CAMERA_X_SENS, -PI, PI)
				desired_camera_rot.x = clamp(desired_camera_rot.x - (rs_dir.y * delta * CAMERA_Y_SENS), -3*PI/8, PI/16)
				camera_rot.y = lerp_angle(camera_rot.y, desired_camera_rot.y, 0.2)
				camera_rot.x = lerp_angle(camera_rot.x, desired_camera_rot.x, 0.2)
			camera_zoom_dist = lerp(camera_zoom_dist, camera_zoom_levels[desired_camera_zoom_level], 0.2)
			# Get desired position of camera and move camera
			player_cam_target = player_cam_target.lerp(position + CAMERA_PIVOT, 0.05)
			var player_cam_pos = Transform3D(Basis(), player_cam_target).rotated_local(Vector3.UP, camera_rot.y).rotated_local(Vector3.RIGHT, camera_rot.x).orthonormalized()
			player_cam_pos = player_cam_pos.translated(player_cam_pos.basis.z * camera_zoom_dist)
			player_cam_point.transform = player_cam_pos
			# Interpolate camera back when leaving other modes
			if not is_nan(cam_settle_timer):
				cam_settle_timer += 1.0
				var interp_weight = clamp(0.15 * (clamp(cam_settle_timer, 7.5, 75) / 7.5), 0.15, 1.0)
				camera.transform = camera.transform.interpolate_with(player_cam_point.transform, interp_weight)
				cam_settle_timer = NAN if camera.transform.is_equal_approx(player_cam_point.transform) else cam_settle_timer
			else:
				camera.transform = player_cam_point.transform
		# Fixed camera
		CameraModes.FIXED:
			var fixed_cam_point = current_cam_area.get_node("CameraPoint")
			camera.transform = camera.transform.interpolate_with(fixed_cam_point.global_transform, 0.1)
			return_fixed_camera(delta)
		# Fixed position camera
		CameraModes.FIXED_POS:
			var fixed_cam_point = current_cam_area.get_node("CameraPoint")
			fixed_cam_point.global_transform = fixed_cam_point.global_transform.looking_at(position + CAMERA_PIVOT)
			# Don't look straight down
			fixed_cam_point.rotation.x = clamp(fixed_cam_point.rotation.x, current_cam_area.max_downward_angle, current_cam_area.max_upward_angle)
			camera.transform = camera.transform.interpolate_with(fixed_cam_point.global_transform, 0.1)
			return_fixed_camera(delta)
		# Fixed perspective camera
		CameraModes.FIXED_PERSPECTIVE:
			# Get camera target, angle, and distance from area
			var camera_target = current_cam_area.get_node("CameraTarget")
			var camera_angle = current_cam_area.get_node("CameraAngle")
			camera_zoom_dist = lerp(camera_zoom_dist, current_cam_area.camera_dist_levels[desired_camera_zoom_level], 0.2)
			# Update target position
			var max_lerp_distance = current_cam_area.max_lerp_distance
			var target_offset = current_cam_area.target_offset_from_player
			var offset_position = position + target_offset
			var dist_from_target = camera_target.position.distance_to(offset_position)
			var lerp_weight = min(0.05 * dist_from_target / max_lerp_distance, 0.05) if max_lerp_distance != 0 else 0.05
			var jump_behaviour = current_cam_area.jump_behaviour
			if jump_behaviour == FixedPerspCamArea.JumpBehaviours.FOLLOW_JUMP or (jump_behaviour == FixedPerspCamArea.JumpBehaviours.UPDATE_ON_LAND and is_on_floor()):
				camera_target.position = camera_target.position.lerp(offset_position, lerp_weight)
			elif jump_behaviour == FixedPerspCamArea.JumpBehaviours.IGNORE_JUMP or (jump_behaviour == FixedPerspCamArea.JumpBehaviours.UPDATE_ON_LAND and not is_on_floor()):
				camera_target.position.x = lerp(camera_target.position.x, offset_position.x, lerp_weight)
				camera_target.position.z = lerp(camera_target.position.z, offset_position.z, lerp_weight)
			# Get desired position of camera and move camera
			var cam_pos = Transform3D(Basis(), camera_target.position + CAMERA_PIVOT).rotated_local(Vector3.UP, camera_angle.rotation.y).rotated_local(Vector3.RIGHT, camera_angle.rotation.x).orthonormalized()
			cam_pos = cam_pos.translated(cam_pos.basis.z * camera_zoom_dist)
			if not is_nan(cam_settle_timer):
				cam_settle_timer += 1.0
				var interp_weight = clamp(0.15 * (clamp(cam_settle_timer, 7.5, 75) / 7.5), 0.15, 1.0)
				camera.transform = camera.transform.interpolate_with(cam_pos, interp_weight)
				cam_settle_timer = NAN if camera.transform.is_equal_approx(cam_pos) else cam_settle_timer
			else:
				camera.transform = cam_pos
			return_fixed_camera(delta)

func return_fixed_camera(delta):
	if fixed_camera_cooldown > 0:
		fixed_camera_cooldown -= delta
	if fixed_camera_cooldown <= 0.0:
		player_cam_target = position + CAMERA_PIVOT
		desired_camera_rot = Vector2(-PI/8, camera.rotation.y)
		camera_rot = desired_camera_rot
		camera_mode = CameraModes.FOLLOW_PLAYER
		camera_zoom_dist = camera_zoom_levels[desired_camera_zoom_level]
		cam_settle_timer = -10.0
		fixed_camera_cooldown = NAN
		current_cam_area = null

func _on_bbox_area_entered(area):
	if area.is_in_group("FixedCameraArea"):
		var fixed_cam_point = area.get_node("CameraPoint")
		camera_mode = CameraModes.FIXED
		fixed_camera_cooldown = NAN
		current_cam_area = area
		# Don't add to active cam areas if already in, i.e. via exiting overlapping/adjacent area
		if area not in active_cam_areas:
			active_cam_areas.append(area)
		if area.instant_snap:
			camera.transform = fixed_cam_point.global_transform
	elif area.is_in_group("FixedCamPosArea"):
		var fixed_cam_point = area.get_node("CameraPoint")
		camera_mode = CameraModes.FIXED_POS
		fixed_camera_cooldown = NAN
		current_cam_area = area
		if area not in active_cam_areas:
			active_cam_areas.append(area)
		if area.instant_snap:
			camera.transform = fixed_cam_point.global_transform.looking_at(position + CAMERA_PIVOT)
	elif area.is_in_group("FixedPerspCamArea"):
		var camera_target = area.get_node("CameraTarget")
		camera_mode = CameraModes.FIXED_PERSPECTIVE
		fixed_camera_cooldown = NAN
		# Don't reset these if re-entering right after exiting
		if current_cam_area != area:
			var target_offset = area.target_offset_from_player
			camera_target.position = position + target_offset
			camera_zoom_dist = area.camera_dist_levels[desired_camera_zoom_level]
			cam_settle_timer = -10.0
		current_cam_area = area
		if area not in active_cam_areas:
			active_cam_areas.append(area)
		if area.instant_snap:
			var camera_angle = area.get_node("CameraAngle")
			var cam_pos = Transform3D(Basis(), camera_target.position + CAMERA_PIVOT).rotated_local(Vector3.UP, camera_angle.rotation.y).rotated_local(Vector3.RIGHT, camera_angle.rotation.x).orthonormalized()
			cam_pos = cam_pos.translated(cam_pos.basis.z * camera_zoom_dist)
			cam_settle_timer = NAN

func _on_bbox_area_exited(area):
	if area.is_in_group("FixedCameraArea") or area.is_in_group("FixedCamPosArea") or area.is_in_group("FixedPerspCamArea"):
		exit_cam_area(area)

func exit_cam_area(area):
	# If player is still in other area(s) after leaving this one (areas are overlapping or adjacent), behave as though re-entering last area entered and ignore usual exiting behaviour
	active_cam_areas.erase(area)
	if not active_cam_areas.is_empty():
		_on_bbox_area_entered(active_cam_areas.back())
		return
	if not area.instant_snap:
		fixed_camera_cooldown = area.override_cooldown if not is_nan(area.override_cooldown) else 1.0
	else:
		player_cam_target = position + CAMERA_PIVOT
		desired_camera_rot = Vector2(-PI/8, camera.rotation.y)
		camera_rot = desired_camera_rot
		camera_mode = CameraModes.FOLLOW_PLAYER
		camera_zoom_dist = camera_zoom_levels[desired_camera_zoom_level]
		cam_settle_timer = NAN
		current_cam_area = null
