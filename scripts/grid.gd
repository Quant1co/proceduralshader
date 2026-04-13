extends Node2D

const GRID_WIDTH:  int = 50
const GRID_HEIGHT: int = 50
const CELL_SIZE:   int = 12

var grid:       Array = []
var next_grid:  Array = []
var running:    bool  = false
var generation: int   = 0

@onready var start_button:  Button  = $UI/Panel/VBox/StartButton
@onready var reset_button:  Button  = $UI/Panel/VBox/ResetButton
@onready var speed_label:   Label   = $UI/Panel/VBox/SpeedLabel
@onready var speed_slider:  HSlider = $UI/Panel/VBox/SpeedSlider
@onready var gen_label:     Label   = $UI/Panel/VBox/GenLabel
@onready var back_button:   Button  = $UI/Panel/VBox/BackButton

var step_timer: float = 0.0
var step_delay: float = 0.1

func _ready() -> void:
	_init_grid()
	_random_fill(0.3)

	start_button.pressed.connect(_toggle_running)
	reset_button.pressed.connect(_reset)
	speed_slider.value_changed.connect(func(v: float) -> void:
		step_delay = 1.0 / v
		speed_label.text = "Скорость: " + str(int(v))
	)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/BakerScene.tscn"))

func _init_grid() -> void:
	grid      = []
	next_grid = []
	for y in range(GRID_HEIGHT):
		grid.append([])
		next_grid.append([])
		for _x in range(GRID_WIDTH):
			grid[y].append(0)
			next_grid[y].append(0)

func _random_fill(density: float) -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			grid[y][x] = 1 if randf() < density else 0
	queue_redraw()

func _toggle_running() -> void:
	running = !running
	start_button.text = "Пауза" if running else "Старт"

func _reset() -> void:
	running    = false
	generation = 0
	start_button.text = "Старт"
	gen_label.text    = "Поколение: 0"
	_init_grid()
	_random_fill(0.3)
	queue_redraw()

func _process(delta: float) -> void:
	if not running:
		return
	step_timer += delta
	if step_timer >= step_delay:
		step_timer = 0.0
		_step()

func _step() -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var neighbors: int = _count_neighbors(x, y)
			var alive: int     = grid[y][x]
			if alive == 1:
				next_grid[y][x] = 1 if (neighbors == 2 or neighbors == 3) else 0
			else:
				next_grid[y][x] = 1 if (neighbors == 3) else 0

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			grid[y][x] = next_grid[y][x]

	generation        += 1
	gen_label.text     = "Поколение: " + str(generation)
	queue_redraw()

func _count_neighbors(x: int, y: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = (x + dx + GRID_WIDTH)  % GRID_WIDTH
			var ny: int = (y + dy + GRID_HEIGHT) % GRID_HEIGHT
			count += grid[ny][nx]
	return count

func _draw() -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var rect := Rect2(
				Vector2(x * CELL_SIZE, y * CELL_SIZE),
				Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			)
			var color: Color = Color.WHITE if grid[y][x] == 1 else Color(0.08, 0.08, 0.08)
			draw_rect(rect, color)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pos: Vector2 = get_local_mouse_position()
			var x: int = int(pos.x / CELL_SIZE)
			var y: int = int(pos.y / CELL_SIZE)
			if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
				grid[y][x] = 1
				queue_redraw()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var pos: Vector2 = get_local_mouse_position()
			var x: int = int(pos.x / CELL_SIZE)
			var y: int = int(pos.y / CELL_SIZE)
			if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
				grid[y][x] = 0
				queue_redraw()
