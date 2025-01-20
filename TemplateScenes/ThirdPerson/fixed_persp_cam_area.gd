class_name FixedPerspCamArea extends "fixed_camera_area.gd"

enum JumpBehaviours {
	FOLLOW_JUMP,
	IGNORE_JUMP,
	UPDATE_ON_LAND
}

@export var camera_dist_levels = [5.0]
@export var max_lerp_distance = 0.0
@export var target_offset_from_player = Vector3(0,0,0)
@export var jump_behaviour = JumpBehaviours.FOLLOW_JUMP
