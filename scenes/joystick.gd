extends Control  # Attach to your on-screen joystick Control

@export var joystick_radius: float = 110.0  # pixels
var dragging: bool = false
var center_position: Vector2

func _ready() -> void:
	center_position = $Draggable.position
	$Draggable.position = center_position
	mouse_filter = MOUSE_FILTER_PASS  # let events propagate

func _gui_input(event: InputEvent) -> void:
	# Start drag
	if (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if joystick_radius > 0.0:
			dragging = true

	# End drag
	if (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if dragging:
			dragging = false
			$Draggable.position = center_position
			JoystickInput.direction = Vector2.ZERO

	# Dragging motion
	if dragging:
		var local_pos: Vector2 = get_local_mouse_position()
		var offset: Vector2 = local_pos - (size * 0.5)
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius
		$Draggable.position = center_position + offset

		# Guard against divide-by-zero / NaN
		if joystick_radius > 0.0:
			var dir := offset / joystick_radius
			if is_nan(dir.x) or is_nan(dir.y):
				dir = Vector2.ZERO
			JoystickInput.direction = dir
		else:
			JoystickInput.direction = Vector2.ZERO
