extends Node3D

# ── Spider-Man Skin Applier ──
# Automatically applies the original textures to the Mixamo-rigged Spider-Man model.
# Attach this script to the spy_idle node (or its parent) inside the player scene.

const TEXTURE_PATH = "res://assets/models/spider-man_peter_parker_the_photographer/textures/"

# Mapping: mesh index → { texture, normal (optional), settings }
# Based on the original GLTF material order:
#   mesh 0 (obj1)  → MI_1036510_Equip_02 (Jacket/Hoodie outer)
#   mesh 1 (obj2)  → MI_1036510_Equip_01 (T-shirt / inner clothes)
#   mesh 2 (obj3)  → MI_1036510_Equip_03 (Pants / shoes)
#   mesh 3 (obj4)  → MI_1036510_Eyes_02  (Left eye)
#   mesh 4 (obj5)  → MI_1036510_Hair_02  (Short hair strands) [BLEND]
#   mesh 5 (obj6)  → MI_1036510_Hair_01  (Main hair)
#   mesh 6 (obj7)  → MI_1036510_Head     (Head / face)
#   mesh 7 (obj8)  → MI_1036510_Equip_04 (Backpack/sunglasses – solid black, no texture)
#   mesh 8 (obj9)  → MI_1036510_Eyes_03  (Right eye iris) [BLEND]
#   mesh 9 (obj10) → MI_Punches_2_005    (Invisible/particle – fully transparent)

var SKIN_MAP = {
	"obj1": {
		"color": "MI_1036510_Equip_02_baseColor.png",
		"normal": "MI_1036510_Equip_02_normal.png"
	},
	"obj2": {
		"color": "MI_1036510_Equip_01_baseColor.png",
		"normal": "MI_1036510_Equip_01_normal.png"
	},
	"obj3": {
		"color": "MI_1036510_Equip_03_baseColor.png",
		"normal": "MI_1036510_Equip_03_normal.png"
	},
	"obj4": {
		"color": "MI_1036510_Eyes_02_baseColor.png"
	},
	"obj5": {
		"color": "MI_1036510_Hair_02_baseColor.png",
		"transparent": true
	},
	"obj6": {
		"color": "MI_1036510_Hair_01_baseColor.png"
	},
	"obj7": {
		"color": "MI_1036510_Head_baseColor.png",
		"normal": "MI_1036510_Head_normal.png"
	},
	"obj8": {
		"solid_color": Color(0, 0, 0, 1)  # Sunglasses – solid black
	},
	"obj9": {
		"color": "MI_1036510_Eyes_03_baseColor.png",
		"transparent": true
	},
	"obj10": {
		"solid_color": Color(0.8, 0.8, 0.8, 0.0)  # Invisible/particle effect
	}
}

func _ready() -> void:
	# Wait a frame for the scene tree to fully load
	await get_tree().process_frame
	_apply_all_skins()

func _apply_all_skins() -> void:
	for mesh_name in SKIN_MAP:
		var mesh_node = _find_node_by_name(self, mesh_name)
		if not mesh_node:
			print("[SpiderManSkin] Could not find mesh: ", mesh_name)
			continue
		if mesh_node is MeshInstance3D:
			_apply_skin_to_mesh(mesh_node, SKIN_MAP[mesh_name])
			print("[SpiderManSkin] ✅ Applied skin to: ", mesh_name)
		else:
			# Sometimes the mesh is a child
			for child in mesh_node.get_children():
				if child is MeshInstance3D:
					_apply_skin_to_mesh(child, SKIN_MAP[mesh_name])
					print("[SpiderManSkin] ✅ Applied skin to child of: ", mesh_name)
					break

func _apply_skin_to_mesh(mesh_instance: MeshInstance3D, skin_data: Dictionary) -> void:
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Double-sided

	if skin_data.has("solid_color"):
		var c: Color = skin_data["solid_color"]
		mat.albedo_color = c
		if c.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		# Load base color texture
		if skin_data.has("color"):
			var tex_path = TEXTURE_PATH + skin_data["color"]
			if ResourceLoader.exists(tex_path):
				mat.albedo_texture = load(tex_path)

		# Load normal map
		if skin_data.has("normal"):
			var norm_path = TEXTURE_PATH + skin_data["normal"]
			if ResourceLoader.exists(norm_path):
				mat.normal_enabled = true
				mat.normal_texture = load(norm_path)

		# Handle transparency (hair, eyes)
		if skin_data.get("transparent", false):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mat.metallic = 0.0
	mat.roughness = 0.8

	# Apply as material override (overrides the locked imported material)
	mesh_instance.material_override = mat

func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, target_name)
		if result:
			return result
	return null
