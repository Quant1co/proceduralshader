@tool
extends Node3D

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

	_bark_material = null
	_leaf_material = null

	# Собираем все ветки с их точками и глубиной
	var all_branches: Array = []
	_collect_branches(path_root, 0, all_branches)

	# Строим меши
	for branch_data in all_branches:
		var points: Array[Vector3] = branch_data["points"]
		var depth: int = branch_data["depth"]
		var has_children: bool = branch_data["has_children"]

		if points.size() < 2:
			continue

		var start_r: float = trunk_radius * pow(radius_decay, depth)
		start_r = max(start_r, min_radius)
		var end_r: float
		if has_children:
			end_r = max(start_r * radius_decay, min_radius)
		else:
			end_r = min_radius

		var mesh: ArrayMesh = _create_tube_mesh(points, start_r, end_r)
		if mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _get_bark_material()
			add_child(mi)

		if not has_children and leaf_enabled:
			_create_leaf(points[-1])

	path_root.queue_free()
	_adjust_to_ground()
	print("[Tree3D] Дерево сгенерировано: %d веток" % all_branches.size())

func _collect_branches(node: Node, depth: int, result: Array) -> void:
	if node is Path3D:
		var curve: Curve3D = node.curve
		if curve and curve.point_count >= 2:
			var points: Array[Vector3] = []
			var total_len: float = curve.get_baked_length()
			if total_len >= 0.01:
				var samples: int = max(int(total_len * 5), 4)
				for i in range(samples + 1):
					var t: float = float(i) / float(samples)
					points.append(curve.sample_baked(t * total_len))

			var has_children: bool = false
			for child in node.get_children():
				if child is Path3D:
					has_children = true
					break

			if points.size() >= 2:
				result.append({
					"points": points,
					"depth": depth,
					"has_children": has_children
				})

		for child in node.get_children():
			_collect_branches(child, depth + 1, result)
	else:
		for child in node.get_children():
			_collect_branches(child, depth, result)

func _adjust_to_ground() -> void:
	var min_y: float = INF
	for child in get_children():
		if child is MeshInstance3D:
			var aabb: AABB = child.mesh.get_aabb()
			min_y = min(min_y, child.position.y + aabb.position.y)
	if min_y != INF and abs(min_y) > 0.01:
		for child in get_children():
			if child is MeshInstance3D:
				child.position.y -= min_y

func _create_tube_mesh(points: Array[Vector3], start_radius: float, end_radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array = []
	var prev_right: Vector3 = Vector3.ZERO
	var prev_up: Vector3 = Vector3.ZERO

	for i in range(points.size()):
		# Направление
		var forward: Vector3
		if i < points.size() - 1:
			forward = (points[i + 1] - points[i]).normalized()
		else:
			forward = (points[i] - points[i - 1]).normalized()
		if forward.length() < 0.001:
			forward = Vector3.UP

		# Радиус — плавная интерполяция
		var t: float = float(i) / float(points.size() - 1)
		var r: float = lerp(start_radius, end_radius, t)

		# Стабильные оси (минимальное вращение между кольцами)
		var right: Vector3
		var up: Vector3
		if i == 0:
			var ref: Vector3 = Vector3.UP if abs(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			right = forward.cross(ref).normalized()
			up = right.cross(forward).normalized()
		else:
			# Проецируем предыдущий right на плоскость, перпендикулярную forward
			right = (prev_right - forward * prev_right.dot(forward)).normalized()
			if right.length() < 0.001:
				var ref: Vector3 = Vector3.UP if abs(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
				right = forward.cross(ref).normalized()
			up = right.cross(forward).normalized()

		prev_right = right
		prev_up = up

		# Кольцо
		var ring: Array[Vector3] = []
		for j in range(circle_segments):
			var angle: float = float(j) / float(circle_segments) * TAU
			ring.append(points[i] + right * cos(angle) * r + up * sin(angle) * r)
		rings.append(ring)

	# Треугольники
	for i in range(rings.size() - 1):
		var ra: Array = rings[i]
		var rb: Array = rings[i + 1]
		for j in range(circle_segments):
			var jn: int = (j + 1) % circle_segments
			st.add_vertex(ra[j])
			st.add_vertex(ra[jn])
			st.add_vertex(rb[j])
			st.add_vertex(ra[jn])
			st.add_vertex(rb[jn])
			st.add_vertex(rb[j])

	st.generate_normals()
	return st.commit()

func _create_leaf(position: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = leaf_size
	sphere.height = leaf_size * 1.5
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere
	mi.material_override = _get_leaf_material()
	mi.position = position
	add_child(mi)

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