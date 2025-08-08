extends CharacterBody3D

# --- CONSTANTS ---
const SPEED = 3.0
const SPRINT_MULTIPLIER = 1.75
const CROUCH_MULTIPLIER = 0.5
const JUMP_VELOCITY = 4.5

const NORMAL_FOV = 70.0
const SPRINT_FOV = 90.0
const FOV_LERP_SPEED = 8.0

const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.2
const STAND_NECK_Y = 0.9
const CROUCH_NECK_Y = 0.5

const BOB_FREQUENCY = 8.0
const BOB_AMPLITUDE_WALK = 0.03
const BOB_AMPLITUDE_SPRINT = 0.07
const BOB_AMPLITUDE_CROUCH = 0.1


# --- NODE REFERENCES ---
@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var footstep_audio := $AudioStreamPlayer
@onready var collision_shape := $CollisionShape3D


# --- STATE VARIABLES ---
var can_jump = true
var footstep_cooldown = 0.0
var is_crouching = false
var forced_crouch = false

var bob_timer = 0.0
var base_camera_pos = Vector3.ZERO


# --- SURFACE FOOTSTEP SOUNDS ---
var surface_sounds = {
	"carpet": [
		preload("res://sounds/footstep_carpet_000.ogg"),
		preload("res://sounds/footstep_carpet_001.ogg"),
		preload("res://sounds/footstep_carpet_002.ogg"),
		preload("res://sounds/footstep_carpet_003.ogg"),
		preload("res://sounds/footstep_carpet_004.ogg")
	],
	"concrete": [
		preload("res://sounds/footstep_concrete_000.ogg"),
		preload("res://sounds/footstep_concrete_001.ogg"),
		preload("res://sounds/footstep_concrete_002.ogg"),
		preload("res://sounds/footstep_concrete_003.ogg"),
		preload("res://sounds/footstep_concrete_004.ogg")
	]
}


# --- GODOT CALLBACKS ---

func _ready() -> void:
	base_camera_pos = camera.position


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

	var input_crouch = Input.is_action_pressed("crouch")

	if forced_crouch:
		is_crouching = true
	else:
		is_crouching = input_crouch

	if Input.is_action_pressed("ui_accept") and can_jump and not is_crouching and not forced_crouch:
		velocity.y = JUMP_VELOCITY
		can_jump = false

	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting = Input.is_action_pressed("sprint") and not is_crouching
	var speed = SPEED * SPRINT_MULTIPLIER if sprinting else SPEED * (CROUCH_MULTIPLIER if is_crouching else 1)

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	var target_fov = SPRINT_FOV if sprinting else NORMAL_FOV
	camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)

	_update_crouch_state(delta)
	_apply_camera_bobbing(delta, velocity.length(), sprinting, is_crouching)

	_update_footstep_sounds(direction, sprinting)


# --- CROUCH LOGIC ---

func _update_crouch_state(delta: float) -> void:
	forced_crouch = false

	var target_height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var target_neck_y = CROUCH_NECK_Y if is_crouching else STAND_NECK_Y

	if not is_crouching:
		var head_global_pos = global_transform.origin + Vector3(0, get_capsule_current_height() / 2, 0)
		var check_end = head_global_pos + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)

		var ray_params = PhysicsRayQueryParameters3D.create(head_global_pos, check_end)
		ray_params.exclude = [self]
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(ray_params)
		if result:
			target_height = CROUCH_HEIGHT
			target_neck_y = CROUCH_NECK_Y
			forced_crouch = true
			is_crouching = true

	var target_scale_y = target_height / STAND_HEIGHT
	var current_scale = collision_shape.scale
	current_scale.y = lerp(current_scale.y, target_scale_y, delta * 10)
	collision_shape.scale = current_scale

	var neck_pos = neck.position
	neck_pos.y = lerp(neck_pos.y, target_neck_y, delta * 10)
	neck.position = neck_pos


func get_capsule_current_height() -> float:
	var capsule = collision_shape.shape
	if capsule is CapsuleShape3D:
		return capsule.height * collision_shape.scale.y
	return STAND_HEIGHT


# --- CAMERA BOBBING ---

func _apply_camera_bobbing(delta: float, speed: float, sprinting: bool, crouching: bool) -> void:
	if speed > 0.1 and is_on_floor():
		bob_timer += delta * BOB_FREQUENCY * (speed / SPEED)
		var amplitude = BOB_AMPLITUDE_WALK
		if sprinting:
			amplitude = BOB_AMPLITUDE_SPRINT
		elif crouching:
			amplitude = BOB_AMPLITUDE_CROUCH

		var bob_x = amplitude * 0.5 * sin(bob_timer * 2)
		var bob_y = amplitude * sin(bob_timer)

		camera.position.x = base_camera_pos.x + bob_x
		camera.position.y = base_camera_pos.y + bob_y
	else:
		bob_timer = 0.0
		camera.position = base_camera_pos


# --- FOOTSTEP SOUNDS ---

func _update_footstep_sounds(direction: Vector3, sprinting: bool) -> void:
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
			if material in surface_sounds and direction.length() > 0.1 and is_on_floor():
				if footstep_cooldown <= 0.0:
					var sounds = surface_sounds[material]
					footstep_audio.stream = sounds[randi() % sounds.size()]

					if sprinting:
						footstep_audio.volume_db = linear_to_db(0.5)
						footstep_cooldown = 0.25
					elif is_crouching:
						footstep_audio.volume_db = linear_to_db(0.1)
						footstep_cooldown = 0.6
					else:
						footstep_audio.volume_db = linear_to_db(0.25)
						footstep_cooldown = 0.4

					footstep_audio.play()
			else:
				if footstep_audio.playing:
					footstep_audio.stop()
		else:
			if footstep_audio.playing:
				footstep_audio.stop()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()
