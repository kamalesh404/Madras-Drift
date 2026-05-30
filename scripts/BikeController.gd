extends VehicleBody3D

# ── Madras Drift ── Bike Controller
# Attach to a VehicleBody3D node

@export var max_engine_force: float = 150.0
@export var max_brake_force: float = 80.0
@export var max_steer_angle: float = 0.4
@export var steer_speed: float = 3.0
@export var nitro_multiplier: float = 2.0
@export var lean_amount: float = 0.06

# Wheels — assign in Inspector
@export var wheel_front_left: NodePath
@export var wheel_front_right: NodePath
@export var wheel_rear_left: NodePath
@export var wheel_rear_right: NodePath

@onready var wfl: VehicleWheel3D = get_node(wheel_front_left)
@onready var wfr: VehicleWheel3D = get_node(wheel_front_right)
@onready var wrl: VehicleWheel3D = get_node(wheel_rear_left)
@onready var wrr: VehicleWheel3D = get_node(wheel_rear_right)

var current_steer: float = 0.0
var nitro_active: bool = false
var nitro_fuel: float = 100.0
var speed_kmh: float = 0.0
var is_player_on: bool = false

signal speed_changed(kmh)
signal nitro_changed(fuel)

func _ready() -> void:
	# Setup rear wheels as drive wheels
	if wrl: wrl.use_as_traction = true
	if wrr: wrr.use_as_traction = true
	if wfl: wfl.use_as_steering = true
	if wfr: wfr.use_as_steering = true

func _physics_process(delta: float) -> void:
	if not is_player_on:
		return

	var throttle := Input.get_axis("move_back", "move_forward")
	var steer_input := Input.get_axis("move_right", "move_left")
	var braking := Input.is_action_pressed("jump")  # Space = brake

	# Nitro
	nitro_active = Input.is_action_pressed("sprint") and nitro_fuel > 0
	var engine_mult := nitro_multiplier if nitro_active else 1.0

	if nitro_active:
		nitro_fuel = max(nitro_fuel - 20 * delta, 0)
	else:
		nitro_fuel = min(nitro_fuel + 5 * delta, 100)
	emit_signal("nitro_changed", nitro_fuel)

	# Apply forces
	engine_force = throttle * max_engine_force * engine_mult
	brake = max_brake_force if braking else 0.0

	# Smooth steering
	current_steer = lerp(current_steer, steer_input * max_steer_angle, steer_speed * delta)
	if wfl: wfl.steering = current_steer
	if wfr: wfr.steering = current_steer

	# Lean on curves
	var lean := -current_steer * lean_amount * (linear_velocity.length() / 10.0)
	rotation.z = lerp(rotation.z, lean, 5.0 * delta)

	# Speed in km/h
	speed_kmh = linear_velocity.length() * 3.6
	emit_signal("speed_changed", speed_kmh)

func mount_player(player: CharacterBody3D) -> void:
	is_player_on = true
	player.is_on_bike = true
	player.reparent(self)
	player.position = Vector3(0, 0.5, 0)

func dismount_player(player: CharacterBody3D) -> void:
	is_player_on = false
	player.is_on_bike = false
	player.reparent(get_tree().current_scene)
	player.global_position = global_position + Vector3(1.5, 0, 0)
