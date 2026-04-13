extends Node2D

const PRESETS: Dictionary = {
	"Koch Curve": {
		"axiom":      "F",
		"rules":      {"F": "F+F-F-F+F"},
		"angle":      90.0,
		"step":       5.0,
		"iterations": 4
	},
	"Sierpinski": {
		"axiom":      "F-G-G",
		"rules":      {"F": "F-G+F+G-F", "G": "GG"},
		"angle":      120.0,
		"step":       8.0,
		"iterations": 5
	},
	"Plant": {
		"axiom":      "X",
		"rules":      {
			"X": "F+[[X]-X]-F[-FX]+X",
			"F": "FF"
		},
		"angle":      25.0,
		"step":       8.0,
		"iterations": 5
	},
	"Dragon Curve": {
		"axiom":      "FX",
		"rules":      {"X": "X+YF+", "Y": "-FX-Y"},
		"angle":      90.0,
		"step":       6.0,
		"iterations": 10
	}
}

var lines: Array[PackedVector2Array] = []

@onready var preset_selector: OptionButton = $UI/Panel/VBox/PresetSelector
@onready var iter_label:      Label        = $UI/Panel/VBox/IterLabel
@onready var iter_slider:     HSlider      = $UI/Panel/VBox/IterSlider
@onready var zoom_label:      Label        = $UI/Panel/VBox/ZoomLabel
@onready var zoom_slider:     HSlider      = $UI/Panel/VBox/ZoomSlider
@onready var generate_btn:    Button       = $UI/Panel/VBox/GenerateButton
@onready var back_button:     Button       = $UI/Panel/VBox/BackButton

var user_scale: float = 1.0

func _ready() -> void:
	for preset_name in PRESETS.keys():
		preset_selector.add_item(preset_name)

	iter_slider.value_changed.connect(func(v: float) -> void:
		iter_label.text = "Итераций: " + str(int(v))
	)
	zoom_slider.value_changed.connect(func(v: float) -> void:
		user_scale = v
		zoom_label.text = "Зум: %.1f" % v
		_generate()
	)
	preset_selector.item_selected.connect(func(_i: int) -> void: _generate())
	generate_btn.pressed.connect(_generate)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/BakerScene.tscn"))

	_generate()

func _generate() -> void:
	var preset_name: String = preset_selector.get_item_text(preset_selector.selected)
	var preset: Dictionary  = PRESETS[preset_name]
	var iterations: int     = int(iter_slider.value)

	var lstring: String = _apply_rules(preset["axiom"], preset["rules"], iterations)
	_interpret(lstring, preset["angle"], preset["step"])
	queue_redraw()

func _apply_rules(axiom: String, rules: Dictionary, iterations: int) -> String:
	var result: String = axiom
	for _i in range(iterations):
		var next: String = ""
		for ch in result:
			next += rules.get(ch, ch)
		result = next
	return result

func _interpret(lstring: String, angle_deg: float, step: float) -> void:
	lines.clear()

	var viewport_size: Vector2 = get_viewport_rect().size
	var pos:   Vector2 = viewport_size / 2.0
	var angle: float   = -90.0
	var stack: Array   = []

	var current_line := PackedVector2Array()
	current_line.append(pos)

	for ch in lstring:
		match ch:
			"F", "G":
				var new_pos: Vector2 = pos + Vector2(
					cos(deg_to_rad(angle)) * step,
					sin(deg_to_rad(angle)) * step
				)
				current_line.append(new_pos)
				pos = new_pos
			"+":
				angle += angle_deg
			"-":
				angle -= angle_deg
			"[":
				stack.push_back({
					"pos":   pos,
					"angle": angle,
					"line":  current_line
				})
				current_line = PackedVector2Array()
				current_line.append(pos)
			"]":
				if stack.size() > 0:
					lines.append(current_line)
					var state: Dictionary = stack.pop_back()
					pos          = state["pos"]
					angle        = state["angle"]
					current_line = state["line"]

	lines.append(current_line)
	_fit_lines_to_viewport()

func _fit_lines_to_viewport() -> void:
	if lines.is_empty():
		return

	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for line in lines:
		for p in line:
			min_pos.x = min(min_pos.x, p.x)
			min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x)
			max_pos.y = max(max_pos.y, p.y)

	var bounds_size := max_pos - min_pos
	if bounds_size.x < 1.0 or bounds_size.y < 1.0:
		return

	var viewport_size := get_viewport_rect().size
	var padding := 0.15
	var target_w := viewport_size.x * (1.0 - padding * 2.0)
	var target_h := viewport_size.y * (1.0 - padding * 2.0)

	var base_scale: float = min(target_w / bounds_size.x, target_h / bounds_size.y)
	var scale_factor: float = base_scale * user_scale

	var center_offset: Vector2 = viewport_size / 2.0 - (min_pos + bounds_size / 2.0) * scale_factor

	for i in range(lines.size()):
		for j in range(lines[i].size()):
			lines[i][j] = lines[i][j] * scale_factor + center_offset

func _draw() -> void:
	for line in lines:
		if line.size() >= 2:
			draw_polyline(line, Color(0.2, 0.9, 0.3), 1.0, true)
