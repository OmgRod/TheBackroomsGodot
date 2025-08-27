extends CharacterBody3D

# --- CONSTANTS ---
const SPEED: float = 3.0
const SPRINT_MULTIPLIER: float = 1.75
const CROUCH_MULTIPLIER: float = 0.5
const JUMP_VELOCITY: float = 4.5

const NORMAL_FOV: float = 70.0
const SPRINT_FOV: float = 90.0
const FOV_LERP_SPEED: float = 8.0

const STAND_HEIGHT: float = 2.0
const CROUCH_HEIGHT: float = 1.2
const STAND_NECK_Y: float = 0.9
const CROUCH_NECK_Y: float = 0.5

const BOB_FREQUENCY: float = 8.0
const BOB_AMPLITUDE_WALK: float = 0.03
const BOB_AMPLITUDE_SPRINT: float = 0.07
const BOB_AMPLITUDE_CROUCH: float = 0.1

# --- NODE REFERENCES ---
@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var footstep_audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# --- STATE VARIABLES ---
var can_jump: bool = true
var footstep_cooldown: float = 0.0
var is_crouching: bool = false
var forced_crouch: bool = false

var bob_timer: float = 0.0
var base_camera_pos: Vector3 = Vector3.ZERO

# --- TOUCH LOOK (right half of screen) ---
@export var look_sensitivity: float = 0.01
var camera_touch_index: int = -1
var last_camera_touch_pos: Vector2 = Vector2.ZERO

# --- RNG for footsteps ---
var _rng := RandomNumberGenerator.new()

# --- SURFACE FOOTSTEP SOUNDS ---
var surface_sounds := {
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

# --- READY ---
func _ready() -> void:
		base_camera_pos = camera.position
		_rng.randomize()

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
		# Desktop mouse look
		if event is InputEventMouseButton:
				if event.pressed:
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.is_action_pressed("ui_cancel"):
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
				neck.rotate_y(-event.relative.x * 0.01)
				camera.rotate_x(-event.relative.y * 0.01)
				camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-75), deg_to_rad(75))

		# Only mobile: touch look on right half
		if OS.has_feature("mobile"):
				var vp_size: Vector2 = get_viewport().get_visible_rect().size
				var right_half_start_x: float = vp_size.x * 0.5

				if event is InputEventScreenTouch:
						if event.pressed and event.position.x >= right_half_start_x and camera_touch_index == -1:
								camera_touch_index = event.index
								last_camera_touch_pos = event.position
						elif not event.pressed and event.index == camera_touch_index:
								camera_touch_index = -1
				elif event is InputEventScreenDrag:
						if event.index == camera_touch_index:
								var delta: Vector2 = event.position - last_camera_touch_pos
								last_camera_touch_pos = event.position
								neck.rotate_y(-delta.x * look_sensitivity)
								camera.rotate_x(-delta.y * look_sensitivity)
								camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-75), deg_to_rad(75))

# --- PHYSICS PROCESS ---
func _physics_process(delta: float) -> void:
		if footstep_cooldown > 0.0:
				footstep_cooldown -= delta

		# Gravity
		if not is_on_floor():
				velocity += get_gravity() * delta
				can_jump = false
		else:
				can_jump = true

		# Crouch
		var input_crouch: bool = Input.is_action_pressed("crouch")
		is_crouching = forced_crouch or input_crouch

		# Jump
		if Input.is_action_pressed("ui_accept") and can_jump and not is_crouching and not forced_crouch:
				velocity.y = JUMP_VELOCITY
				can_jump = false

		# --- Movement input ---
		var input_dir: Vector2 = Vector2.ZERO
		if OS.has_feature("mobile"):
				input_dir = JoystickInput.direction
		else:
				input_dir = Input.get_vector("left", "right", "forward", "back")

		if is_nan(input_dir.x) or is_nan(input_dir.y):
				input_dir = Vector2.ZERO

		var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
		if direction.length() > 0.0:
				direction = (neck.transform.basis * direction).normalized()
		else:
				direction = Vector3.ZERO

		# Sprint speed
		var sprinting: bool = Input.is_action_pressed("sprint") and not is_crouching
		var speed: float = SPEED * (SPRINT_MULTIPLIER if sprinting else (CROUCH_MULTIPLIER if is_crouching else 1.0))

		# Apply analog movement scaled by joystick magnitude
		if direction != Vector3.ZERO:
				velocity.x = direction.x * speed * input_dir.length()
				velocity.z = direction.z * speed * input_dir.length()
		else:
				velocity.x = move_toward(velocity.x, 0.0, SPEED)
				velocity.z = move_toward(velocity.z, 0.0, SPEED)

		move_and_slide()

		# FOV
		var target_fov: float = SPRINT_FOV if sprinting else NORMAL_FOV
		camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)

		# Other updates
		_update_crouch_state(delta)
		_apply_camera_bobbing(delta, velocity.length(), sprinting, is_crouching, input_dir.length())
		_update_footstep_sounds(direction, sprinting, input_dir.length())

# --- CROUCH LOGIC ---
func _update_crouch_state(delta: float) -> void:
		forced_crouch = false

		var target_height: float = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
		var target_neck_y: float = CROUCH_NECK_Y if is_crouching else STAND_NECK_Y

		if not is_crouching:
				var head_global_pos: Vector3 = global_transform.origin + Vector3(0, get_capsule_current_height() / 2.0, 0)
				var check_end: Vector3 = head_global_pos + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)
				var ray_params := PhysicsRayQueryParameters3D.create(head_global_pos, check_end)
				ray_params.exclude = [self]
				var result := get_world_3d().direct_space_state.intersect_ray(ray_params)
				if result:
						target_height = CROUCH_HEIGHT
						target_neck_y = CROUCH_NECK_Y
						forced_crouch = true
						is_crouching = true

		collision_shape.scale.y = lerp(collision_shape.scale.y, target_height / STAND_HEIGHT, delta * 10.0)
		neck.position.y = lerp(neck.position.y, target_neck_y, delta * 10.0)

func get_capsule_current_height() -> float:
		if collision_shape.shape is CapsuleShape3D:
				return (collision_shape.shape as CapsuleShape3D).height * collision_shape.scale.y
		return STAND_HEIGHT

# --- CAMERA BOBBING ---
func _apply_camera_bobbing(delta: float, speed_len: float, sprinting: bool, crouching: bool, move_factor: float) -> void:
		if speed_len > 0.1 and is_on_floor():
				bob_timer += delta * BOB_FREQUENCY * (speed_len / SPEED)
				var amplitude: float = BOB_AMPLITUDE_WALK
				if sprinting:
						amplitude = BOB_AMPLITUDE_SPRINT
				elif crouching:
						amplitude = BOB_AMPLITUDE_CROUCH

				# Scale bob by movement factor (analog feel)
				amplitude *= move_factor

				camera.position.x = base_camera_pos.x + amplitude * 0.5 * sin(bob_timer * 2.0)
				camera.position.y = base_camera_pos.y + amplitude * sin(bob_timer)
		else:
				bob_timer = 0.0
				camera.position = base_camera_pos

# --- FOOTSTEP SOUNDS ---
func _update_footstep_sounds(direction: Vector3, sprinting: bool, move_factor: float) -> void:
		if move_factor <= 0.0:
				return

		var ray_origin: Vector3 = global_transform.origin
		var ray_end: Vector3 = ray_origin - Vector3.UP * 1.5
		var ray_params := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		ray_params.exclude = [self]

		var result := get_world_3d().direct_space_state.intersect_ray(ray_params)

		if result and result.collider:
				var node: Node = result.collider
				while node and not node.has_meta("MaterialType"):
						node = node.get_parent()
				if node and node.has_meta("MaterialType"):
						var material: String = str(node.get_meta("MaterialType")).to_lower()
						if material in surface_sounds and direction.length() > 0.1 and is_on_floor():
								if footstep_cooldown <= 0.0:
										var sounds: Array = surface_sounds.get(material, [])
										if sounds.size() > 0:
												var idx: int = _rng.randi_range(0, sounds.size() - 1)
												footstep_audio.stream = sounds[idx]

												var base_cooldown: float
												var vol: float
												if sprinting:
													base_cooldown = 0.25
													vol = 0.5
												elif is_crouching:
													base_cooldown = 0.6
													vol = 0.1
												else:
													base_cooldown = 0.4
													vol = 0.25

												footstep_audio.volume_db = linear_to_db(vol)
												footstep_cooldown = base_cooldown / move_factor
												footstep_audio.play()
						elif footstep_audio.playing:
								footstep_audio.stop()
		elif footstep_audio.playing:
				footstep_audio.stop()
