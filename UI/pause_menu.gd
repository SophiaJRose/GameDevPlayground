extends PanelContainer

var paused: bool = false
var prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	$VBox/ResumeButton.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape") or event.is_action_pressed("Start Button"):
		unpause() if paused else pause()

func pause() -> void:
	paused = true
	get_tree().paused = true
	show()
	prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$VBox/ResumeButton.grab_focus()

func unpause() -> void:
	paused = false
	hide()
	get_tree().paused = false
	Input.set_mouse_mode(prev_mouse_mode)

func change_level(level: String) -> void:
	unpause()
	get_tree().change_scene_to_file(level)

func quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()
