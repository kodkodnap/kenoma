class_name MachineBatch
extends RefCounted
## Acumula primitivas estáticas y las fusiona en una malla por material.
## Las piezas móviles (perillas, agujas) no pasan por aquí: conservan su nodo.

var _entries: Array[Dictionary] = []


func box(pos: Vector3, size: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add_mesh(mesh, Transform3D(Basis.from_euler(rot), pos), material)


func cylinder(pos: Vector3, radius: float, height: float, material: Material,
		rot := Vector3(PI * 0.5, 0.0, 0.0), segments := 20, top_radius := -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	add_mesh(mesh, Transform3D(Basis.from_euler(rot), pos), material)


func sphere(pos: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	add_mesh(mesh, Transform3D(Basis.IDENTITY, pos), material)


func quad(pos: Vector3, size: Vector2, material: Material, rot := Vector3.ZERO) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	add_mesh(mesh, Transform3D(Basis.from_euler(rot), pos), material)


func tube(points: Array[Vector3], radius: float, material: Material, sides := 8) -> void:
	var mesh := MachineMesh.tube_mesh(points, radius, sides)
	if mesh != null:
		add_mesh(mesh, Transform3D.IDENTITY, material)


func add_mesh(mesh: Mesh, transform: Transform3D, material: Material) -> void:
	_entries.append({"mesh": mesh, "transform": transform, "material": material})


## Fusiona todo y añade un MeshInstance3D por material al padre.
func commit(parent: Node3D, node_name := "Static") -> void:
	var tools: Dictionary = {}
	var materials: Dictionary = {}
	for entry in _entries:
		var material: Material = entry["material"]
		if material == null:
			continue
		var key := material.get_instance_id()
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
			materials[key] = material
		var tool: SurfaceTool = tools[key]
		tool.append_from(entry["mesh"] as Mesh, 0, entry["transform"] as Transform3D)
	_entries.clear()
	var index := 0
	for key in tools:
		var tool: SurfaceTool = tools[key]
		var mesh := tool.commit()
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "%s%d" % [node_name, index]
		instance.mesh = mesh
		instance.material_override = materials[key] as Material
		parent.add_child(instance)
		index += 1
