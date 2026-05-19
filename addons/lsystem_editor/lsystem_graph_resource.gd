@tool
class_name LSystemGraphResource
extends Resource

## Узлы графа — массив Vector2 координат
@export var nodes: PackedVector2Array = PackedVector2Array()

## Рёбра — каждое ребро [from_id, to_id]
@export var edges: Array[Vector2i] = []

## Символ для каждого ребра
@export var edge_symbols: PackedStringArray = PackedStringArray()

## Глубина для каждого ребра
@export var edge_depths: PackedInt32Array = PackedInt32Array()

## Список смежности — для каждого узла массив соседних узлов
@export var adjacency: Array[PackedInt32Array] = []

## Метаданные генерации
@export var axiom: String = ""
@export var angle: float = 0.0
@export var step: float = 0.0
@export var iterations: int = 0
@export var generation_seed: int = 0

## Количество узлов
func get_node_count() -> int:
	return nodes.size()

## Количество рёбер
func get_edge_count() -> int:
	return edges.size()

## Получить позицию узла
func get_node_position(node_id: int) -> Vector2:
	if node_id >= 0 and node_id < nodes.size():
		return nodes[node_id]
	return Vector2.ZERO

## Получить соседей узла
func get_neighbors(node_id: int) -> PackedInt32Array:
	if node_id >= 0 and node_id < adjacency.size():
		return adjacency[node_id]
	return PackedInt32Array()

## Получить ребро по индексу
func get_edge(edge_idx: int) -> Vector2i:
	if edge_idx >= 0 and edge_idx < edges.size():
		return edges[edge_idx]
	return Vector2i(-1, -1)

## Получить символ ребра
func get_edge_symbol(edge_idx: int) -> String:
	if edge_idx >= 0 and edge_idx < edge_symbols.size():
		return edge_symbols[edge_idx]
	return ""

## Проверить, является ли узел точкой ветвления (3+ соседей)
func is_branch_point(node_id: int) -> bool:
	if node_id >= 0 and node_id < adjacency.size():
		return adjacency[node_id].size() >= 3
	return false

## Получить все точки ветвления
func get_branch_points() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in range(adjacency.size()):
		if adjacency[i].size() >= 3:
			result.append(i)
	return result

## Получить все листовые узлы (1 сосед)
func get_leaf_nodes() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in range(adjacency.size()):
		if adjacency[i].size() == 1:
			result.append(i)
	return result