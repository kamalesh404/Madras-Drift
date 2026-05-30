extends VehicleBody3D

# ── Madras Drift — Bike Controller ──
# Suzuki GSX 750 with lean physics, wheelie detection, and speed boost
# Uses _integrate_forces to prevent the bike from falling over (locked roll/pitch)

# ── Tuning ──
const MAX_ENGINE_FORCE: float = 600.0
const MAX_REVERSE_FORCE: float = 200.0
const MAX_STEER_ANGLE: float = 0.6
const STEER_SPEED: float = 4.0
const BOOST_MULTIPLIER: float = 1.5
const BRAKE_FORCE: float = 8.0
const LEAN_DEGREES: float = 25.0
const WHEELIE_PITCH: float = 12.0
const WHEELIE_SPEED_THRESHOLD: float = 5.0

# ── State ──
var active: bool = false
var driver: CharacterBody3D = null
var player_in_range: CharacterBody3D = null
var show_prompt: bool = false
var is_drifting: bool = false
var current_steer: float = 0.0
var current_lean: float = 0.0
var current_wheelie: float = 0.0
var nitro_fuel: float = 100.0
var headlight_on: bool = false
var light_cooldown: float = 0.0

# ── Cached ──
@onready var interact_area: Area3D = $InteractArea
var bike_model: Node3D = null
var headlight: SpotLight3D = null
var wheel_meshes: Array = []

func _ready() -> void:
	mass = 220.0

	# Find the model child
	for child in get_children():
		if child.name == "Model":
			bike_model = child
			break

	# Create headlight
	headlight = SpotLight3D.new()
	headlight.name = "Headlight"
	headlight.spot_range = 30.0
	headlight.spot_angle = 35.0
	headlight.light_energy = 3.0
	headlight.transform.origin = Vector3(0.0, 0.6, 1.2)
	headlight.rotation_degrees.x = -15.0
	headlight.visible = false
	add_child(headlight)

	# Gather wheel meshes for spin animation
	for child in get_children():
		if child is VehicleWheel3D:
			for sub in child.get_children():
				if sub is MeshInstance3D:
					wheel_meshes.append({"wheel": child, "mesh": sub})
					break

	# Connect interact area signals
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	print("[Bike] Ready! Wheels: ", wheel_meshes.size())

# ── CRITICAL: Keep bike upright ──
# VehicleBody3D with 2 wheels will fall over without this.
# We lock the roll (Z) and pitch (X) axes in physics, keeping only yaw (Y) rotation.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var t = state.transform
	var euler = t.basis.get_euler()
	# Lock roll and pitch, keep yaw
	euler.x = 0.0
	euler.z = 0.0
	t.basis = Basis.from_euler(euler)
	state.transform = t

func _physics_process(delta: float) -> void:
	show_prompt = player_in_range != null and not active

	if not active:
		engine_force = 0.0
		brake = 0.0
		return

	# ── Exit check ──
	if Input.is_action_just_pressed("interact"):
		exit_bike()
		return

	# ── Throttle (W/S) ──
	var accel = Input.get_action_strength("move_forward")
	var reverse_input = Input.get_action_strength("move_back")
	var boosting = Input.is_action_pressed("sprint")

	var target_force: float = 0.0
	if accel > 0.0:
		target_force = accel * MAX_ENGINE_FORCE
		if boosting and nitro_fuel > 0:
			target_force *= BOOST_MULTIPLIER
			nitro_fuel = maxf(nitro_fuel - 12.0 * delta, 0.0)
	elif reverse_input > 0.0:
		target_force = -reverse_input * MAX_REVERSE_FORCE

	# Nitro recharge
	if not boosting or accel <= 0:
		nitro_fuel = minf(nitro_fuel + 5.0 * delta, 100.0)

	engine_force = target_force

	# ── Braking (Space) ──
	if Input.is_action_pressed("jump"):
		brake = BRAKE_FORCE
	else:
		brake = 0.0

	# ── Steering (A/D) ──
	var steer_left = Input.get_action_strength("move_left")
	var steer_right = Input.get_action_strength("move_right")
	var target_steer = (steer_left - steer_right) * MAX_STEER_ANGLE
	current_steer = lerp(current_steer, target_steer, STEER_SPEED * delta)
	steering = current_steer

	# ── Visual Lean Animation (model only, not the physics body) ──
	var target_lean = -current_steer * LEAN_DEGREES
	current_lean = lerp(current_lean, target_lean, 5.0 * delta)

	# ── Visual Wheelie Detection ──
	var speed = linear_velocity.length()
	var target_wheelie: float = 0.0
	if accel > 0.9 and speed < WHEELIE_SPEED_THRESHOLD:
		target_wheelie = -WHEELIE_PITCH
	current_wheelie = lerp(current_wheelie, target_wheelie, 4.0 * delta)

	# Apply lean + wheelie to the visual model only
	if bike_model:
		bike_model.rotation_degrees.z = current_lean
		bike_model.rotation_degrees.x = current_wheelie

	# ── Wheel Spin ──
	var spin_speed = speed * 2.0 * delta
	for entry in wheel_meshes:
		entry["mesh"].rotate_x(spin_speed)

func _process(delta: float) -> void:
	# Toggle headlight with L
	light_cooldown -= delta
	if active and Input.is_key_pressed(KEY_L) and light_cooldown <= 0:
		headlight_on = not headlight_on
		headlight.visible = headlight_on
		light_cooldown = 0.3

	# Enter bike when near and pressing F
	if not active and player_in_range and Input.is_action_just_pressed("interact"):
		enter_bike(player_in_range)

func get_nitro_percent() -> float:
	return nitro_fuel

# ── Enter / Exit ──
func enter_bike(player: CharacterBody3D) -> void:
	if active:
		return
	active = true
	driver = player

	# Disable player and hide
	driver.set_physics_process(false)
	driver.set_process(false)
	driver.hide()
	driver.in_vehicle = true
	driver.current_vehicle = self

	# Point the third person camera at the BIKE
	var cam_pivot = driver.get_node_or_null("CameraPivot")
	if cam_pivot:
		var cam_script = cam_pivot.get_child(0) if cam_pivot.get_child_count() > 0 else null
		if cam_script and cam_script.has_method("_update_camera"):
			cam_script.target_node = self
			cam_script.distance = 5.0
			cam_script.height = 2.0

	brake = 0.0
	print("[Bike] 🏍️ Player mounted!")

func exit_bike() -> void:
	if not active or not driver:
		return
	active = false

	# Point the camera back at the PLAYER
	var cam_pivot = driver.get_node_or_null("CameraPivot")
	if cam_pivot:
		var cam_script = cam_pivot.get_child(0) if cam_pivot.get_child_count() > 0 else null
		if cam_script and cam_script.has_method("_update_camera"):
			cam_script.target_node = driver
			cam_script.distance = 4.5
			cam_script.height = 1.8

	# Place player next to the bike (on the ground, not underground)
	driver.global_position = global_position + global_transform.basis.x * 2.0
	driver.global_position.y = global_position.y + 0.5

	driver.in_vehicle = false
	driver.current_vehicle = null
	driver.set_physics_process(true)
	driver.set_process(true)
	driver.show()
	driver = null

	engine_force = 0.0
	brake = BRAKE_FORCE
	current_steer = 0.0
	steering = 0.0
	current_lean = 0.0
	current_wheelie = 0.0
	print("[Bike] 🏍️ Player dismounted!")

# ── Interaction Area ──
func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "player":
		player_in_range = body

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
