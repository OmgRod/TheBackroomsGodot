extends Control

func _ready():
	$Container/ButtonContainer/StartButton.pressed.connect(_on_StartButton_pressed)
	$Container/ButtonContainer/OptionsButton.pressed.connect(_on_OptionsButton_pressed)
	$Container/ButtonContainer/ExitButton.pressed.connect(_on_QuitButton_pressed)

func _on_StartButton_pressed():
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_OptionsButton_pressed():
	$Container.visible = false;

func _on_QuitButton_pressed():
	get_tree().quit()
