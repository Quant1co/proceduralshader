extends Node2D

@onready var generator: Node2D = $DungeonGenerator
@onready var generate_btn: Button = $UI/VBox/GenerateBtn
@onready var info_label: Label = $UI/VBox/Info
@onready var camera: Camera2D = $Camera2D

var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _camera_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	generate_btn.pressed.connect(_on_generate)

func _on_generate() -> void:
	if generator.graph_json_path.is_empty():
		info_label.text = "Сначала укажите graph_json_path в Inspector!"
		return

	generator.generate()
	info_label.text = "Подземелье сгенерировано!"

	if generator.tilemap:
		var used: Rect2i = generator.tilemap.get_used_rect()
		var center_tile: Vector2 = Vector2(used.position) + Vector2(used.size) / 2.0
		camera.position = center_tile * float(generator.tile_size)

func _input(event: InputEvent) -> void:
	# Зум колёсиком
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom /= 1.1
		# Перетаскивание средней кнопкой
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.global_position
				_camera_start = camera.position
			else:
				_is_panning = false
		# Перетаскивание левой кнопкой тоже
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_panning = true
				_pan_start = event.global_position
				_camera_start = camera.position
			else:
				_is_panning = false

	# Движение мыши при перетаскивании
	if event is InputEventMouseMotion and _is_panning:
		var delta: Vector2 = event.global_position - _pan_start
		camera.position = _camera_start - delta / camera.zoom

	# Стрелки
	if event is InputEventKey and event.pressed:
		var move_speed: float = 50.0 / camera.zoom.x
		match event.keycode:
			KEY_LEFT: camera.position.x -= move_speed
			KEY_RIGHT: camera.position.x += move_speed
			KEY_UP: camera.position.y -= move_speed
			KEY_DOWN: camera.position.y += move_speed