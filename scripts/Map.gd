extends Node3D

func _ready() -> void:
	print("[Map] Generating collision for map...")
	var shape_count = 0
	var mesh_instances = _find_all_mesh_instances(self)
	
	for mi in mesh_instances:
		if mi.mesh:
			var shape = mi.mesh.create_trimesh_shape()
			if shape:
				var static_body = StaticBody3D.new()
				var col = CollisionShape3D.new()
				col.shape = shape
				static_body.add_child(col)
				mi.add_child(static_body)
				shape_count += 1
				
	print("[Map] Successfully generated ", shape_count, " collision shapes!")

func _find_all_mesh_instances(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result
