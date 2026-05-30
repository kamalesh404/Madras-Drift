@tool
extends EditorScript

# Generates a new Main.tscn with:
# - Clock Tower map (with runtime collision generation)
# - Proper sun (DirectionalLight3D)
# - Sky + Environment (WorldEnvironment)
# - Player, Car, Bike properly placed

func _run() -> void:
	print("--- Generating Main Scene ---")
	
	# ── Root ──
	var world = Node3D.new()
	world.name = "World"
	
	# ══════════════════════════════════════════════════════════════
	# ── SUN (DirectionalLight3D) ──
	# ══════════════════════════════════════════════════════════════
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)  # Warm sunlight
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	# Rotate to simulate afternoon sun (45 deg down, slight angle)
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.transform.origin = Vector3(0, 20, 0)
	world.add_child(sun)
	sun.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── SKY & ENVIRONMENT (WorldEnvironment) ──
	# ══════════════════════════════════════════════════════════════
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	
	var env = Environment.new()
	
	# Sky
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.15, 0.35, 0.75)       # Deep blue top
	sky_mat.sky_horizon_color = Color(0.55, 0.7, 0.9)     # Light blue horizon
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.1)  # Dark ground
	sky_mat.ground_horizon_color = Color(0.55, 0.5, 0.45) # Brownish horizon
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.15
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	
	# Ambient light from sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	
	# Glow/Bloom for that AAA feel
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	
	# Fog for atmosphere/depth
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.65, 0.75)
	env.fog_density = 0.001
	env.fog_aerial_perspective = 0.3
	
	world_env.environment = env
	world.add_child(world_env)
	world_env.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── FILL LIGHT (secondary softer light from opposite side) ──
	# ══════════════════════════════════════════════════════════════
	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_energy = 0.3
	fill_light.light_color = Color(0.7, 0.8, 1.0)  # Cool blue fill
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-30, -150, 0)
	world.add_child(fill_light)
	fill_light.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── MAP (Clock Tower) ──
	# ══════════════════════════════════════════════════════════════
	var map_scene = load("res://assets/models/new_clock_tower_map_free_fire_max.glb") as PackedScene
	if not map_scene:
		printerr("Failed to load clock tower map!")
		return
	
	var map = map_scene.instantiate()
	map.name = "Map"
	map.scale = Vector3(10.0, 10.0, 10.0) # Scale up the map 10x
	
	# Attach the dynamic runtime collision script!
	map.set_script(load("res://scripts/Map.gd"))
	
	world.add_child(map)
	# NOTE: We ONLY set the map root's owner. We DO NOT recursively set the owner 
	# of its children, nor do we generate collision here. This prevents the "name clash" 
	# load errors when Godot tries to save an unpacked GLB.
	map.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── PLAYER ──
	# ══════════════════════════════════════════════════════════════
	var player_scene = load("res://player.tscn") as PackedScene
	if player_scene:
		var player = player_scene.instantiate()
		player.name = "player"
		player.transform.origin = Vector3(0, 30.0, 0)  # Spawn high to drop onto map
		world.add_child(player)
		player.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── CAR ──
	# ══════════════════════════════════════════════════════════════
	var car_scene = load("res://car.tscn") as PackedScene
	if car_scene:
		var car = car_scene.instantiate()
		car.name = "Car"
		car.transform.origin = Vector3(10, 30.0, 10)  # Spawn high to drop onto map
		world.add_child(car)
		car.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── BIKE ──
	# ══════════════════════════════════════════════════════════════
	var bike_scene = load("res://bike.tscn") as PackedScene
	if bike_scene:
		var bike = bike_scene.instantiate()
		bike.name = "Bike"
		bike.transform.origin = Vector3(-10, 30.0, 10)  # Spawn high to drop onto map
		world.add_child(bike)
		bike.owner = world
	
	# ══════════════════════════════════════════════════════════════
	# ── SAVE ──
	# ══════════════════════════════════════════════════════════════
	var packed = PackedScene.new()
	packed.pack(world)
	var err = ResourceSaver.save(packed, "res://Main.tscn")
	if err == OK:
		print("✅ Main.tscn generated successfully!")
	else:
		printerr("❌ Failed to save Main.tscn. Error: ", err)
