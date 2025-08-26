extends Control   # Attach to your on-screen joystick Control

@export var joystick_radius: float = 110.0  # Max distance in pixels
var dragging: bool = false
var center_position: Vector2

func _ready() -> void:
	center_position = $Draggable.position
	$Draggable.position = center_position
	mouse_filter = MOUSE_FILTER_PASS  # Let touches propagate if needed

func _gui_input(event: InputEvent) -> void:
	# --- START DRAG ---
	if (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if joystick_radius > 0.0:
			dragging = true

	# --- END DRAG ---
	if (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if dragging:
			dragging = false
			$Draggable.position = center_position
			JoystickInput.direction = Vector2.ZERO

	# --- DRAGGING MOTION ---
	if dragging:
		# Touch/mouse pos relative to this Control
		var local_pos: Vector2 = get_local_mouse_position()
		var offset: Vector2 = local_pos - (size * 0.5)

		# Clamp to radius
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius

		# Move handle
		$Draggable.position = center_position + offset

		# Compute analog direction strength
		if joystick_radius > 0.0:
			var strength: float = offset.length() / joystick_radius
			var dir: Vector2 = offset.normalized() * strength
			if is_nan(dir.x) or is_nan(dir.y):
				dir = Vector2.ZERO
			JoystickInput.direction = dir
		else:
			JoystickInput.direction = Vector2.ZERO
