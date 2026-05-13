@tool
extends Control

# ===========================================================================
#  Встроенные пресеты
# ===========================================================================
const BUILTIN_PRESETS: Dictionary = {
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

# ===========================================================================
#  Пути
# ===========================================================================
const USER_PRESETS_PATH: String = "user://lsystem_presets.json"
const DEFAULT_EXPORT_PATH: String = "res://export/lsystem/"
const SETTINGS_PATH: String = "user://lsystem_settings.cfg"

# ===========================================================================
#  Константы
# ===========================================================================
const MAX_LSTRING_LENGTH: int = 500_000
const DRAWING_SYMBOLS: Array[String] = ["F", "G"]

const DEFAULT_SYMBOL_COLORS: Dictionary = {
	"F": Color(0.2, 0.9, 0.3),
	"G": Color(0.3, 0.5, 0.9),
}

enum ColorMode { SINGLE, BY_SYMBOL, BY_DEPTH }

# ===========================================================================
#  Переменные
# ===========================================================================
var user_presets: Dictionary = {}
var rule_rows: Array = []
var segments: Array = []
var max_depth: int = 0
var user_scale: float = 1.0
var _last_preview_size: float = 0.0
var _current_render_size: int = 300
var custom_export_path: String = ""
var _cached_char_data: Array = []
var _rng := RandomNumberGenerator.new()
var _current_seed: int = 0

var color_mode: int = ColorMode.SINGLE
var single_color: Color = Color(0.2, 0.9, 0.3)
var symbol_colors: Dictionary = {}
var depth_color_start: Color = Color(0.55, 0.27, 0.07)
var depth_color_end: Color = Color(0.2, 0.9, 0.3)
var symbol_color_rows: Array = []

# ===========================================================================
#  UI-ссылки
# ===========================================================================
@onready var preset_selector:          OptionButton         = $ScrollContainer/VBox/PresetSelector
@onready var axiom_edit:               LineEdit             = $ScrollContainer/VBox/AxiomEdit
@onready var rules_container:          VBoxContainer        = $ScrollContainer/VBox/RulesContainer
@onready var add_rule_button:          Button               = $ScrollContainer/VBox/AddRuleButton
@onready var angle_label:              Label                = $ScrollContainer/VBox/AngleLabel
@onready var angle_slider:             HSlider              = $ScrollContainer/VBox/AngleSlider
@onready var step_label:               Label                = $ScrollContainer/VBox/StepLabel
@onready var step_slider:              HSlider              = $ScrollContainer/VBox/StepSlider
@onready var iter_label:               Label                = $ScrollContainer/VBox/IterLabel
@onready var iter_slider:              HSlider              = $ScrollContainer/VBox/IterSlider
@onready var zoom_label:               Label                = $ScrollContainer/VBox/ZoomLabel
@onready var zoom_slider:              HSlider              = $ScrollContainer/VBox/ZoomSlider
@onready var color_mode_selector:      OptionButton         = $ScrollContainer/VBox/ColorModeSelector
@onready var single_color_row:         HBoxContainer        = $ScrollContainer/VBox/SingleColorRow
@onready var single_color_picker:      ColorPickerButton    = $ScrollContainer/VBox/SingleColorRow/SingleColorPicker
@onready var symbol_colors_container:  VBoxContainer        = $ScrollContainer/VBox/SymbolColorsContainer
@onready var depth_start_row:          HBoxContainer        = $ScrollContainer/VBox/DepthStartRow
@onready var depth_start_picker:       ColorPickerButton    = $ScrollContainer/VBox/DepthStartRow/DepthStartPicker
@onready var depth_end_row:            HBoxContainer        = $ScrollContainer/VBox/DepthEndRow
@onready var depth_end_picker:         ColorPickerButton    = $ScrollContainer/VBox/DepthEndRow/DepthEndPicker
@onready var preview_container:        SubViewportContainer = $ScrollContainer/VBox/PreviewContainer
@onready var preview_viewport:         SubViewport          = $ScrollContainer/VBox/PreviewContainer/PreviewViewport
@onready var draw_node:                Node2D               = $ScrollContainer/VBox/PreviewContainer/PreviewViewport/DrawNode
@onready var generate_btn:             Button               = $ScrollContainer/VBox/GenerateButton
@onready var export_button:            Button               = $ScrollContainer/VBox/ExportButton
@onready var export_path_button:       Button               = $ScrollContainer/VBox/ExportPathButton
@onready var open_export_folder_btn:   Button               = $ScrollContainer/VBox/OpenExportFolderButton
@onready var save_preset_button:       Button               = $ScrollContainer/VBox/SavePresetButton
@onready var delete_preset_button:     Button               = $ScrollContainer/VBox/DeletePresetButton
@onready var status_label:             Label                = $ScrollContainer/VBox/StatusLabel

# ===========================================================================
#  _ready
# ===========================================================================
func _ready() -> void:
	_load_user_presets()
	_load_settings()
	_populate_presets()

	draw_node.draw.connect(_on_draw_node_draw)

	color_mode_selector.add_item("Единый цвет")
	color_mode_selector.add_item("По символам")
	color_mode_selector.add_item("Градиент")
	color_mode_selector.item_selected.connect(_on_color_mode_changed)

	single_color_picker.color_changed.connect(func(c: Color):
		single_color = c
		draw_node.queue_redraw()
	)
	depth_start_picker.color_changed.connect(func(c: Color):
		depth_color_start = c
		draw_node.queue_redraw()
	)
	depth_end_picker.color_changed.connect(func(c: Color):
		depth_color_end = c
		draw_node.queue_redraw()
	)

	_update_color_ui_visibility()

	preset_selector.item_selected.connect(_on_preset_selected)
	generate_btn.pressed.connect(_generate)
	add_rule_button.pressed.connect(func(): _add_rule_row())
	save_preset_button.pressed.connect(_on_save_preset_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_pressed)
	export_button.pressed.connect(_on_export_pressed)
	export_path_button.pressed.connect(_pick_export_path)
	open_export_folder_btn.pressed.connect(_on_open_export_folder)

	angle_slider.value_changed.connect(func(v: float):
		angle_label.text = "Угол: %.0f°" % v
	)
	step_slider.value_changed.connect(func(v: float):
		step_label.text = "Длина шага: %.1f" % v
	)
	iter_slider.value_changed.connect(func(v: float):
		iter_label.text = "Итераций: %d" % int(v)
	)
	zoom_slider.value_changed.connect(func(v: float):
		user_scale = v
		zoom_label.text = "Зум: %.1f" % v
		if not _cached_char_data.is_empty():
			_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
			draw_node.queue_redraw()
	)

	if preset_selector.item_count > 0:
		preset_selector.selected = 0
		_on_preset_selected(0)

# ===========================================================================
#  _process
# ===========================================================================
func _process(_delta: float) -> void:
	if preview_container == null or preview_viewport == null:
		return
	var current_width: float = preview_container.size.x
	if current_width < 50.0:
		return
	if abs(current_width - _last_preview_size) > 2.0:
		_last_preview_size = current_width
		preview_container.custom_minimum_size.y = current_width
		_current_render_size = preview_viewport.size.x
		_regenerate_for_current_size()

# ===========================================================================
#  Режимы окраски
# ===========================================================================
func _on_color_mode_changed(index: int) -> void:
	color_mode = index
	_update_color_ui_visibility()
	if color_mode == ColorMode.BY_SYMBOL:
		_rebuild_symbol_color_rows()
	draw_node.queue_redraw()

func _update_color_ui_visibility() -> void:
	single_color_row.visible = (color_mode == ColorMode.SINGLE)
	symbol_colors_container.visible = (color_mode == ColorMode.BY_SYMBOL)
	depth_start_row.visible = (color_mode == ColorMode.BY_DEPTH)
	depth_end_row.visible = (color_mode == ColorMode.BY_DEPTH)

# ===========================================================================
#  Цвета по символам
# ===========================================================================
func _rebuild_symbol_color_rows() -> void:
	for row_data in symbol_color_rows:
		if is_instance_valid(row_data["row"]):
			row_data["row"].queue_free()
	symbol_color_rows.clear()

	var symbols := _collect_drawing_symbols()

	for sym in symbols:
		var hbox := HBoxContainer.new()

		var label := Label.new()
		label.text = sym + ":"
		label.custom_minimum_size.x = 80
		hbox.add_child(label)

		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(60, 30)
		picker.color = symbol_colors.get(sym, DEFAULT_SYMBOL_COLORS.get(sym, Color.WHITE))
		hbox.add_child(picker)

		symbol_colors[sym] = picker.color

		var captured_sym := sym
		picker.color_changed.connect(func(c: Color):
			symbol_colors[captured_sym] = c
			draw_node.queue_redraw()
		)

		symbol_colors_container.add_child(hbox)
		symbol_color_rows.append({"symbol": sym, "picker": picker, "row": hbox})

func _collect_drawing_symbols() -> Array[String]:
	var symbols: Array[String] = []
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()

	var all_chars: String = axiom
	for key in rules.keys():
		var rule_list: Array = rules[key]
		for rule_data in rule_list:
			all_chars += rule_data["replacement"]

	for ch in all_chars:
		if ch in DRAWING_SYMBOLS and ch not in symbols:
			symbols.append(ch)

	return symbols

# ===========================================================================
#  Цвет сегмента
# ===========================================================================
func _get_segment_color(seg: Dictionary, seg_index: int = 0) -> Color:
	match color_mode:
		ColorMode.SINGLE:
			return single_color
		ColorMode.BY_SYMBOL:
			return symbol_colors.get(seg["symbol"], single_color)
		ColorMode.BY_DEPTH:
			var t: float = 0.0
			if segments.size() > 1:
				t = float(seg_index) / float(segments.size() - 1)
			return depth_color_start.lerp(depth_color_end, t)
	return single_color

func _get_export_segment_color(seg: Dictionary, seg_index: int, total: int) -> Color:
	match color_mode:
		ColorMode.SINGLE:
			return single_color
		ColorMode.BY_SYMBOL:
			return symbol_colors.get(seg["symbol"], single_color)
		ColorMode.BY_DEPTH:
			var t: float = 0.0
			if total > 1:
				t = float(seg_index) / float(total - 1)
			return depth_color_start.lerp(depth_color_end, t)
	return single_color

# ===========================================================================
#  Путь экспорта
# ===========================================================================
func _get_export_path() -> String:
	if custom_export_path.is_empty():
		return DEFAULT_EXPORT_PATH
	return custom_export_path

func _get_export_dir_absolute() -> String:
	var path := _get_export_path()
	var abs_path: String
	if path.begins_with("user://") or path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	else:
		abs_path = path
	if not abs_path.ends_with("/") and not abs_path.ends_with("\\"):
		abs_path += "/"
	return abs_path

func _pick_export_path() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Выбрать папку экспорта L-систем"
	dialog.access = 2
	dialog.dir_selected.connect(func(path: String):
		custom_export_path = path
		_update_export_path_button()
		_save_settings()
		_set_status("Папка экспорта: " + path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _update_export_path_button() -> void:
	if custom_export_path.is_empty():
		export_path_button.text = "Папка экспорта: по умолчанию"
	else:
		var parts := custom_export_path.replace("\\", "/").split("/")
		var short: String = ""
		if parts.size() >= 2:
			short = parts[-2] + "/" + parts[-1]
		elif parts.size() >= 1:
			short = parts[-1]
		else:
			short = custom_export_path
		export_path_button.text = "Экспорт: .../" + short

# ===========================================================================
#  Настройки
# ===========================================================================
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("export", "export_path", custom_export_path if not custom_export_path.is_empty() else "")
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		custom_export_path = cfg.get_value("export", "export_path", "")
	_update_export_path_button()

# ===========================================================================
#  Перегенерация (использует кэш)
# ===========================================================================
func _regenerate_for_current_size() -> void:
	if _cached_char_data.is_empty():
		return
	_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
	draw_node.queue_redraw()

# ===========================================================================
#  Отрисовка
# ===========================================================================
func _on_draw_node_draw() -> void:
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var color: Color = _get_segment_color(seg, i)
		draw_node.draw_line(seg["from"], seg["to"], color, 1.0, true)

# ===========================================================================
#  Пресеты
# ===========================================================================
func _populate_presets() -> void:
	preset_selector.clear()
	for preset_name in BUILTIN_PRESETS.keys():
		preset_selector.add_item(preset_name)
	for preset_name in user_presets.keys():
		preset_selector.add_item("★ " + preset_name)
	preset_selector.add_item("✦ Создать свой...")

func _on_preset_selected(index: int) -> void:
	var item_text: String = preset_selector.get_item_text(index)
	if item_text == "✦ Создать свой...":
		axiom_edit.text = ""
		_clear_rule_rows()
		_add_rule_row()
		angle_slider.value = 90.0
		step_slider.value  = 5.0
		iter_slider.value  = 3
		_set_fields_editable(true)
		_update_delete_button_visibility()
		segments.clear()
		_cached_char_data.clear()
		draw_node.queue_redraw()
		_set_status("")
		return

	if item_text.begins_with("★ "):
		var preset_name: String = item_text.substr(2)
		if user_presets.has(preset_name):
			var preset: Dictionary = user_presets[preset_name]
			_load_preset_to_ui(preset)
			_set_fields_editable(true)
			var saved_seed: int = int(preset.get("seed", randi()))
			_current_seed = saved_seed
			_generate_with_seed(_current_seed)
	else:
		if BUILTIN_PRESETS.has(item_text):
			_load_preset_to_ui(BUILTIN_PRESETS[item_text])
			_set_fields_editable(false)
			_generate()

	_update_delete_button_visibility()

func _load_preset_to_ui(preset: Dictionary) -> void:
	axiom_edit.text = preset.get("axiom", "")
	_clear_rule_rows()
	var rules = preset.get("rules", {})
	for symbol in rules.keys():
		var value = rules[symbol]
		if value is String:
			_add_rule_row(symbol, value, 1.0)
		elif value is Array:
			for rule_data in value:
				var repl: String = rule_data.get("replacement", "") if rule_data is Dictionary else str(rule_data)
				var w: float = rule_data.get("weight", 1.0) if rule_data is Dictionary else 1.0
				_add_rule_row(symbol, repl, w)
		else:
			_add_rule_row(symbol, str(value), 1.0)
	angle_slider.value = preset.get("angle", 90.0)
	step_slider.value  = preset.get("step", 5.0)
	iter_slider.value  = preset.get("iterations", 4)
	_update_labels()

# ===========================================================================
#  Редактируемость
# ===========================================================================
func _set_fields_editable(editable: bool) -> void:
	axiom_edit.editable = editable
	add_rule_button.visible = editable
	save_preset_button.visible = editable
	for row in rule_rows:
		row["symbol"].editable = editable
		row["replacement"].editable = editable
		row["weight"].editable = editable
		var remove_btn = row["row"].get_child(row["row"].get_child_count() - 1)
		if remove_btn is Button:
			remove_btn.visible = editable

func _update_delete_button_visibility() -> void:
	var item_text: String = preset_selector.get_item_text(preset_selector.selected)
	delete_preset_button.visible = item_text.begins_with("★ ")

# ===========================================================================
#  Метки
# ===========================================================================
func _update_labels() -> void:
	angle_label.text = "Угол: %.0f°" % angle_slider.value
	step_label.text  = "Длина шага: %.1f" % step_slider.value
	iter_label.text  = "Итераций: %d" % int(iter_slider.value)
	zoom_label.text  = "Зум: %.1f" % zoom_slider.value

func _set_status(text: String) -> void:
	status_label.text = text

# ===========================================================================
#  Правила с весом
# ===========================================================================
func _add_rule_row(symbol: String = "", replacement: String = "", weight: float = 1.0) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var symbol_edit := LineEdit.new()
	symbol_edit.custom_minimum_size.x = 35
	symbol_edit.max_length = 1
	symbol_edit.text = symbol
	symbol_edit.placeholder_text = "F"
	symbol_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(symbol_edit)

	var arrow := Label.new()
	arrow.text = " → "
	hbox.add_child(arrow)

	var replacement_edit := LineEdit.new()
	replacement_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement_edit.text = replacement
	replacement_edit.placeholder_text = "F+F-F-F+F"
	hbox.add_child(replacement_edit)

	var weight_label := Label.new()
	weight_label.text = " вес:"
	hbox.add_child(weight_label)

	var weight_spin := SpinBox.new()
	weight_spin.min_value = 0.01
	weight_spin.max_value = 100.0
	weight_spin.step = 0.01
	weight_spin.value = weight
	weight_spin.custom_minimum_size.x = 65
	hbox.add_child(weight_spin)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size.x = 32
	hbox.add_child(remove_btn)

	rules_container.add_child(hbox)

	var row_data: Dictionary = {
		"symbol":      symbol_edit,
		"replacement": replacement_edit,
		"weight":      weight_spin,
		"row":         hbox
	}
	rule_rows.append(row_data)

	remove_btn.pressed.connect(func():
		rule_rows.erase(row_data)
		hbox.queue_free()
	)

func _clear_rule_rows() -> void:
	for row in rule_rows:
		if is_instance_valid(row["row"]):
			row["row"].queue_free()
	rule_rows.clear()

func _collect_rules_from_ui() -> Dictionary:
	var rules: Dictionary = {}
	for row in rule_rows:
		var s: String = row["symbol"].text.strip_edges()
		var r: String = row["replacement"].text.strip_edges()
		var w: float = row["weight"].value
		if not s.is_empty() and not r.is_empty():
			if not rules.has(s):
				rules[s] = []
			rules[s].append({"replacement": r, "weight": w})
	return rules

# ===========================================================================
#  Выбор правила по весу
# ===========================================================================
func _pick_weighted_rule(rule_list: Array) -> String:
	if rule_list.size() == 1:
		return rule_list[0]["replacement"]

	var total_weight: float = 0.0
	for rule in rule_list:
		total_weight += rule["weight"]

	var roll: float = _rng.randf() * total_weight
	var cumulative: float = 0.0
	for rule in rule_list:
		cumulative += rule["weight"]
		if roll <= cumulative:
			return rule["replacement"]

	return rule_list[-1]["replacement"]

# ===========================================================================
#  Генерация (новый случайный seed)
# ===========================================================================
func _generate() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	if axiom.is_empty():
		segments.clear()
		_cached_char_data.clear()
		draw_node.queue_redraw()
		return

	var rules: Dictionary = _collect_rules_from_ui()
	if rules.is_empty():
		segments.clear()
		_cached_char_data.clear()
		draw_node.queue_redraw()
		return

	_current_seed = randi()
	_generate_with_seed(_current_seed)

# ===========================================================================
#  Генерация с конкретным seed (для воспроизводимости)
# ===========================================================================
func _generate_with_seed(seed_value: int) -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	if axiom.is_empty() or rules.is_empty():
		return

	_rng.seed = seed_value
	var iterations: int = int(iter_slider.value)
	_cached_char_data = _apply_rules_with_depth(axiom, rules, iterations)
	_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
	draw_node.queue_redraw()

	if color_mode == ColorMode.BY_SYMBOL:
		_rebuild_symbol_color_rows()

	_set_status("Сгенерировано: %d сегментов" % segments.size())

# ===========================================================================
#  Применение правил с глубиной и весами
# ===========================================================================
func _apply_rules_with_depth(axiom: String, rules: Dictionary, iterations: int) -> Array:
	var result: Array = []
	for ch in axiom:
		result.append({"char": ch, "depth": 0})

	for iter_idx in range(iterations):
		var next: Array = []
		for item in result:
			var ch: String = item["char"]
			if rules.has(ch):
				var rule_list: Array = rules[ch]
				var chosen: String = _pick_weighted_rule(rule_list)
				for new_ch in chosen:
					next.append({"char": new_ch, "depth": iter_idx + 1})
			else:
				next.append(item)
			if next.size() > MAX_LSTRING_LENGTH:
				push_warning("[LSystem] Превышен лимит %d символов на итерации %d" % [MAX_LSTRING_LENGTH, iter_idx])
				return next
		result = next

	return result

# ===========================================================================
#  Интерпретация
# ===========================================================================
func _interpret_colored(char_data: Array, angle_deg: float, step: float, target_size: int) -> void:
	segments.clear()
	max_depth = 0

	var center: float = float(target_size) / 2.0
	var pos: Vector2  = Vector2(center, center)
	var angle: float  = -90.0
	var stack: Array   = []

	for item in char_data:
		var ch: String = item["char"]
		var depth: int = item["depth"]
		if depth > max_depth:
			max_depth = depth

		match ch:
			"F", "G":
				var new_pos: Vector2 = pos + Vector2(
					cos(deg_to_rad(angle)) * step,
					sin(deg_to_rad(angle)) * step
				)
				segments.append({
					"from": pos,
					"to": new_pos,
					"symbol": ch,
					"depth": depth
				})
				pos = new_pos
			"+":
				angle += angle_deg
			"-":
				angle -= angle_deg
			"[":
				stack.push_back({"pos": pos, "angle": angle})
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back()
					pos   = state["pos"]
					angle = state["angle"]

	_fit_segments_to_size(target_size)

# ===========================================================================
#  Масштабирование
# ===========================================================================
func _fit_segments_to_size(target_size: int) -> void:
	if segments.is_empty():
		return

	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for seg in segments:
		for key in ["from", "to"]:
			var p: Vector2 = seg[key]
			min_pos.x = min(min_pos.x, p.x)
			min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x)
			max_pos.y = max(max_pos.y, p.y)

	var bounds_size := max_pos - min_pos
	if bounds_size.x < 1.0 or bounds_size.y < 1.0:
		return

	var padding: float = 0.1
	var target: float  = float(target_size) * (1.0 - padding * 2.0)
	var base_scale: float   = min(target / bounds_size.x, target / bounds_size.y)
	var scale_factor: float = base_scale * user_scale

	var img_center := Vector2(float(target_size), float(target_size)) / 2.0
	var bounds_center := (min_pos + bounds_size / 2.0) * scale_factor
	var center_offset: Vector2 = img_center - bounds_center

	for seg in segments:
		seg["from"] = seg["from"] * scale_factor + center_offset
		seg["to"]   = seg["to"]   * scale_factor + center_offset

# ===========================================================================
#  Экспорт
# ===========================================================================
func _on_export_pressed() -> void:
	if segments.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте")
		return

	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)

	var export_size: int = 1024
	var export_segments := _generate_segments_for_export(export_size)

	var image: Image = Image.create(export_size, export_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.05, 1.0))

	var total: int = export_segments.size()
	for i in range(total):
		var seg: Dictionary = export_segments[i]
		var color: Color = _get_export_segment_color(seg, i, total)
		_draw_line_on_image(image, seg["from"], seg["to"], color)

	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_name: String = "lsystem_" + timestamp

	var png_path: String = abs_export_dir + file_name + ".png"
	var err: Error = image.save_png(png_path)
	if err != OK:
		_set_status("Ошибка сохранения PNG")
		push_error("[LSystem] Ошибка сохранения PNG: " + str(err))
		return

	var json_path: String = abs_export_dir + file_name + ".json"
	_export_lsystem_metadata(json_path)

	_set_status("Экспортировано: " + file_name)
	print("[LSystem] Экспортировано: " + png_path)

func _generate_segments_for_export(img_size: int) -> Array:
	if _cached_char_data.is_empty():
		return []

	var export_segments: Array = []
	var center: float = float(img_size) / 2.0
	var pos: Vector2  = Vector2(center, center)
	var angle: float  = -90.0
	var stack: Array   = []

	for item in _cached_char_data:
		var ch: String = item["char"]
		var depth: int = item["depth"]
		match ch:
			"F", "G":
				var new_pos: Vector2 = pos + Vector2(
					cos(deg_to_rad(angle)) * step_slider.value,
					sin(deg_to_rad(angle)) * step_slider.value
				)
				export_segments.append({
					"from": pos, "to": new_pos,
					"symbol": ch, "depth": depth
				})
				pos = new_pos
			"+":
				angle += angle_slider.value
			"-":
				angle -= angle_slider.value
			"[":
				stack.push_back({"pos": pos, "angle": angle})
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back()
					pos   = state["pos"]
					angle = state["angle"]

	if export_segments.is_empty():
		return []

	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for seg in export_segments:
		for key in ["from", "to"]:
			var p: Vector2 = seg[key]
			min_pos.x = min(min_pos.x, p.x)
			min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x)
			max_pos.y = max(max_pos.y, p.y)

	var bounds_size := max_pos - min_pos
	if bounds_size.x < 1.0 or bounds_size.y < 1.0:
		return export_segments

	var padding: float = 0.1
	var target: float  = float(img_size) * (1.0 - padding * 2.0)
	var scale_factor: float = min(target / bounds_size.x, target / bounds_size.y)
	var img_center := Vector2(float(img_size), float(img_size)) / 2.0
	var bounds_center := (min_pos + bounds_size / 2.0) * scale_factor
	var center_offset: Vector2 = img_center - bounds_center

	for seg in export_segments:
		seg["from"] = seg["from"] * scale_factor + center_offset
		seg["to"]   = seg["to"]   * scale_factor + center_offset

	return export_segments

# ===========================================================================
#  Брезенхэм
# ===========================================================================
func _draw_line_on_image(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var x0: int = int(round(from.x))
	var y0: int = int(round(from.y))
	var x1: int = int(round(to.x))
	var y1: int = int(round(to.y))
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var w: int = image.get_width()
	var h: int = image.get_height()
	while true:
		if x0 >= 0 and x0 < w and y0 >= 0 and y0 < h:
			image.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

# ===========================================================================
#  Метаданные
# ===========================================================================
func _export_lsystem_metadata(path: String) -> void:
	var rules: Dictionary = _collect_rules_from_ui()

	var rules_export: Dictionary = {}
	for symbol in rules.keys():
		var rule_list: Array = rules[symbol]
		var export_list: Array = []
		for rule_data in rule_list:
			export_list.append({
				"replacement": rule_data["replacement"],
				"weight": rule_data["weight"]
			})
		rules_export[symbol] = export_list

	var color_info: Dictionary = {}
	match color_mode:
		ColorMode.SINGLE:
			color_info = {"mode": "single", "color": _color_to_hex(single_color)}
		ColorMode.BY_SYMBOL:
			var sym_cols: Dictionary = {}
			for sym in symbol_colors:
				sym_cols[sym] = _color_to_hex(symbol_colors[sym])
			color_info = {"mode": "by_symbol", "colors": sym_cols}
		ColorMode.BY_DEPTH:
			color_info = {
				"mode": "gradient",
				"start": _color_to_hex(depth_color_start),
				"end": _color_to_hex(depth_color_end)
			}

	var metadata: Dictionary = {
		"version": "2.0",
		"type": "lsystem",
		"exported_at": Time.get_datetime_string_from_system(),
		"seed": _current_seed,
		"params": {
			"axiom":      axiom_edit.text.strip_edges(),
			"rules":      rules_export,
			"angle":      angle_slider.value,
			"step":       step_slider.value,
			"iterations": int(iter_slider.value)
		},
		"colors": color_info
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()

func _color_to_hex(c: Color) -> String:
	return "#" + c.to_html(false)

# ===========================================================================
#  Папка экспорта
# ===========================================================================
func _on_open_export_folder() -> void:
	var abs_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	OS.shell_open(abs_dir)

# ===========================================================================
#  Сохранение пресета
# ===========================================================================
func _on_save_preset_pressed() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	if axiom.is_empty() or rules.is_empty():
		_set_status("Заполните аксиому и правила")
		return
	_show_name_dialog(func(preset_name: String):
		user_presets[preset_name] = {
			"axiom":      axiom,
			"rules":      rules,
			"angle":      angle_slider.value,
			"step":       step_slider.value,
			"iterations": int(iter_slider.value),
			"seed":       _current_seed
		}
		_save_user_presets()
		_populate_presets()
		for i in range(preset_selector.item_count):
			if preset_selector.get_item_text(i) == "★ " + preset_name:
				preset_selector.selected = i
				break
		_set_status("Пресет сохранён: " + preset_name)
	)

func _show_name_dialog(callback: Callable) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Имя пресета"
	dialog.ok_button_text = "Сохранить"
	var vbox := VBoxContainer.new()
	var hint_label := Label.new()
	hint_label.text = "Введите имя для пресета:"
	vbox.add_child(hint_label)
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Мой пресет"
	line_edit.custom_minimum_size.x = 250
	vbox.add_child(line_edit)
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var preset_name: String = line_edit.text.strip_edges()
		if not preset_name.is_empty():
			callback.call(preset_name)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 120))

# ===========================================================================
#  Удаление пресета
# ===========================================================================
func _on_delete_preset_pressed() -> void:
	var item_text: String = preset_selector.get_item_text(preset_selector.selected)
	if not item_text.begins_with("★ "):
		return
	var preset_name: String = item_text.substr(2)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Подтверждение"
	dialog.dialog_text = "Удалить пресет \"" + preset_name + "\"?"
	dialog.ok_button_text = "Удалить"
	dialog.confirmed.connect(func():
		user_presets.erase(preset_name)
		_save_user_presets()
		_populate_presets()
		if preset_selector.item_count > 0:
			preset_selector.selected = 0
			_on_preset_selected(0)
		_set_status("Пресет удалён: " + preset_name)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

# ===========================================================================
#  JSON пресеты
# ===========================================================================
func _save_user_presets() -> void:
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(user_presets, "\t"))
		file.close()

func _load_user_presets() -> void:
	if not FileAccess.file_exists(USER_PRESETS_PATH):
		return
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(content)
	if err == OK and json.data is Dictionary:
		user_presets = json.data