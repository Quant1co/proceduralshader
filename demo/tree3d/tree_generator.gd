@tool
extends Node3D

## Генератор 3D-дерева по экспортированной Path3D сцене L-системы
## Загружает .tscn с иерархией Path3D и строит меши вдоль кривых

@export_file("*.tscn") var path3d_scene_path: String = ""
@export var trunk_radius: float = 0.15
@export var radius_decay: float = 0.7
@export var min_radius: float = 0.02
@export var leaf_size: float = 0.3
@export var leaf_enabled: bool = true
@export var trunk_color: Color = Color(0.45, 0.3, 0.15)
@export var leaf_color: Color = Color(0.2, 0.7, 0.15)
@export var circle_segments: int = 8
@export var auto_generate: bool = false

func _ready() -> void:
	if auto_generate and not path3d_scene_path.is_empty():
		generate()

func generate() -> void:
	for child in get_children():
		child.queue_free()

	if path3d_scene_path.is_empty():
		push_error("[Tree3D] Не указан путь к Path3D сцене")
		return

	var scene: PackedScene = load(path3d_scene_path)
	if scene == null:
		push_error("[Tree3D] Не удалось загрузить: " + path3d_scene_path)
		return

	var path_root: Node = scene.instantiate()
	if path_root == null:
		push_error("[Tree3D] Не удалось инстанцировать сцену")
		return

	# Сбрасываем кэшированные материалы
	_bark_material = null
	_leaf_material = null

	_build_tree_recursive(path_root, trunk_radius)

	path_root.queue_free()

	_adjust_to_ground()

	print("[Tree3D] Дерево сгенерировано")

func _adjust_to_ground() -> void:
	var min_y: float = INF
	for child in get_children():
		if child is MeshInstance3D:
			var aabb: AABB = child.mesh.get_aabb()
			var world_min_y: float = child.position.y + aabb.position.y
			min_y = min(min_y, world_min_y)
	if min_y != INF and abs(min_y) > 0.01:
		for child in get_children():
			if child is MeshInstance3D:
				child.position.y -= min_y

func _build_tree_recursive(node: Node, current_radius: float) -> void:
	if node is Path3D:
		var path3d: Path3D = node
		var curve: Curve3D = path3d.curve
		if curve and curve.point_count >= 2:
			var child_count: int = 0
			for child in node.get_children():
				if child is Path3D:
					child_count += 1

			var end_radius: float
			if child_count > 0:
				end_radius = max(current_radius * radius_decay, min_radius)
			else:
				end_radius = min_radius

			_create_branch(curve, current_radius, end_radius)

			if child_count == 0 and leaf_enabled:
				var tip: Vector3 = curve.get_point_position(curve.point_count - 1)
				_create_leaf(tip)

		var child_radius: float = max(current_radius * radius_decay, min_radius)
		for child in node.get_children():
			_build_tree_recursive(child, child_radius)
	else:
		for child in node.get_children():
			_build_tree_recursive(child, current_radius)

func _create_branch(curve: Curve3D, start_radius: float, end_radius: float) -> void:
	var total_length: float = curve.get_baked_length()
	if total_length < 0.01:
		return

	var sample_count: int = max(int(total_length * 5), 4)
	var points: Array[Vector3] = []
	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var offset: float = t * total_length
		points.append(curve.sample_baked(offset))

	if points.size() < 2:
		return

	var mesh: ArrayMesh = _create_tube_mesh(points, start_radius, end_radius)
	if mesh == null:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _get_bark_material()
	add_child(mesh_instance)

func _create_tube_mesh(points: Array[Vector3], start_radius: float, end_radius: float) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array = []

	for i in range(points.size()):
		var forward: Vector3
		if i < points.size() - 1:
			forward = (points[i + 1] - points[i]).normalized()
		else:
			forward = (points[i] - points[i - 1]).normalized()

		if forward.length() < 0.001:
			forward = Vector3.UP

		var t: float = float(i) / float(points.size() - 1)
		var r: float = lerp(start_radius, end_radius, t)

		var up: Vector3 = Vector3.UP
		if abs(forward.dot(up)) > 0.99:
			up = Vector3.RIGHT
		var right: Vector3 = forward.cross(up).normalized()
		up = right.cross(forward).normalized()

		var ring: Array[Vector3] = []
		for j in range(circle_segments):
			var angle: float = float(j) / float(circle_segments) * TAU
			var point: Vector3 = points[i] + right * cos(angle) * r + up * sin(angle) * r
			ring.append(point)
		rings.append(ring)

	for i in range(rings.size() - 1):
		var ring_a: Array = rings[i]
		var ring_b: Array = rings[i + 1]
		for j in range(circle_segments):
			var j_next: int = (j + 1) % circle_segments

			var a0: Vector3 = ring_a[j]
			var a1: Vector3 = ring_a[j_next]
			var b0: Vector3 = ring_b[j]
			var b1: Vector3 = ring_b[j_next]

			var normal1: Vector3 = (b0 - a0).cross(a1 - a0).normalized()
			var normal2: Vector3 = (b1 - a1).cross(b0 - a1).normalized()

			surface_tool.set_normal(normal1)
			surface_tool.add_vertex(a0)
			surface_tool.add_vertex(a1)
			surface_tool.add_vertex(b0)

			surface_tool.set_normal(normal2)
			surface_tool.add_vertex(a1)
			surface_tool.add_vertex(b1)
			surface_tool.add_vertex(b0)

	surface_tool.generate_normals()
	return surface_tool.commit()

func _create_leaf(position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = leaf_size
	sphere.height = leaf_size * 1.5
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _get_leaf_material()
	mesh_instance.position = position
	add_child(mesh_instance)

var _bark_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D

func _get_bark_material() -> StandardMaterial3D:
	if _bark_material == null:
		_bark_material = StandardMaterial3D.new()
		_bark_material.albedo_color = trunk_color
		_bark_material.roughness = 0.9
	return _bark_material

func _get_leaf_material() -> StandardMaterial3D:
	if _leaf_material == null:
		_leaf_material = StandardMaterial3D.new()
		_leaf_material.albedo_color = leaf_color
		_leaf_material.roughness = 0.7
		_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_leaf_material.albedo_color.a = 0.85
	return _leaf_material