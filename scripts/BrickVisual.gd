extends RefCounted
const Catalog = preload("res://scripts/BrickCatalog.gd")
const Logic = preload("res://scripts/BrickLogic.gd")

static func create_part(p: Dictionary, ghost: bool = false) -> Node3D:
	var root := Node3D.new()
	var size := Catalog.size_for(int(p["kind"]),int(p["rotation"]))
	var color := Catalog.color_for(int(p["color"]))
	if ghost:
		color.a = 0.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.66
	if ghost:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(size.x)*Logic.UNIT-0.025, Logic.HEIGHT-0.025, float(size.y)*Logic.UNIT-0.025)
	body.mesh = mesh
	body.material_override = mat
	body.position = Vector3(float(size.x)*Logic.UNIT*0.5,Logic.HEIGHT*0.5,float(size.y)*Logic.UNIT*0.5)
	root.add_child(body)
	var stud_mesh := CylinderMesh.new()
	stud_mesh.top_radius = 0.165
	stud_mesh.bottom_radius = 0.165
	stud_mesh.height = 0.09
	stud_mesh.radial_segments = 12
	for xx in range(size.x):
		for zz in range(size.y):
			var stud := MeshInstance3D.new()
			stud.mesh = stud_mesh
			stud.material_override = mat
			stud.position = Vector3((xx+0.5)*Logic.UNIT,Logic.HEIGHT+0.035,(zz+0.5)*Logic.UNIT)
			root.add_child(stud)
	root.position = Logic.world_position(p)
	return root
