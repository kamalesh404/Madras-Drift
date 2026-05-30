extends Node3D

# ── Madras Drift ── Third Person Camera (Cinemachine-style)

@export var target: NodePath
@export var distance: float = 4.5
@export var height: float = 1.8
@export var h_sensitivity: float = 0.3
@export var v_sensitivity: float = 0.3
@export var min_pitch: float = -30.0
@export var max_pitch: float = 60.0
@export var smooth_speed: float = 8.0
@export var collision_margin: float = 0.3

var yaw: float = 0.0
var pitch: float = -10.0
var target_node: Node3D

func _ready() -> void:
	if target.is_empty():
		# Fallback: assume the camera is inside CameraPivot, which is inside Player
		target_node = get_parent().get_parent()
	else:
		target_node = get_node(target)
	set_as_top_level(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw   -= event.relative.x * h_sensitivity
		pitch -= event.relative.y * v_sensitivity
		pitch  = clamp(pitch, min_pitch, max_pitch)

func _process(delta: float) -> void:
	if not target_node:
		return
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var target_pos := target_node.global_position + Vector3(0, height, 0)

	# Orbit rotation
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))
	var offset := rotation_basis * Vector3(0, 0, distance)

	# Collision check
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(target_pos, target_pos + offset)
	query.exclude = [target_node]
	var result := space_state.intersect_ray(query)

	var desired_pos: Vector3
	if result:
		desired_pos = result.position - offset.normalized() * collision_margin
	else:
		desired_pos = target_pos + offset

	# Smooth follow
	global_position = global_position.lerp(desired_pos, smooth_speed * delta)
	look_at(target_pos, Vector3.UP)
