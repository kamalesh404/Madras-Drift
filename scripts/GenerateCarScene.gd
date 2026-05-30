@tool
extends EditorScript

func _run() -> void:
	print("--- Generating Car Scene ---")
	
	var car_root = VehicleBody3D.new()
	car_root.name = "Car"
	car_root.mass = 1200.0 # Realistic car mass
	
	# Load the script
	var script = load("res://scripts/Car.gd")
	if script:
		car_root.set_script(script)
	
	# Load the GLTF Model
	var gltf_scene = load("res://assets/models/2022_toyota_team_toyotires_drift_gr86_66.glb") as PackedScene
	if not gltf_scene:
		printerr("Failed to load GR86 GLB!")
		return
		
	var model = gltf_scene.instantiate()
	model.name = "Model"
	car_root.add_child(model)
	model.owner = car_root
	
	# Create a Box collision shape roughly matching a car (Length: 4.5m, Width: 1.8m, Height: 1.3m)
	# And lift it slightly so it doesn't scrape the floor
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(1.8, 1.2, 4.2)
	collision.shape = box
	collision.position = Vector3(0, 0.7, 0)
	car_root.add_child(collision)
	collision.owner = car_root
	
	# Interaction Area (so Spider-Man can press F to enter)
	var interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	var interact_collision = CollisionShape3D.new()
	var interact_box = BoxShape3D.new()
	interact_box.size = Vector3(4.0, 2.0, 5.0) # Larger area around the car
	interact_collision.shape = interact_box
	interact_area.add_child(interact_collision)
	car_root.add_child(interact_area)
	interact_area.owner = car_root
	interact_collision.owner = car_root
	interact_area.position = Vector3(0, 1.0, 0)
	
	# Camera Pivot (where the camera attaches when driving)
	var cam_pivot = Node3D.new()
	cam_pivot.name = "CameraPivot"
	cam_pivot.position = Vector3(0, 2.5, -5.0) # Behind and slightly above
	car_root.add_child(cam_pivot)
	cam_pivot.owner = car_root
	
	# Function to generate a wheel
	var create_wheel = func(w_name: String, pos: Vector3, is_steering: bool, is_traction: bool):
		var wheel = VehicleWheel3D.new()
		wheel.name = w_name
		wheel.position = pos
		wheel.use_as_steering = is_steering
		wheel.use_as_traction = is_traction
		
		# Wheel physics parameters
		wheel.wheel_radius = 0.35
		wheel.suspension_travel = 0.2
		wheel.suspension_stiffness = 40.0
		wheel.wheel_friction_slip = 10.5 # Drift settings
		
		car_root.add_child(wheel)
		wheel.owner = car_root
	
	# Add the 4 wheels based on standard car dimensions (approximate)
	# Left = +X, Right = -X in standard Godot, but let's check visually later.
	# We'll put them at X: +/- 0.8, Y: 0.35, Z: +/- 1.4
	create_wheel.call("WheelFrontLeft", Vector3(0.8, 0.35, 1.4), true, false)
	create_wheel.call("WheelFrontRight", Vector3(-0.8, 0.35, 1.4), true, false)
	create_wheel.call("WheelBackLeft", Vector3(0.8, 0.35, -1.4), false, true) # RWD drift car
	create_wheel.call("WheelBackRight", Vector3(-0.8, 0.35, -1.4), false, true)
	
	# Save the scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(car_root)
	var err = ResourceSaver.save(packed_scene, "res://car.tscn")
	if err == OK:
		print("✅ Successfully generated car.tscn!")
	else:
		printerr("❌ Failed to save car.tscn. Error code: ", err)
