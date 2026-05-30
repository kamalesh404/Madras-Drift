@tool
extends EditorScript


func _run() -> void:
	# 1. Create root VehicleBody3D
	var car_root := VehicleBody3D.new()
	car_root.name = "Bike"
	car_root.mass = 220.0

	# 3. Load and assign the Bike script
	var bike_script: Script = load("res://scripts/Bike.gd")
	car_root.set_script(bike_script)

	# 4. Load GLTF model, instantiate, and add as child
	var model_scene: PackedScene = load("res://assets/models/suzuki_gsx_750_bike.glb")
	var model: Node3D = model_scene.instantiate()
	model.name = "Model"
	car_root.add_child(model)
	model.owner = car_root

	# Removed recursive owner setting to prevent GLTF unpacking errors in Godot 4

	# 5. CollisionShape3D with BoxShape3D
	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.0, 2.2)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.6, 0.0)
	car_root.add_child(col_shape)
	col_shape.owner = car_root

	# 6. InteractArea (Area3D) with CollisionShape3D child
	var interact_area := Area3D.new()
	interact_area.name = "InteractArea"
	car_root.add_child(interact_area)
	interact_area.owner = car_root

	var interact_col := CollisionShape3D.new()
	interact_col.name = "CollisionShape3D"
	var interact_box := BoxShape3D.new()
	interact_box.size = Vector3(3.0, 2.0, 3.5)
	interact_col.shape = interact_box
	interact_area.add_child(interact_col)
	interact_col.owner = car_root

	# 7. CameraPivot (Node3D)
	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 2.0, -4.0)
	car_root.add_child(camera_pivot)
	camera_pivot.owner = car_root

	# 8. VehicleWheel3D nodes
	var wheel_front := VehicleWheel3D.new()
	wheel_front.name = "WheelFront"
	wheel_front.position = Vector3(0.0, 0.3, 1.0)
	wheel_front.use_as_steering = true
	wheel_front.use_as_traction = false
	wheel_front.wheel_radius = 0.3
	wheel_front.suspension_travel = 0.15
	wheel_front.suspension_stiffness = 50.0
	wheel_front.wheel_friction_slip = 8.0
	car_root.add_child(wheel_front)
	wheel_front.owner = car_root

	var wheel_back := VehicleWheel3D.new()
	wheel_back.name = "WheelBack"
	wheel_back.position = Vector3(0.0, 0.3, -0.8)
	wheel_back.use_as_steering = false
	wheel_back.use_as_traction = true
	wheel_back.wheel_radius = 0.3
	wheel_back.suspension_travel = 0.15
	wheel_back.suspension_stiffness = 50.0
	wheel_back.wheel_friction_slip = 8.0
	car_root.add_child(wheel_back)
	wheel_back.owner = car_root

	# 9. Pack and save the scene
	var packed_scene := PackedScene.new()
	var result := packed_scene.pack(car_root)
	if result != OK:
		printerr("Failed to pack bike scene: ", result)
		return

	var save_result := ResourceSaver.save(packed_scene, "res://bike.tscn")
	if save_result != OK:
		printerr("Failed to save bike.tscn: ", save_result)
		return

	# 10. Print success message
	print("bike.tscn generated successfully!")
