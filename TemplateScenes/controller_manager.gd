extends Node

var player_devices: Array[int] = [-1, -1, -1, -1]
var level: Node = null
@export var player: PackedScene = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	level = get_tree().get_nodes_in_group("Level")[0]

func _input(event: InputEvent) -> void:
	for i in 4:
		# Only add/remove player for device if not already added/removed
		if event.is_action_pressed("Jump Device %s" % i) and !player_devices.has(i):
			add_player(i)
		if event.is_action_pressed("Quit Device %s" % i) and player_devices.has(i):
			remove_player(i)

func add_player(device: int) -> void:
	var player_slot: int = player_devices.find(-1)
	player_devices[player_slot] = device
	var spawn_point: Node = level.get_node("P%sSpawn" % (player_slot+1))
	var new_player = player.instantiate()
	new_player.name = "Player%s" % player_slot
	new_player.player_slot = player_slot
	new_player.device_id = device
	spawn_point.add_sibling(new_player)
	new_player.transform = spawn_point.transform
	
func remove_player(device: int) -> void:
	var player_slot: int = player_devices.find(device)
	player_devices[player_slot] = -1
	var quitting_player = level.get_node("Player%s" % player_slot)
	quitting_player.queue_free()
