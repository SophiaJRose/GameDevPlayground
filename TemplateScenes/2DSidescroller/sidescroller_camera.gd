class_name sidescroller_camera extends Camera2D

enum HorizontalScrollModes {
	None,							# No horizontal scrolling
	Follow,							# Camera keeps player at center of screen if possible
	Lookahead,						# Camera keeps player within defined central zone if possible
	Screen,							# Camera scrolls a screen's width at a time, when leaving the screen
	ScreenSmooth					# Above, but lerps to new position
}
enum VerticalScrollModes {
	None,							# No vertical scrolling
	Follow,							# Camera keeps player at center of screen if possible
	Lookahead,						# Camera keeps player within defined central zone if possible
	Climbing,						# Camera only scrolls up when on solid ground, follows player when moving down
	Screen,							# Camera scrolls a screen's height at a time, when leaving the screen
	ScreenSmooth					# Above, but lerps to new position
}

@onready var viewport = get_viewport()

@export var player: sidescroller_player = null
@export var horizontalMode: HorizontalScrollModes = HorizontalScrollModes.None
@export var verticalMode: VerticalScrollModes = VerticalScrollModes.None
@export var minX: float = NAN
@export var maxX: float = NAN
@export var minY: float = NAN
@export var maxY: float = NAN
# Variables for Lookahead mode
# Guidelines are where the camera will be aligned with while moving in that direction, boundaries are the line the player must cross to switch to that alignment
# Guidelines should generally be placed to position the camera ahead of the player, and boundaries placed such that the camera doesn't switch too easily
# e.g. |---LB---RG---Mid---LG---RB---|
@export var leftGuidelineOffset: float = 0
@export var leftBoundaryOffset: float = 0
@export var rightGuidelineOffset: float = 0
@export var rightBoundaryOffset: float = 0
@export var upGuidelineOffset: float = 0
@export var upBoundaryOffset: float = 0
@export var downGuidelineOffset: float = 0
@export var downBoundaryOffset: float = 0
var lookRight: bool = true
var lookDown: bool = false
var desiredCamXOffset: float = 0
var currentCamXOffset: float = 0
var desiredCamYOffset: float = 0
var currentCamYOffset: float = 0
# Variables for Climbing mode
@export var ground_camera_offset = 0
var last_ground_height = 0
# Variables for Screen and ScreenSmooth modes
var screen_width = 0
var screen_height = 0
var desiredXPos = 0
var desiredYPos = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialise some of the above variables
	desiredCamXOffset = rightGuidelineOffset
	desiredCamYOffset = upGuidelineOffset
	screen_width = viewport.get_visible_rect().size.x
	screen_height = viewport.get_visible_rect().size.y
	desiredXPos = position.x
	desiredYPos = position.y
	# All scrolling mode require a player to work, so if no player, no scrolling
	if player == null:
		horizontalMode = HorizontalScrollModes.None
		verticalMode = VerticalScrollModes.None

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Horizontal scrolling
	if horizontalMode == HorizontalScrollModes.Follow:
		position.x = clamp(player.position.x, minX if !is_nan(minX) else player.position.x, maxX if !is_nan(maxX) else player.position.x);
	elif horizontalMode == HorizontalScrollModes.Lookahead:
		## If player passes boundary, set desired offset to corresponding guideline, then lerp current offset to desired
		if lookRight and player.position.x < position.x - leftBoundaryOffset:
			desiredCamXOffset = leftGuidelineOffset
			currentCamXOffset = leftBoundaryOffset
			lookRight = false
		elif !lookRight and player.position.x > position.x - rightBoundaryOffset:
			desiredCamXOffset = rightGuidelineOffset
			currentCamXOffset = rightBoundaryOffset
			lookRight = true
		currentCamXOffset = lerp(currentCamXOffset, desiredCamXOffset, 0.05)
		if (lookRight and player.position.x >= position.x - rightGuidelineOffset) or (!lookRight and player.position.x <= position.x - leftGuidelineOffset):
			position.x = clamp(player.position.x + currentCamXOffset, minX if !is_nan(minX) else player.position.x + currentCamXOffset, maxX if !is_nan(maxX) else player.position.x + currentCamXOffset)
	elif horizontalMode == HorizontalScrollModes.Screen:
		var playerRelativeXPos = player.position.x - position.x
		if playerRelativeXPos > (screen_width / 2):
			position.x += screen_width
		elif playerRelativeXPos < (screen_width / -2):
			position.x -= screen_width
		position.x = clamp(position.x, minX if !is_nan(minX) else position.x, maxX if !is_nan(maxX) else position.x);
	elif horizontalMode == HorizontalScrollModes.ScreenSmooth:
		var playerRelativeXPos = player.position.x - desiredXPos
		if playerRelativeXPos > (screen_width / 2):
			desiredXPos += screen_width
		elif playerRelativeXPos < (screen_width / -2):
			desiredXPos -= screen_width
		desiredXPos = clamp(desiredXPos, minX if !is_nan(minX) else desiredXPos, maxX if !is_nan(maxX) else desiredXPos);
		position.x = lerp(position.x, desiredXPos, 0.2)
	# Vertical scrolling
	if verticalMode == VerticalScrollModes.Follow:
		position.y = clamp(player.position.y, minY if !is_nan(minY) else player.position.y, maxY if !is_nan(maxY) else player.position.y);
	elif verticalMode == VerticalScrollModes.Lookahead:
		## If player passes boundary, set desired offset to corresponding guideline, then lerp current offset to desired
		if lookDown and player.position.y < position.y - upBoundaryOffset:
			desiredCamYOffset = upGuidelineOffset
			currentCamYOffset = upBoundaryOffset
			lookDown = false
		elif !lookDown and player.position.y > position.y - downBoundaryOffset:
			desiredCamYOffset = downGuidelineOffset
			currentCamYOffset = downBoundaryOffset
			lookDown = true
		currentCamYOffset = lerp(currentCamYOffset, desiredCamYOffset, 0.1)
		if (lookDown and player.position.y >= position.y - downGuidelineOffset) or (!lookDown and player.position.y <= position.y - upGuidelineOffset):
			position.y = clamp(player.position.y + currentCamYOffset, minY if !is_nan(minY) else player.position.y + currentCamYOffset, maxY if !is_nan(maxY) else player.position.y + currentCamYOffset)
	elif verticalMode == VerticalScrollModes.Climbing:
		# Camera position tries to be last ground player stood on + offest
		# When player is above last ground, only update camera when landing again
		# When player is below last ground, camera follows player
		if player.is_on_floor():
			last_ground_height = player.position.y
		if player.position.y > last_ground_height:
			position.y = max(player.position.y + ground_camera_offset, position.y)
		else:
			position.y = lerp(position.y, last_ground_height + ground_camera_offset, 0.1)
		position.y = clamp(position.y, minY if !is_nan(minY) else position.y, maxY if !is_nan(maxY) else position.y);
	elif verticalMode == VerticalScrollModes.Screen:
		var playerRelativeYPos = player.position.y - position.y
		if playerRelativeYPos > (screen_height / 2):
			position.y += screen_height
		elif playerRelativeYPos < (screen_height / -2):
			position.y -= screen_height
		position.y = clamp(position.y, minY if !is_nan(minY) else position.y, maxY if !is_nan(maxY) else position.y);
	elif verticalMode == VerticalScrollModes.ScreenSmooth:
		var playerRelativeYPos = player.position.y - desiredYPos
		if playerRelativeYPos > (screen_height / 2):
			desiredYPos += screen_height
		elif playerRelativeYPos < (screen_height / -2):
			desiredYPos -= screen_height
		desiredYPos = clamp(desiredYPos, minY if !is_nan(minY) else desiredYPos, maxY if !is_nan(maxY) else desiredYPos);
		position.y = lerp(position.y, desiredYPos, 0.2)
