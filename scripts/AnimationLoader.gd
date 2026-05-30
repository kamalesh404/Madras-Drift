extends Node

# ── Madras Drift ── Animation Loader
# Attach this to the Player (CharacterBody3D) node
# Base model: Running (1).fbx (has mesh + run animation)
# Other animations loaded from separate FBX files

@export var anim_player_path: NodePath = "../Model/new_idle/AnimationPlayer"

@onready var anim_player: AnimationPlayer = get_node_or_null(anim_player_path)

func _ready() -> void:
	await get_tree().process_frame
	
	# If path is wrong, try to auto-find it
	if not anim_player:
		anim_player = _find_animation_player(get_parent())
	
	_load_all_animations()


# Map: library name → FBX file path
# new_idle.fbx is the BASE — already loaded with the model
# We load walk, run, jump on top
const ANIMATION_FILES := {
	"walk": "res://assets/models/new_walk.fbx",
	"run": "res://assets/models/new_run.fbx",
	"jump": "res://assets/models/new_jump.fbx",
}



func _load_all_animations() -> void:
	if not anim_player:
		push_error("AnimationLoader: AnimationPlayer not found at path: " + str(anim_player_path))
		return

	# Rename the base animation "Take 0" → "idle" in the default library
	_rename_base_animation()

	# Load other animations
	for lib_name in ANIMATION_FILES:
		var path: String = ANIMATION_FILES[lib_name]
		_load_animation_from_fbx(lib_name, path)

	# Print all loaded animations
	print("=== Madras Drift Animations Loaded ===")
	for lib in anim_player.get_animation_library_list():
		var library: AnimationLibrary = anim_player.get_animation_library(lib) as AnimationLibrary
		for anim_name in library.get_animation_list():
			var full: String = (lib + "/" + anim_name) if lib != "" else anim_name
			print("  ✅ ", full)
	print("======================================")

func _rename_base_animation() -> void:
	# Search all libraries for the first animation we can find to use as idle
	var libs = anim_player.get_animation_library_list()
	for lib_name in libs:
		var lib: AnimationLibrary = anim_player.get_animation_library(lib_name) as AnimationLibrary
		if lib and lib.get_animation_list().size() > 0:
			var idle_lib := AnimationLibrary.new()
			var first_anim_name = lib.get_animation_list()[0]
			var idle_anim: Animation = lib.get_animation(first_anim_name).duplicate()
			idle_anim.loop_mode = Animation.LOOP_LINEAR
			idle_lib.add_animation("mixamo_com", idle_anim)
			
			if not anim_player.has_animation_library("idle"):
				anim_player.add_animation_library("idle", idle_lib)
			break # Found our base animation, stop searching

func _load_animation_from_fbx(lib_name: String, fbx_path: String) -> void:
	if not ResourceLoader.exists(fbx_path):
		push_warning("Animation file not found: " + fbx_path)
		return

	var scene: PackedScene = load(fbx_path) as PackedScene
	if not scene:
		return

	var instance: Node = scene.instantiate()
	var src_player: AnimationPlayer = _find_animation_player(instance)

	if not src_player:
		instance.queue_free()
		return

	# Search the loaded FBX for its first animation, wherever it is
	var src_lib: AnimationLibrary = null
	var src_anim_name: String = ""
	
	for slib_name in src_player.get_animation_library_list():
		var slib = src_player.get_animation_library(slib_name)
		if slib and slib.get_animation_list().size() > 0:
			src_lib = slib
			src_anim_name = slib.get_animation_list()[0]
			break

	if not src_lib:
		instance.queue_free()
		return

	# Create a new local library so we can modify the read-only imported animations
	var local_lib := AnimationLibrary.new()
	var anim: Animation = src_lib.get_animation(src_anim_name).duplicate()
	if "jump" not in lib_name.to_lower():
		anim.loop_mode = Animation.LOOP_LINEAR
	
	# ALWAYS rename the animation to mixamo_com so Player.gd knows what to call
	local_lib.add_animation("mixamo_com", anim)

	if anim_player.has_animation_library(lib_name):
		anim_player.remove_animation_library(lib_name)

	anim_player.add_animation_library(lib_name, local_lib)
	instance.queue_free()
	print("Loaded: ", lib_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result:
			return result
	return null
