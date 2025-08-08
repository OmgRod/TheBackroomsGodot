extends Node

var player_health = 100
var player_sanity = 100
var player_position = Vector2.ZERO
var inventory = []

func _ready():
	pass

func save_game():
	var save_data = {
		"player_health": player_health,
		"player_position": player_position,
		"inventory": inventory,
	}

	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game():
	if not FileAccess.file_exists("user://savegame.save"):
		return false
	var file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if not file:
		return false

	var content = file.get_as_text()
	file.close()

	var json = JSON.parse_string(content)
	if json.error != OK:
		return false
	var data = json.result
	if typeof(data) == TYPE_DICTIONARY:
		player_health = data.get("player_health", 100)
		player_position = data.get("player_position", Vector2.ZERO)
		inventory = data.get("inventory", [])
		return true
	return false
