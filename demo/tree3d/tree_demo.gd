extends Node3D

@onready var generator: Node3D = $TreeGenerator
@onready var generate_btn: Button = $UI/VBox/GenerateBtn
@onready var info_label: Label = $UI/VBox/Info
@onready var camera: Camera3D = $Camera3D

var _orbit_angle: float = 0.0
var _orbit_height: float = 5.0
var _orbit_distance: float = 12.0
var _is_orbiting: bool = false
var _orbit_start: Vector2 = Vector2.ZERO
var _orbit_angle_start: float = 0.0
var _orbit_height_start: float = 0.0

func _ready() -> void:
	generate_btn.pressed.connect(_on_generate)
	_update_camera()

func _on_generate() -> void:
	if generator.path3d_scene_path.is_empty():
		info_label.text = "Укажите path3d_scene_path в Inspector!"
		return

	# Сбрасываем кэшированные материалы
	generator._bark_material = null
	generator._leaf_material = null
	generator.generate()
	info_label.text = "Дерево сгенерировано!"

func _input(event: InputEvent) -> void:
	# Зум колёсиком
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_orbit_distance = max(2.0, _orbit_distance - 1.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_orbit_distance = min(50.0, _orbit_distance + 1.0)
			_update_camera()
		# Орбитальное вращение средней/левой кнопкой
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
		_orbit_height = clampf(_orbit_height_start - delta.y * 0.05, 1.0, 20.0)
		_update_camera()

func _update_camera() -> void:
	var x: float = cos(_orbit_angle) * _orbit_distance
	var z: float = sin(_orbit_angle) * _orbit_distance
	camera.position = Vector3(x, _orbit_height, z)
	camera.look_at(Vector3(0, _orbit_height * 0.4, 0))