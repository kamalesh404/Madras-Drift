extends VehicleBody3D

# ── Madras Drift — Car Controller ──
# Toyota GR86 Drift Car with full physics, wheel spin, drift, headlights, nitro

# ── Tuning ──
const MAX_ENGINE_FORCE: float = 800.0
const MAX_REVERSE_FORCE: float = 400.0
const MAX_STEER_ANGLE: float = 0.4
const STEER_SPEED: float = 5.0
const TURBO_MULTIPLIER: float = 1.8
const BRAKE_FORCE: float = 5.0
const HANDBRAKE_FORCE: float = 15.0
const HANDBRAKE_FRICTION: float = 3.0
const DEFAULT_FRICTION: float = 10.5
const DRIFT_ANGLE_THRESHOLD: float = 20.0
const DRIFT_FRICTION: float = 4.5

# ── State ──
var active: bool = false
var driver: CharacterBody3D = null
var player_in_range: CharacterBody3D = null
var show_prompt: bool = false
var is_drifting: bool = false
var headlights_on: bool = false
var current_steer: float = 0.0
var nitro_fuel: float = 100.0
var light_cooldown: float = 0.0

# ── Cached ──
@onready var interact_area: Area3D = $InteractArea
var wheel_data: Array = []
var rear_wheels: Array = []
var headlight_left: SpotLight3D = null
var headlight_right: SpotLight3D = null

func _ready() -> void:
	# Discover wheels and their visual meshes
	for child in get_children():
		if child is VehicleWheel3D:
			var wheel := child as VehicleWheel3D
			var mesh: MeshInstance3D = null
			for sub in wheel.get_children():
				if sub is MeshInstance3D:
					mesh = sub
					break
			wheel_data.append({"wheel": wheel, "mesh": mesh})
			if wheel.use_as_traction:
				rear_wheels.append(wheel)

	# Create headlights
	headlight_left = _create_headlight("HeadlightLeft", Vector3(-0.6, 0.5, 2.2))
	headlight_right = _create_headlight("HeadlightRight", Vector3(0.6, 0.5, 2.2))

	# Interaction area signals
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	
	print("[Car] Ready! Wheels: ", wheel_data.size(), " Rear: ", rear_wheels.size())

func _create_headlight(light_name: String, pos: Vector3) -> SpotLight3D:
	var light = SpotLight3D.new()
	light.name = light_name
	light.transform.origin = pos
	light.rotation_degrees = Vector3(-10, 0, 0)
	light.light_energy = 3.0
	light.spot_range = 30.0
	light.spot_angle = 30.0
	light.shadow_enabled = true
	light.visible = false
	add_child(light)
	return light

func _physics_process(delta: float) -> void:
	show_prompt = player_in_range != null and not active

	if not active:
		engine_force = 0.0
		steering = move_toward(steering, 0.0, STEER_SPEED * delta)
		brake = BRAKE_FORCE
		return

	# ── Exit check ──
	if Input.is_action_just_pressed("interact"):
		exit_car()
		return

	# ── Throttle (W/S) ──
	var accel = Input.get_action_strength("move_forward")
	var reverse_input = Input.get_action_strength("move_back")
	var turbo = Input.is_action_pressed("sprint")

	var target_force: float = 0.0
	if accel > 0.0:
		target_force = accel * MAX_ENGINE_FORCE
		if turbo and nitro_fuel > 0:
			target_force *= TURBO_MULTIPLIER
			nitro_fuel = maxf(nitro_fuel - 15.0 * delta, 0.0)
	elif reverse_input > 0.0:
		target_force = -reverse_input * MAX_REVERSE_FORCE

	# Nitro recharges when not boosting
	if not turbo or accel <= 0:
		nitro_fuel = minf(nitro_fuel + 5.0 * delta, 100.0)

	engine_force = target_force

	# ── Steering (A/D) ──
	var steer_left = Input.get_action_strength("move_left")
	var steer_right = Input.get_action_strength("move_right")
	var raw_steer = (steer_left - steer_right) * MAX_STEER_ANGLE
	current_steer = lerp(current_steer, raw_steer, STEER_SPEED * delta)
	steering = current_steer

	# ── Handbrake (Space) ──
	var handbrake = Input.is_action_pressed("jump")
	if handbrake:
		brake = HANDBRAKE_FORCE
		for rw in rear_wheels:
			rw.wheel_friction_slip = HANDBRAKE_FRICTION
	else:
		brake = 0.0
		for rw in rear_wheels:
			rw.wheel_friction_slip = DEFAULT_FRICTION

	# ── Drift Detection ──
	var speed = linear_velocity.length()
	var forward = -global_transform.basis.z.normalized()
	is_drifting = false
	if speed > 2.0:
		var vel_dir = linear_velocity.normalized()
		var dot = clampf(forward.dot(vel_dir), -1.0, 1.0)
		var angle_deg = rad_to_deg(acos(dot))
		if angle_deg > DRIFT_ANGLE_THRESHOLD:
			is_drifting = true
			if not handbrake:
				for wd in wheel_data:
					wd["wheel"].wheel_friction_slip = DRIFT_FRICTION

	# ── Wheel Spin Animation ──
	var spin_dir: float = 1.0
	if speed > 0.5:
		spin_dir = signf(forward.dot(linear_velocity))
	for wd in wheel_data:
		if wd["mesh"] != null:
			wd["mesh"].rotate_x(speed * delta * spin_dir)

func _process(delta: float) -> void:
	# Toggle headlights with L (with cooldown to prevent rapid flickering)
	light_cooldown -= delta
	if active and Input.is_key_pressed(KEY_L) and light_cooldown <= 0:
		headlights_on = not headlights_on
		headlight_left.visible = headlights_on
		headlight_right.visible = headlights_on
		light_cooldown = 0.3

	# Enter vehicle when near and pressing F
	if not active and player_in_range and Input.is_action_just_pressed("interact"):
		enter_car(player_in_range)

func get_nitro_percent() -> float:
	return nitro_fuel

# ── Enter / Exit ──
func enter_car(player: CharacterBody3D) -> void:
	if active:
		return
	active = true
	driver = player

	# Disable player physics and hide
	driver.set_physics_process(false)
	driver.set_process(false)
	driver.hide()
	driver.in_vehicle = true
	driver.current_vehicle = self

	# Point the third person camera at the CAR instead of the player
	var cam_pivot = driver.get_node_or_null("CameraPivot")
	if cam_pivot:
		var cam_script = cam_pivot.get_child(0) if cam_pivot.get_child_count() > 0 else null
		if cam_script and cam_script.has_method("_update_camera"):
			cam_script.target_node = self
			cam_script.distance = 7.0  # Pull back further for car
			cam_script.height = 2.5

	# Release handbrake
	brake = 0.0
	print("[Car] 🚗 Player entered!")

func exit_car() -> void:
	if not active or not driver:
		return
	active = false

	# Point the camera back at the PLAYER
	var cam_pivot = driver.get_node_or_null("CameraPivot")
	if cam_pivot:
		var cam_script = cam_pivot.get_child(0) if cam_pivot.get_child_count() > 0 else null
		if cam_script and cam_script.has_method("_update_camera"):
			cam_script.target_node = driver
			cam_script.distance = 4.5  # Original distance
			cam_script.height = 1.8

	# Place player next to the car door
	driver.global_position = global_position + global_transform.basis.x * 2.5
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
	print("[Car] 🚗 Player exited!")

# ── Interaction Area ──
func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "player":
		player_in_range = body

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
