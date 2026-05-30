extends CharacterBody3D

# ── Madras Drift ── Player Controller (AJ)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 5.0
@export var gravity: float = 20.0
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0
@export var rotation_speed: float = 10.0

# State machine
enum State { IDLE, WALK, SPRINT, JUMP, FALL }
var current_state: State = State.IDLE

# References — using get_node_or_null so no crash if path is wrong
@onready var model: Node3D = get_node_or_null("Model")
var animation_player: AnimationPlayer = null

# Camera — found at runtime
var camera: Camera3D = null

# Internal
var speed: float = 0.0
var in_vehicle: bool = false
var current_vehicle: Node = null
var health: float = 100.0
var wanted_level: int = 0

signal health_changed(new_health)
signal wanted_level_changed(level)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	camera = get_viewport().get_camera_3d()
	if model:
		animation_player = _find_animation_player(model)
		if animation_player:
			_auto_load_animations()
			
	print("Player ready! Camera found: ", camera != null)
	print("AnimationPlayer found: ", animation_player != null)

func _auto_load_animations() -> void:
	# Load ALL animations from their respective FBX files
	var files = {
		"idle": "res://assets/models/spy_idle.fbx",
		"walk": "res://assets/models/spy_walk.fbx",
		"run": "res://assets/models/spy_run.fbx",
		"jump": "res://assets/models/spy_jump.fbx"
	}
	
	# Find the ACTUAL Skeleton3D path relative to the AnimationPlayer's root
	var actual_skel_path = _find_skeleton_path()
	print("[Anim] Actual skeleton path: ", actual_skel_path)
	
	for action_name in files:
		var path = files[action_name]
		if not ResourceLoader.exists(path): continue
		
		var scene = load(path) as PackedScene
		if not scene: continue
		
		var instance = scene.instantiate()
		var src_player = _find_animation_player(instance)
		if not src_player: 
			instance.queue_free()
			continue
			
		var src_lib: AnimationLibrary = null
		var src_anim_name: String = ""
		for slib_name in src_player.get_animation_library_list():
			var slib = src_player.get_animation_library(slib_name)
			if slib and slib.get_animation_list().size() > 0:
				src_lib = slib
				src_anim_name = _get_best_animation_name(slib)
				break
				
		if src_lib:
			var new_lib = AnimationLibrary.new()
			var anim = src_lib.get_animation(src_anim_name).duplicate()
			
			# REMAP all track paths to point to OUR skeleton!
			_remap_animation_tracks(anim, actual_skel_path)
			
			if "jump" not in action_name:
				anim.loop_mode = Animation.LOOP_LINEAR
			new_lib.add_animation("mixamo_com", anim)
			if animation_player.has_animation_library(action_name):
				animation_player.remove_animation_library(action_name)
			animation_player.add_animation_library(action_name, new_lib)
			print("[Anim] ✅ Loaded: ", action_name)
		instance.queue_free()

func _find_skeleton_path() -> String:
	# Find the Skeleton3D node relative to the AnimationPlayer's root node
	if not animation_player:
		return "Skeleton3D"
	var root = animation_player.get_node(animation_player.root_node)
	var skel = _find_skeleton(root)
	if skel:
		return str(root.get_path_to(skel))
	return "Skeleton3D"

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null

func _remap_animation_tracks(anim: Animation, target_skel_path: String) -> void:
	# Remap every track so that the skeleton path matches our actual model
	for i in range(anim.get_track_count()):
		var track_path: NodePath = anim.track_get_path(i)
		var path_str: String = str(track_path)
		
		# Track paths look like "SomeNode/Skeleton3D:BoneName"
		# We need to replace everything before the colon's skeleton part
		if ":" in path_str:
			var colon_idx = path_str.find(":")
			var bone_part = path_str.substr(colon_idx)  # ":BoneName"
			# Replace the node path with our actual skeleton path
			var new_path = target_skel_path + bone_part
			anim.track_set_path(i, NodePath(new_path))
		elif "Skeleton" in path_str:
			# Track targets the skeleton node itself (no bone)
			anim.track_set_path(i, NodePath(target_skel_path))

func _get_best_animation_name(lib: AnimationLibrary) -> String:
	# Avoid 'Take 001' which is usually just a 1-frame T-pose!
	if lib.has_animation("mixamo_com"):
		return "mixamo_com"
	for anim in lib.get_animation_list():
		if "take" not in anim.to_lower():
			return anim
	return lib.get_animation_list()[0]

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result:
			return result
	return null

func _physics_process(delta: float) -> void:
	if in_vehicle:
		return
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	if model:
		_rotate_model(delta)
	_update_state()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction: Vector3
	if camera:
		# Move relative to camera direction
		var cam_forward := -camera.global_transform.basis.z
		var cam_right   :=  camera.global_transform.basis.x
		cam_forward.y = 0
		cam_right.y   = 0
		cam_forward = cam_forward.normalized()
		cam_right   = cam_right.normalized()
		direction = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		# Fallback: move in world direction if no camera
		direction = Vector3(input_dir.x, 0, input_dir.y)

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction.length() > 0.1:
		speed = move_toward(speed, target_speed, acceleration * delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		speed = move_toward(speed, 0.0, deceleration * delta)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

func _rotate_model(delta: float) -> void:
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		var target_angle := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)

func _update_state() -> void:
	var new_state: State = current_state
	
	# Determine movement from actual input
	var is_moving = Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
	var is_sprinting = Input.is_action_pressed("sprint")
	
	if is_on_floor():
		if is_moving:
			new_state = State.SPRINT if is_sprinting else State.WALK
		else:
			new_state = State.IDLE
	else:
		# Only switch to jump/fall if we are actually airborne, ignore tiny floor bumps
		if velocity.y > 1.0:
			new_state = State.JUMP
		elif velocity.y < -2.0:
			new_state = State.FALL

	if new_state != current_state:
		current_state = new_state
		_play_animation()

func _play_animation() -> void:
	if not animation_player:
		return
	match current_state:
		State.IDLE:
			if animation_player.has_animation("idle/mixamo_com"):
				animation_player.play("idle/mixamo_com", 0.2)
			else:
				_force_play_animation("idle")
		State.WALK:
			if animation_player.has_animation("walk/mixamo_com"):
				animation_player.play("walk/mixamo_com", 0.2)
			else:
				_force_play_animation("walk")
		State.SPRINT:
			if animation_player.has_animation("run/mixamo_com"):
				animation_player.play("run/mixamo_com", 0.2)
			else:
				_force_play_animation("run")
		State.JUMP, State.FALL:
			if animation_player.current_animation != "jump/mixamo_com":
				if animation_player.has_animation("jump/mixamo_com"):
					animation_player.play("jump/mixamo_com", 0.2)
				else:
					_force_play_animation("jump")

func _force_play_animation(keyword: String) -> void:
	if not animation_player: return
	# Find ANY animation containing the keyword in its library or animation name
	for lib_name in animation_player.get_animation_library_list():
		var lib = animation_player.get_animation_library(lib_name)
		if lib:
			for anim_name in lib.get_animation_list():
				if keyword in lib_name.to_lower() or keyword in anim_name.to_lower():
					var full_name = str(lib_name) + "/" + str(anim_name) if str(lib_name) != "" else str(anim_name)
					animation_player.play(full_name, 0.2)
					return
	
	# Ultimate fallback: just play literally anything that isn't empty
	for lib_name in animation_player.get_animation_library_list():
		var lib = animation_player.get_animation_library(lib_name)
		if lib and lib.get_animation_list().size() > 0:
			var anim_name = lib.get_animation_list()[0]
			var full_name = str(lib_name) + "/" + str(anim_name) if str(lib_name) != "" else str(anim_name)
			animation_player.play(full_name, 0.2)
			return

func take_damage(amount: float) -> void:
	health = clamp(health - amount, 0, 100)
	emit_signal("health_changed", health)
	if health <= 0:
		print("AJ is down!")

func increase_wanted_level() -> void:
	wanted_level = min(wanted_level + 1, 5)
	emit_signal("wanted_level_changed", wanted_level)

func decrease_wanted_level() -> void:
	wanted_level = max(wanted_level - 1, 0)
	emit_signal("wanted_level_changed", wanted_level)
