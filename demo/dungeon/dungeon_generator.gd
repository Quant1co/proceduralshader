@tool
extends Node2D

## Скрипт генерации подземелья по графу L-системы
## Загружает JSON-граф и строит TileMap с комнатами и коридорами

@export_file("*.json") var graph_json_path: String = ""
@export var tile_size: int = 16
@export var room_min_size: int = 3
@export var room_max_size: int = 7
@export var corridor_width: int = 2
@export var grid_scale: float = 2.0
@export var auto_generate: bool = false

var tilemap: TileMap
var tileset: TileSet

const FLOOR_SOURCE: int = 0
const FLOOR_ATLAS: Vector2i = Vector2i(0, 0)
const WALL_ATLAS: Vector2i = Vector2i(1, 0)
const START_ATLAS: Vector2i = Vector2i(2, 0)
const EXIT_ATLAS: Vector2i = Vector2i(3, 0)

const LAYER_GROUND: int = 0

func _ready() -> void:
	if auto_generate and not graph_json_path.is_empty():
		generate()

func generate() -> void:
	# Очищаем предыдущую генерацию
	for child in get_children():
		child.queue_free()

	# Загружаем граф
	var graph: Dictionary = _load_graph(graph_json_path)
	if graph.is_empty():
		push_error("[Dungeon] Не удалось загрузить граф: " + graph_json_path)
		return

	# Создаём TileSet программно
	tileset = _create_tileset()

	# Создаём TileMap
	tilemap = TileMap.new()
	tilemap.name = "DungeonMap"
	tilemap.tile_set = tileset
	add_child(tilemap)

	# Генерируем подземелье
	var nodes: Array = graph["nodes"]
	var edges: Array = graph["edges"]

	if nodes.is_empty():
		push_warning("[Dungeon] Граф пуст")
		return

	# Нормализуем координаты в сетку тайлов
	var tile_nodes: Array = _normalize_to_grid(nodes)

	# Определяем размеры комнат
	var room_sizes: Array = _calculate_room_sizes(tile_nodes, graph.get("adjacency", {}))

	# Рисуем комнаты
	for i in range(tile_nodes.size()):
		var center: Vector2i = tile_nodes[i]
		var size: Vector2i = room_sizes[i]
		_draw_room(center, size)

	# Рисуем коридоры
	for edge in edges:
		var from_idx: int = edge["from"]
		var to_idx: int = edge["to"]
		if from_idx < tile_nodes.size() and to_idx < tile_nodes.size():
			_draw_corridor(tile_nodes[from_idx], tile_nodes[to_idx])

	# Обводим стенами
	_draw_walls()

	# Отмечаем старт и выход
	_mark_special_rooms(tile_nodes, graph.get("adjacency", {}))

	print("[Dungeon] Сгенерировано: %d комнат, %d коридоров" % [nodes.size(), edges.size()])

# ===========================================================================
#  Загрузка графа
# ===========================================================================
func _load_graph(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

# ===========================================================================
#  Создание TileSet программно
# ===========================================================================
func _create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)

	# Создаём атлас из программной текстуры
	var img := Image.create(4 * tile_size, tile_size, false, Image.FORMAT_RGBA8)

	# Тайл 0: пол (тёмно-серый)
	_fill_tile(img, 0, Color(0.25, 0.25, 0.3))

	# Тайл 1: стена (тёмно-коричневый)
	_fill_tile(img, 1, Color(0.4, 0.25, 0.15))

	# Тайл 2: старт (зелёный)
	_fill_tile(img, 2, Color(0.2, 0.7, 0.3))

	# Тайл 3: выход (красный)
	_fill_tile(img, 3, Color(0.8, 0.2, 0.2))

	var texture := ImageTexture.create_from_image(img)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_size, tile_size)

	# Создаём тайлы в атласе
	source.create_tile(Vector2i(0, 0))  # пол
	source.create_tile(Vector2i(1, 0))  # стена
	source.create_tile(Vector2i(2, 0))  # старт
	source.create_tile(Vector2i(3, 0))  # выход

	ts.add_source(source, FLOOR_SOURCE)

	return ts

func _fill_tile(img: Image, tile_index: int, color: Color) -> void:
	var x_start: int = tile_index * tile_size
	for x in range(x_start, x_start + tile_size):
		for y in range(0, tile_size):
			# Добавляем лёгкий шум для визуального разнообразия
			var noise: float = randf() * 0.1 - 0.05
			var c := Color(
				clampf(color.r + noise, 0.0, 1.0),
				clampf(color.g + noise, 0.0, 1.0),
				clampf(color.b + noise, 0.0, 1.0),
				1.0
			)
			img.set_pixel(x, y, c)

# ===========================================================================
#  Нормализация координат графа в сетку тайлов
# ===========================================================================
func _normalize_to_grid(nodes: Array) -> Array:
	if nodes.is_empty():
		return []

	# Находим границы
	var min_x: float = INF; var min_y: float = INF
	var max_x: float = -INF; var max_y: float = -INF
	for node in nodes:
		var x: float = node["x"]
		var y: float = node["y"]
		min_x = min(min_x, x); min_y = min(min_y, y)
		max_x = max(max_x, x); max_y = max(max_y, y)

	var range_x: float = max_x - min_x
	var range_y: float = max_y - min_y
	if range_x < 0.01: range_x = 1.0
	if range_y < 0.01: range_y = 1.0

	# Масштабируем в сетку с учётом размера комнат
	var grid_width: int = int(nodes.size() * grid_scale * room_max_size)
	var grid_height: int = int(nodes.size() * grid_scale * room_max_size)
	var scale_x: float = float(grid_width) / range_x
	var scale_y: float = float(grid_height) / range_y
	var grid_sc: float = min(scale_x, scale_y)

	var tile_nodes: Array = []
	for node in nodes:
		var tx: int = int((node["x"] - min_x) * grid_sc) + room_max_size + 2
		var ty: int = int((node["y"] - min_y) * grid_sc) + room_max_size + 2
		tile_nodes.append(Vector2i(tx, ty))

	# Убираем слишком близкие узлы (минимальное расстояние = room_max_size)
	for i in range(tile_nodes.size()):
		for j in range(i + 1, tile_nodes.size()):
			var dist: float = Vector2(tile_nodes[i]).distance_to(Vector2(tile_nodes[j]))
			if dist < room_max_size * 1.5:
				# Раздвигаем
				var dir: Vector2 = (Vector2(tile_nodes[j]) - Vector2(tile_nodes[i])).normalized()
				if dir.length() < 0.01:
					dir = Vector2(1, 0)
				tile_nodes[j] = Vector2i(tile_nodes[j]) + Vector2i(dir * room_max_size)

	return tile_nodes

# ===========================================================================
#  Размеры комнат
# ===========================================================================
func _calculate_room_sizes(tile_nodes: Array, adjacency: Dictionary) -> Array:
	var sizes: Array = []
	for i in range(tile_nodes.size()):
		var key: String = str(i)
		var neighbor_count: int = 0
		if adjacency.has(key):
			neighbor_count = adjacency[key].size()

		var w: int; var h: int
		if neighbor_count >= 3:
			# Перекрёсток — большая комната
			w = room_max_size
			h = room_max_size
		elif neighbor_count == 1:
			# Тупик — маленькая комната
			w = room_min_size
			h = room_min_size
		else:
			# Обычная — средняя
			w = roundi(lerp(float(room_min_size), float(room_max_size), 0.5))
			h = roundi(lerp(float(room_min_size), float(room_max_size), 0.5))

		sizes.append(Vector2i(w, h))
	return sizes

# ===========================================================================
#  Рисование комнаты
# ===========================================================================
func _draw_room(center: Vector2i, size: Vector2i) -> void:
	var half_w: int = int(size.x / 2.0)
	var half_h: int = int(size.y / 2.0)
	for x in range(center.x - half_w, center.x + half_w + 1):
		for y in range(center.y - half_h, center.y + half_h + 1):
			tilemap.set_cell(LAYER_GROUND, Vector2i(x, y), FLOOR_SOURCE, FLOOR_ATLAS)

# ===========================================================================
#  Рисование коридора (L-образный)
# ===========================================================================
func _draw_corridor(from: Vector2i, to: Vector2i) -> void:
	# Горизонтальный участок
	var x_start: int = min(from.x, to.x)
	var x_end: int = max(from.x, to.x)
	for x in range(x_start, x_end + 1):
		for w in range(corridor_width):
			tilemap.set_cell(LAYER_GROUND, Vector2i(x, from.y + w), FLOOR_SOURCE, FLOOR_ATLAS)
			tilemap.set_cell(LAYER_GROUND, Vector2i(x, from.y - w), FLOOR_SOURCE, FLOOR_ATLAS)

	# Вертикальный участок
	var y_start: int = min(from.y, to.y)
	var y_end: int = max(from.y, to.y)
	for y in range(y_start, y_end + 1):
		for w in range(corridor_width):
			tilemap.set_cell(LAYER_GROUND, Vector2i(to.x + w, y), FLOOR_SOURCE, FLOOR_ATLAS)
			tilemap.set_cell(LAYER_GROUND, Vector2i(to.x - w, y), FLOOR_SOURCE, FLOOR_ATLAS)

# ===========================================================================
#  Обводка стенами
# ===========================================================================
func _draw_walls() -> void:
	# Собираем все тайлы пола
	var floor_cells: Array = tilemap.get_used_cells(LAYER_GROUND)
	var floor_set: Dictionary = {}
	for cell in floor_cells:
		floor_set[cell] = true

	# Для каждого пустого соседа тайла пола — ставим стену
	var wall_cells: Dictionary = {}
	for cell in floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor := Vector2i(cell.x + dx, cell.y + dy)
				if not floor_set.has(neighbor):
					wall_cells[neighbor] = true

	for cell in wall_cells:
		tilemap.set_cell(LAYER_GROUND, cell, FLOOR_SOURCE, WALL_ATLAS)

# ===========================================================================
#  Отметить старт и выход
# ===========================================================================
func _mark_special_rooms(tile_nodes: Array, adjacency: Dictionary) -> void:
	if tile_nodes.is_empty():
		return

	# Старт — первый узел (корень графа)
	var start: Vector2i = tile_nodes[0]
	tilemap.set_cell(LAYER_GROUND, start, FLOOR_SOURCE, START_ATLAS)

	# Выход — самый дальний листовой узел
	var exit_idx: int = 0
	var max_dist: float = 0.0
	for i in range(tile_nodes.size()):
		var key: String = str(i)
		var is_leaf: bool = false
		if adjacency.has(key):
			is_leaf = adjacency[key].size() == 1
		if is_leaf:
			var dist: float = Vector2(tile_nodes[i]).distance_to(Vector2(start))
			if dist > max_dist:
				max_dist = dist
				exit_idx = i

	if exit_idx != 0:
		var exit_pos: Vector2i = tile_nodes[exit_idx]
		tilemap.set_cell(LAYER_GROUND, exit_pos, FLOOR_SOURCE, EXIT_ATLAS)
