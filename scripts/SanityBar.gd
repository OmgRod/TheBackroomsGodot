extends Control

@export var decrease_interval: float = 5.0 # seconds between decreases
@export var decrease_amount: int = 1       # % decrease per interval
@export var sanity: int = 100              # starts at 100%

var timer := 0.0

func _process(delta: float) -> void:
	timer += delta
	if timer >= decrease_interval:
		timer = 0.0
		_change_sanity(-decrease_amount)

func _change_sanity(amount: int) -> void:
	sanity = clamp(sanity + amount, 0, 100)
	_update_ui()

func _update_ui() -> void:
	# Calculate new width of fill bar
	var bg_width = $Background.size.x
	var fill_width = (sanity / 100.0) * bg_width
	$FillBar.size.x = fill_width

	# Update text
	$RichTextLabel.text = "Sanity: %d%%" % sanity
