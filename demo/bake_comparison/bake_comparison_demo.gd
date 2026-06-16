extends Node3D

@onready var info_label: Label = $UI/VBox/InfoLabel
@onready var fps_label: Label = $UI/VBox/FPSLabel
@onready var mode_button: Button = $UI/VBox/ModeButton
@onready var object_count_label: Label = $UI/VBox/ObjectCountLabel
@onready var camera: Camera3D = $Camera3D

@export var baked_marble_path: String = "res://demo/bake_comparison/textures/heavy_marble_albedo.png"
@export var baked_lava_path: String = "res://demo/bake_comparison/textures/heavy_lava_albedo.png"
@export var marble_shader_path: String = "res://shaders/heavy_marble_spatial.gdshader"
@export var lava_shader_path: String = "res://shaders/heavy_lava_spatial.gdshader"

var _use_baked: bool = true
var _objects: Array[MeshInstance3D] = []
var _marble_shader: Shader
var _lava_shader: Shader
var _baked_marble_tex: Texture2D
var _baked_lava_tex: Texture2D
var _avg_frame_ms: float = 0.0

var _orbit_angle: float = 0.3
var _orbit_height: float = 4.0
var _orbit_distance: float = 12.0
var _is_orbiting: bool = false
var _orbit_start: Vector2 = Vector2.ZERO
var _orbit_angle_start: float = 0.0
var _orbit_height_start: float = 0.0

var _marble_objects: Array[MeshInstance3D] = []
var _lava_objects: Array[MeshInstance3D] = []

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_marble_shader = load(marble_shader_path)
	_lava_shader = load(lava_shader_path)

	if FileAccess.file_exists(baked_marble_path):
		_baked_marble_tex = load(baked_marble_path)
	if FileAccess.file_exists(baked_lava_path):
		_baked_lava_tex = load(baked_lava_path)

	mode_button.pressed.connect(_toggle_mode)

	_build_hall()
	_apply_materials()
	_update_ui()
	_update_camera()

func _process(delta: float) -> void:
	_avg_frame_ms = lerpf(_avg_frame_ms, delta * 1000.0, 0.1)
	fps_label.text = "FPS: %d  |  %.1f ms" % [Engine.get_frames_per_second(), _avg_frame_ms]

# =======================================================================
#  Построение сцены
# =======================================================================
func _build_hall() -> void:
	var hall_length: float = 20.0
	var hall_width: float = 10.0
	var column_radius: float = 0.4
	var column_height: float = 3.5
	var column_count: int = 6
	var column_spacing: float = hall_length / float(column_count + 1)

	# Потолок прилегает к верху колонн: капитель на column_height + 0.125, толщина 0.25
	# Значит верх капители = column_height + 0.25
	# Потолок (толщина 0.3) ставим так, чтобы его низ = column_height + 0.25
	var ceiling_y: float = column_height + 0.25 + 0.15  # центр потолка
	var wall_height: float = ceiling_y + 0.15  # верх потолка = верх стен

	# --- Пол ---
	_add_marble(_create_box(Vector3(hall_width, 0.3, hall_length)), Vector3(0, -0.15, 0))

	# --- Стены ---
	_add_marble(_create_box(Vector3(0.4, wall_height, hall_length)), Vector3(-hall_width / 2.0, wall_height / 2.0, 0))
	_add_marble(_create_box(Vector3(0.4, wall_height, hall_length)), Vector3(hall_width / 2.0, wall_height / 2.0, 0))
	_add_marble(_create_box(Vector3(hall_width, wall_height, 0.4)), Vector3(0, wall_height / 2.0, -hall_length / 2.0))

	# --- Потолок ---
	_add_marble(_create_box(Vector3(hall_width, 0.3, hall_length)), Vector3(0, ceiling_y, 0))

	# --- Колонны ---
	for side in [-1.0, 1.0]:
		for i in range(column_count):
			var z_pos: float = -hall_length / 2.0 + column_spacing * float(i + 1)
			var x_pos: float = side * (hall_width / 2.0 - 1.2)

			var col_mesh := CylinderMesh.new()
			col_mesh.top_radius = column_radius
			col_mesh.bottom_radius = column_radius
			col_mesh.height = column_height
			col_mesh.radial_segments = 16
			_add_marble(_create_mi(col_mesh), Vector3(x_pos, column_height / 2.0, z_pos))

			# База
			_add_marble(_create_box(Vector3(column_radius * 2.5, 0.3, column_radius * 2.5)), Vector3(x_pos, 0.15, z_pos))

			# Капитель
			_add_marble(_create_box(Vector3(column_radius * 2.5, 0.25, column_radius * 2.5)), Vector3(x_pos, column_height + 0.125, z_pos))

	# --- Ступени ---
	for step_i in range(3):
		var step_depth: float = hall_width - float(step_i) * 0.6
		_add_marble(
			_create_box(Vector3(step_depth, 0.2, 1.0)),
			Vector3(0, 0.1 + float(step_i) * 0.2, hall_length / 2.0 - 0.5 - float(step_i) * 0.8)
		)

	# --- Постамент ---
	_add_marble(_create_box(Vector3(2.0, 0.6, 2.0)), Vector3(0, 0.3, -2.0))
	var pedestal_sphere := SphereMesh.new()
	pedestal_sphere.radius = 0.6
	pedestal_sphere.height = 1.2
	pedestal_sphere.radial_segments = 24
	pedestal_sphere.rings = 16
	_add_marble(_create_mi(pedestal_sphere), Vector3(0, 1.2, -2.0))

	# --- Карнизы ---
	for side in [-1.0, 1.0]:
		_add_marble(
			_create_box(Vector3(0.6, 0.2, hall_length)),
			Vector3(side * (hall_width / 2.0 - 0.1), wall_height - 0.5, 0)
		)

	# --- Лавовый канал (из квадратных секций вместо одного длинного прямоугольника) ---
	var channel_width: float = 1.5
	var channel_length: float = hall_length * 0.7
	var segment_size: float = channel_width  # квадратные секции
	var segment_count: int = int(channel_length / segment_size)
	var channel_start_z: float = 1.5 - channel_length / 2.0

	for i in range(segment_count):
		var seg_z: float = channel_start_z + float(i) * segment_size + segment_size / 2.0
		_add_lava(
			_create_box(Vector3(channel_width, 0.05, segment_size)),
			Vector3(0, 0.03, seg_z)
		)

	# --- Лавовые бассейны по бокам ---
	for side in [-1.0, 1.0]:
		# Бассейн из квадратных секций
		var pool_width: float = 1.2
		var pool_length: float = 3.0
		var pool_seg_size: float = pool_width
		var pool_seg_count: int = int(ceil(pool_length / pool_seg_size))
		var pool_start_z: float = 4.0 - pool_length / 2.0

		for i in range(pool_seg_count):
			var seg_len: float = minf(pool_seg_size, pool_length - float(i) * pool_seg_size)
			var seg_z: float = pool_start_z + float(i) * pool_seg_size + seg_len / 2.0
			_add_lava(
				_create_box(Vector3(pool_width, 0.05, seg_len)),
				Vector3(side * 3.0, 0.03, seg_z)
			)

		# Бортики
		_add_marble(_create_box(Vector3(1.4, 0.25, 0.15)), Vector3(side * 3.0, 0.125, 4.0 + 1.5))
		_add_marble(_create_box(Vector3(1.4, 0.25, 0.15)), Vector3(side * 3.0, 0.125, 4.0 - 1.5))
		_add_marble(_create_box(Vector3(0.15, 0.25, 3.0)), Vector3(side * (3.0 + 0.7), 0.125, 4.0))
		_add_marble(_create_box(Vector3(0.15, 0.25, 3.0)), Vector3(side * (3.0 - 0.7), 0.125, 4.0))

	# --- Лавовые потёки на задней стене ---
	var back_wall_z: float = -hall_length / 2.0 + 0.25
	var streak_positions: Array[float] = [-3.0, -1.0, 1.0, 3.0]
	for x_pos in streak_positions:
		_add_lava(
			_create_box(Vector3(0.6, 2.5, 0.08)),
			Vector3(x_pos, wall_height - 1.25, back_wall_z)
		)
		_add_lava(
			_create_box(Vector3(0.35, 1.5, 0.08)),
			Vector3(x_pos + 0.05, wall_height - 3.25, back_wall_z)
		)
		_add_lava(
			_create_box(Vector3(0.8, 0.04, 0.6)),
			Vector3(x_pos, 0.02, back_wall_z + 0.3)
		)

		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.35, 0.05)
		glow.light_energy = 0.6
		glow.omni_range = 3.0
		glow.omni_attenuation = 1.8
		glow.position = Vector3(x_pos, wall_height / 2.0, back_wall_z + 0.5)
		add_child(glow)

	object_count_label.text = "Объектов: %d (мрамор: %d, лава: %d)" % [
		_objects.size(), _marble_objects.size(), _lava_objects.size()
	]

# =======================================================================
#  Вспомогательные функции
# =======================================================================
func _create_box(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

func _create_mi(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

func _add_marble(mi: MeshInstance3D, pos: Vector3) -> void:
	mi.position = pos
	add_child(mi)
	_objects.append(mi)
	_marble_objects.append(mi)

func _add_lava(mi: MeshInstance3D, pos: Vector3) -> void:
	mi.position = pos
	add_child(mi)
	_objects.append(mi)
	_lava_objects.append(mi)

# =======================================================================
#  Переключение режимов
# =======================================================================
func _toggle_mode() -> void:
	_use_baked = not _use_baked
	_apply_materials()
	_update_ui()

func _apply_materials() -> void:
	if _use_baked:
		var marble_mat := StandardMaterial3D.new()
		marble_mat.albedo_texture = _baked_marble_tex
		if marble_mat.albedo_texture == null:
			marble_mat.albedo_color = Color(0.9, 0.88, 0.82)

		var lava_mat := StandardMaterial3D.new()
		lava_mat.albedo_texture = _baked_lava_tex
		if lava_mat.albedo_texture == null:
			lava_mat.albedo_color = Color(0.8, 0.2, 0.0)
		lava_mat.emission_enabled = true
		lava_mat.emission = Color(1.0, 0.4, 0.0)
		lava_mat.emission_energy_multiplier = 0.5

		for mi in _marble_objects:
			mi.material_override = marble_mat
		for mi in _lava_objects:
			mi.material_override = lava_mat
	else:
		var marble_shader_mat := ShaderMaterial.new()
		marble_shader_mat.shader = _marble_shader

		var lava_shader_mat := ShaderMaterial.new()
		lava_shader_mat.shader = _lava_shader

		for mi in _marble_objects:
			mi.material_override = marble_shader_mat
		for mi in _lava_objects:
			mi.material_override = lava_shader_mat

func _update_ui() -> void:
	if _use_baked:
		mode_button.text = "Режим: запечённые текстуры"
		info_label.text = "PNG-текстуры из Procedural Baker.\nGPU выполняет только выборку текстуры.\nVSync отключён для честного сравнения."
	else:
		mode_button.text = "Режим: шейдеры реального времени"
		info_label.text = "Каждый пиксель каждого объекта вычисляется\nшейдером каждый кадр: domain warping,\nFBM 12-14 октав, Voronoi, турбулентность."

# =======================================================================
#  Камера
# =======================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_orbit_distance = max(3.0, _orbit_distance - 0.8)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_orbit_distance = min(25.0, _orbit_distance + 0.8)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_orbiting = true
				_orbit_start = event.global_position
				_orbit_angle_start = _orbit_angle
				_orbit_height_start = _orbit_height
			else:
				_is_orbiting = false

	if event is InputEventMouseMotion and _is_orbiting:
		var delta: Vector2 = event.global_position - _orbit_start
		_orbit_angle = _orbit_angle_start + delta.x * 0.01
		_orbit_height = clampf(_orbit_height_start - delta.y * 0.05, 1.0, 15.0)
		_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(
		cos(_orbit_angle) * _orbit_distance,
		_orbit_height,
		sin(_orbit_angle) * _orbit_distance
	)
	camera.look_at(Vector3(0, 1.5, 0))