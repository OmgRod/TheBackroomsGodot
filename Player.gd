extends CharacterBody3D

const SPEED = 3.0
const SPRINT_MULTIPLIER = 1.75
const JUMP_VELOCITY = 4.5

const NORMAL_FOV = 70.0
const SPRINT_FOV = 90.0
const FOV_LERP_SPEED = 8.0

@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var footstep_audio := $AudioStreamPlayer

var can_jump = true
var footstep_cooldown = 0.0

var carpet_sounds = [
	preload("res://sounds/footstep_carpet_000.ogg"),
	preload("res://sounds/footstep_carpet_001.ogg"),
	preload("res://sounds/footstep_carpet_002.ogg"),
	preload("res://sounds/footstep_carpet_003.ogg"),
	preload("res://sounds/footstep_carpet_004.ogg")
]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			neck.rotate_y(-event.relative.x * 0.01)
			camera.rotate_x(-event.relative.y * 0.01)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-75), deg_to_rad(75))

func _physics_process(delta: float) -> void:
	if footstep_cooldown > 0:
		footstep_cooldown -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta
		can_jump = false
	else:
		can_jump = true

	if Input.is_action_pressed("ui_accept") and can_jump:
		velocity.y = JUMP_VELOCITY
		can_jump = false

	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting = Input.is_action_pressed("sprint")
	var speed = SPEED * SPRINT_MULTIPLIER if sprinting else SPEED

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	var target_fov = SPRINT_FOV if sprinting else NORMAL_FOV
	camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)

	var ray_origin = global_transform.origin
	var ray_end = ray_origin - Vector3.UP * 1.5

	var ray_params = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_params.exclude = [self]

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(ray_params)

	if result and result.collider:
		var node = result.collider
		while node and not node.has_meta("MaterialType"):
			node = node.get_parent()
		if node and node.has_meta("MaterialType"):
			var material = str(node.get_meta("MaterialType")).to_lower()
			if material == "carpet" and direction.length() > 0.1 and is_on_floor():
				if footstep_cooldown <= 0.0:
					footstep_audio.stream = carpet_sounds[randi() % carpet_sounds.size()]
					footstep_audio.play()
					footstep_cooldown = 0.25 if sprinting else 0.5
			else:
				if footstep_audio.playing:
					footstep_audio.stop()
		else:
			if footstep_audio.playing:
				footstep_audio.stop()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()
