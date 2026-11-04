class_name MachineMesh
extends RefCounted
## Piezas de geometría reutilizables para las máquinas físicas.
## Todo primitivas: no hay mallas importadas.
## Dentro de un lote (`begin_batch`) las piezas estáticas se fusionan por material.

static var _batches: Dictionary = {}


static func begin_batch(target: Node3D) -> void:
	_batches[target.get_instance_id()] = MachineBatch.new()


static func end_batch(target: Node3D) -> void:
	var key := target.get_instance_id()
	if not _batches.has(key):
		return
	var batch: MachineBatch = _batches[key]
	_batches.erase(key)
	batch.commit(target, String(target.name) + "Batch")

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material,
		rot := Vector3.ZERO, node_name := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, rot, material, node_name)


static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		material: Material, rot := Vector3(PI * 0.5, 0.0, 0.0), segments := 20,
		top_radius := -1.0, node_name := "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	return _instance(parent, mesh, pos, rot, material, node_name)


static func sphere(parent: Node3D, pos: Vector3, radius: float, material: Material,
		node_name := "") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _instance(parent, mesh, pos, Vector3.ZERO, material, node_name)


static func quad(parent: Node3D, pos: Vector3, size: Vector2, material: Material,
		rot := Vector3.ZERO, node_name := "") -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, rot, material, node_name)


static func label(parent: Node3D, text: String, pos: Vector3, pixel_size: float,
		color: Color, font_size := 24, rot := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.position = pos
	label.rotation = rot
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	parent.add_child(label)
	return label


## Tornillos en una sola instancia: un draw call para todos.
static func bolts(parent: Node3D, points: Array[Vector3], material: Material,
		radius := 0.011, depth := 0.008) -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = depth
	mesh.radial_segments = 8
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = points.size()
	var basis := Basis(Vector3.RIGHT, PI * 0.5)
	for i in points.size():
		multimesh.set_instance_transform(i, Transform3D(basis, points[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Serie de listones iguales (rejillas) con transformaciones ya calculadas.
static func slats(parent: Node3D, transforms: Array[Transform3D], size: Vector3,
		material: Material, node_name := "") -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Cable: tubo continuo por una lista de puntos. Un solo draw call.
static func tube(parent: Node3D, points: Array[Vector3], radius: float,
		material: Material, sides := 8, node_name := "") -> MeshInstance3D:
	var mesh := tube_mesh(points, radius, sides)
	if mesh == null:
		return null
	return _instance(parent, mesh, Vector3.ZERO, Vector3.ZERO, material, node_name)


static func tube_mesh(points: Array[Vector3], radius: float, sides := 8) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var from := points[i]
		var to := points[i + 1]
		var basis := _tube_basis((to - from).normalized())
		for side in sides:
			var angle_a := TAU * float(side) / float(sides)
			var angle_b := TAU * float(side + 1) / float(sides)
			var normal_a := basis * Vector3(cos(angle_a), sin(angle_a), 0.0)
			var normal_b := basis * Vector3(cos(angle_b), sin(angle_b), 0.0)
			var a0 := from + normal_a * radius
			var a1 := from + normal_b * radius
			var b0 := to + normal_a * radius
			var b1 := to + normal_b * radius
			_add_vertex(tool, a0, normal_a, Vector2(0.0, float(side) / float(sides)))
			_add_vertex(tool, a1, normal_b, Vector2(0.0, float(side + 1) / float(sides)))
			_add_vertex(tool, b1, normal_b, Vector2(1.0, float(side + 1) / float(sides)))
			_add_vertex(tool, a0, normal_a, Vector2(0.0, float(side) / float(sides)))
			_add_vertex(tool, b1, normal_b, Vector2(1.0, float(side + 1) / float(sides)))
			_add_vertex(tool, b0, normal_a, Vector2(1.0, float(side) / float(sides)))
	return tool.commit()


static func _add_vertex(tool: SurfaceTool, vertex: Vector3, normal: Vector3,
		uv: Vector2) -> void:
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.add_vertex(vertex)


static func _tube_basis(direction: Vector3) -> Basis:
	var z := direction.normalized()
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


static func _instance(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3,
		material: Material, node_name: String) -> MeshInstance3D:
	var batched: Variant = _batches.get(parent.get_instance_id())
	if batched is MachineBatch:
		(batched as MachineBatch).add_mesh(mesh,
			Transform3D(Basis.from_euler(rot), pos), material)
		return null
	var instance := MeshInstance3D.new()
	if node_name != "":
		instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance
