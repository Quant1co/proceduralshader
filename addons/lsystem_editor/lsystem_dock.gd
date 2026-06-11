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
const NODE_MERGE_THRESHOLD: float = 0.5

const DEFAULT_SYMBOL_COLORS: Dictionary = {
	"F": Color(0.2, 0.9, 0.3),
	"G": Color(0.3, 0.5, 0.9),
}

enum ColorMode { SINGLE, BY_SYMBOL, GRADIENT, BY_SEGMENT_RANGE, BY_ITERATION }

const CAT_TRUNK: int = 0
const CAT_BRANCH: int = 1
const CAT_TIP: int = 2

# ===========================================================================
#  Переменные
# ===========================================================================
var user_presets: Dictionary = {}
var rule_rows: Array = []
var segments: Array = []
var max_depth: int = 0
var user_scale: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _pan_offset_start: Vector2 = Vector2.ZERO
var _last_preview_size: float = 0.0
var _current_render_size: int = 300
var custom_export_path: String = ""
var _cached_char_data: Array = []
var _rng := RandomNumberGenerator.new()
var _current_seed: int = 0

var color_mode: int = ColorMode.SINGLE
var single_color: Color = Color(0.2, 0.9, 0.3)
var symbol_colors: Dictionary = {}
var symbol_color_rows: Array = []

var gradient: Gradient
var gradient_texture: GradientTexture1D

var segment_range_rows: Array = []

var _has_branching: bool = false
var iter_trunk_color: Color = Color(0.55, 0.27, 0.07)
var iter_branch_color: Color = Color(0.1, 0.5, 0.15)
var iter_tip_color: Color = Color(0.3, 0.9, 0.3)
var trunk_depth: int = 0
var iter_trunk_width: float = 3.0
var iter_branch_width: float = 2.0
var iter_tip_width: float = 1.0

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
@onready var pan_left_btn:             Button               = $ScrollContainer/VBox/PanRow/PanLeftBtn
@onready var pan_up_btn:               Button               = $ScrollContainer/VBox/PanRow/PanUpBtn
@onready var pan_down_btn:             Button               = $ScrollContainer/VBox/PanRow/PanDownBtn
@onready var pan_right_btn:            Button               = $ScrollContainer/VBox/PanRow/PanRightBtn
@onready var pan_reset_btn:            Button               = $ScrollContainer/VBox/PanRow/PanResetBtn
@onready var color_mode_selector:      OptionButton         = $ScrollContainer/VBox/ColorModeSelector
@onready var single_color_row:         HBoxContainer        = $ScrollContainer/VBox/SingleColorRow
@onready var single_color_picker:      ColorPickerButton    = $ScrollContainer/VBox/SingleColorRow/SingleColorPicker
@onready var symbol_colors_container:  VBoxContainer        = $ScrollContainer/VBox/SymbolColorsContainer
@onready var gradient_container:       VBoxContainer        = $ScrollContainer/VBox/GradientContainer
@onready var gradient_preview:         TextureRect          = $ScrollContainer/VBox/GradientContainer/GradientPreview
@onready var edit_gradient_button:     Button               = $ScrollContainer/VBox/GradientContainer/EditGradientButton
@onready var segment_range_info:       Label                = $ScrollContainer/VBox/SegmentRangeInfoLabel
@onready var segment_range_container:  VBoxContainer        = $ScrollContainer/VBox/SegmentRangeContainer
@onready var add_segment_range_button: Button               = $ScrollContainer/VBox/AddSegmentRangeButton
@onready var iter_info:                Label                = $ScrollContainer/VBox/IterInfoLabel
@onready var iter_color_container:     VBoxContainer        = $ScrollContainer/VBox/IterColorContainer
@onready var add_iter_color_button:    Button               = $ScrollContainer/VBox/AddIterColorButton
@onready var trunk_depth_row:          HBoxContainer        = $ScrollContainer/VBox/TrunkDepthRow
@onready var trunk_depth_spin:         SpinBox              = $ScrollContainer/VBox/TrunkDepthRow/TrunkDepthSpin
@onready var preview_container:        SubViewportContainer = $ScrollContainer/VBox/PreviewContainer
@onready var preview_viewport:         SubViewport          = $ScrollContainer/VBox/PreviewContainer/PreviewViewport
@onready var draw_node:                Node2D               = $ScrollContainer/VBox/PreviewContainer/PreviewViewport/DrawNode
@onready var generate_btn:             Button               = $ScrollContainer/VBox/GenerateButton
@onready var export_format_selector:   OptionButton         = $ScrollContainer/VBox/ExportFormatSelector
@onready var transparent_bg_check:     CheckBox             = $ScrollContainer/VBox/TransparentBgCheck
@onready var straighten_trunk_check:   CheckBox             = $ScrollContainer/VBox/StraightenTrunkCheck
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

	gradient = Gradient.new()
	gradient.set_color(0, Color(0.55, 0.27, 0.07))
	gradient.set_color(1, Color(0.2, 0.9, 0.3))
	gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_preview.texture = gradient_texture
	gradient.changed.connect(_on_gradient_changed)
	edit_gradient_button.pressed.connect(_on_edit_gradient_pressed)

	color_mode_selector.add_item("Единый цвет")
	color_mode_selector.add_item("По символам")
	color_mode_selector.add_item("Градиент")
	color_mode_selector.add_item("По диапазонам")
	color_mode_selector.add_item("По итерациям")
	color_mode_selector.item_selected.connect(_on_color_mode_changed)

	single_color_picker.color_changed.connect(func(c: Color):
		single_color = c
		draw_node.queue_redraw()
	)

	_update_color_ui_visibility()
	add_segment_range_button.pressed.connect(_on_add_segment_range_pressed)

	trunk_depth_spin.value_changed.connect(func(v: float):
		trunk_depth = int(v)
		if not _cached_char_data.is_empty():
			_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
			draw_node.queue_redraw()
	)

	preset_selector.item_selected.connect(_on_preset_selected)
	generate_btn.pressed.connect(_generate)
	add_rule_button.pressed.connect(func(): _add_rule_row())
	save_preset_button.pressed.connect(_on_save_preset_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_pressed)

	# --- Экспорт ---
	export_format_selector.add_item("PNG изображение")
	export_format_selector.add_item("Path2D (.tscn)")
	export_format_selector.add_item("Path3D (.tscn)")
	export_format_selector.add_item("Граф (.json)")
	export_format_selector.add_item("Граф (.tres)")
	export_format_selector.item_selected.connect(_on_export_format_changed)
	export_button.pressed.connect(_on_export_pressed_unified)
	_on_export_format_changed(0)

	export_path_button.pressed.connect(_pick_export_path)
	open_export_folder_btn.pressed.connect(_on_open_export_folder)

	angle_slider.value_changed.connect(func(v: float): angle_label.text = "Угол: %.0f°" % v)
	step_slider.value_changed.connect(func(v: float): step_label.text = "Длина шага: %.1f" % v)
	iter_slider.value_changed.connect(func(v: float): iter_label.text = "Итераций: %d" % int(v))
	zoom_slider.value_changed.connect(func(v: float):
		user_scale = v
		zoom_label.text = "Зум: %.2f" % v
		_refresh_preview()
	)

	var pan_step_fn := func():
		return max(20.0, 50.0 / user_scale)

	pan_left_btn.pressed.connect(func():
		pan_offset.x += pan_step_fn.call(); _refresh_preview()
	)
	pan_right_btn.pressed.connect(func():
		pan_offset.x -= pan_step_fn.call(); _refresh_preview()
	)
	pan_up_btn.pressed.connect(func():
		pan_offset.y += pan_step_fn.call(); _refresh_preview()
	)
	pan_down_btn.pressed.connect(func():
		pan_offset.y -= pan_step_fn.call(); _refresh_preview()
	)
	pan_reset_btn.pressed.connect(func():
		pan_offset = Vector2.ZERO; _refresh_preview()
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
#  Зум колёсиком + панорамирование мышью
# ===========================================================================
func _input(event: InputEvent) -> void:
	if preview_container == null:
		return
	var mouse_pos: Vector2 = preview_container.get_local_mouse_position()
	var rect := Rect2(Vector2.ZERO, preview_container.size)

	if event is InputEventMouseButton and rect.has_point(mouse_pos):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_slider.value = zoom_slider.value * 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_slider.value = zoom_slider.value / 1.1
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.global_position
				_pan_offset_start = pan_offset
			else:
				_is_panning = false

	if event is InputEventMouseMotion and _is_panning:
		var delta: Vector2 = event.global_position - _pan_start
		pan_offset = _pan_offset_start + delta
		_refresh_preview()

# ===========================================================================
#  Формат экспорта
# ===========================================================================
func _on_export_format_changed(index: int) -> void:
	transparent_bg_check.visible = (index == 0)
	straighten_trunk_check.visible = (index == 2)

func _on_export_pressed_unified() -> void:
	match export_format_selector.selected:
		0: _on_export_pressed()
		1: _on_export_path2d_pressed()
		2: _on_export_path3d_pressed()
		3: _on_export_graph_pressed()
		4: _on_export_graph_res_pressed()

# ===========================================================================
#  Режимы окраски
# ===========================================================================
func _on_color_mode_changed(index: int) -> void:
	color_mode = index
	_update_color_ui_visibility()
	if color_mode == ColorMode.BY_SYMBOL:
		_rebuild_symbol_color_rows()
	if color_mode == ColorMode.BY_SEGMENT_RANGE:
		_update_segment_range_info()
	if color_mode == ColorMode.BY_ITERATION:
		_build_iter_color_ui()
	draw_node.queue_redraw()

func _update_color_ui_visibility() -> void:
	single_color_row.visible          = (color_mode == ColorMode.SINGLE)
	symbol_colors_container.visible   = (color_mode == ColorMode.BY_SYMBOL)
	gradient_container.visible        = (color_mode == ColorMode.GRADIENT)
	segment_range_info.visible        = (color_mode == ColorMode.BY_SEGMENT_RANGE)
	segment_range_container.visible   = (color_mode == ColorMode.BY_SEGMENT_RANGE)
	add_segment_range_button.visible  = (color_mode == ColorMode.BY_SEGMENT_RANGE)
	iter_info.visible                 = (color_mode == ColorMode.BY_ITERATION)
	iter_color_container.visible      = (color_mode == ColorMode.BY_ITERATION)
	add_iter_color_button.visible     = false
	trunk_depth_row.visible           = (color_mode == ColorMode.BY_ITERATION)

func _on_gradient_changed() -> void:
	draw_node.queue_redraw()

func _on_edit_gradient_pressed() -> void:
	EditorInterface.inspect_object(gradient)

# ===========================================================================
#  Цвета по символам
# ===========================================================================
func _rebuild_symbol_color_rows() -> void:
	for row_data in symbol_color_rows:
		if is_instance_valid(row_data["row"]): row_data["row"].queue_free()
	symbol_color_rows.clear()
	var symbols := _collect_drawing_symbols()
	for sym in symbols:
		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = sym + ":"; label.custom_minimum_size.x = 80
		hbox.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(60, 30)
		picker.color = symbol_colors.get(sym, DEFAULT_SYMBOL_COLORS.get(sym, Color.WHITE))
		hbox.add_child(picker)
		symbol_colors[sym] = picker.color
		var captured_sym := sym
		picker.color_changed.connect(func(c: Color):
			symbol_colors[captured_sym] = c; draw_node.queue_redraw()
		)
		symbol_colors_container.add_child(hbox)
		symbol_color_rows.append({"symbol": sym, "picker": picker, "row": hbox})

func _collect_drawing_symbols() -> Array[String]:
	var symbols: Array[String] = []
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	var all_chars: String = axiom
	for key in rules.keys():
		for rule_data in rules[key]: all_chars += rule_data["replacement"]
	for ch in all_chars:
		if ch in DRAWING_SYMBOLS and ch not in symbols: symbols.append(ch)
	return symbols

# ===========================================================================
#  Диапазоны по сегментам
# ===========================================================================
func _update_segment_range_info() -> void:
	if segments.is_empty():
		segment_range_info.text = "Сегментов: 0 (сначала сгенерируйте)"
	else:
		segment_range_info.text = "Сегментов: %d. Диапазоны в %% (0–100):" % segments.size()

func _on_add_segment_range_pressed() -> void:
	_add_segment_range_row(0, 100, Color.WHITE)

func _add_segment_range_row(from_pct: int = 0, to_pct: int = 100, color: Color = Color.WHITE) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var from_label := Label.new()
	from_label.text = "От%:"; from_label.custom_minimum_size.x = 30; hbox.add_child(from_label)
	var from_spin := SpinBox.new()
	from_spin.min_value = 0; from_spin.max_value = 100; from_spin.suffix = "%"
	from_spin.value = from_pct; from_spin.custom_minimum_size.x = 70; hbox.add_child(from_spin)
	var to_label := Label.new()
	to_label.text = "До%:"; to_label.custom_minimum_size.x = 30; hbox.add_child(to_label)
	var to_spin := SpinBox.new()
	to_spin.min_value = 0; to_spin.max_value = 100; to_spin.suffix = "%"
	to_spin.value = to_pct; to_spin.custom_minimum_size.x = 70; hbox.add_child(to_spin)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(40, 28); picker.color = color; hbox.add_child(picker)
	var remove_btn := Button.new()
	remove_btn.text = "✕"; remove_btn.custom_minimum_size.x = 28; hbox.add_child(remove_btn)
	segment_range_container.add_child(hbox)
	var row_data: Dictionary = {"from": from_spin, "to": to_spin, "picker": picker, "row": hbox}
	segment_range_rows.append(row_data)
	from_spin.value_changed.connect(func(_v: float): draw_node.queue_redraw())
	to_spin.value_changed.connect(func(_v: float): draw_node.queue_redraw())
	picker.color_changed.connect(func(_c: Color): draw_node.queue_redraw())
	remove_btn.pressed.connect(func():
		segment_range_rows.erase(row_data); hbox.queue_free(); draw_node.queue_redraw()
	)

func _get_color_for_segment_index(seg_index: int, total: int) -> Color:
	if total <= 0: return single_color
	var pct: float = (float(seg_index) / float(total)) * 100.0
	for i in range(segment_range_rows.size() - 1, -1, -1):
		var row_data: Dictionary = segment_range_rows[i]
		if not is_instance_valid(row_data["row"]): continue
		if pct >= row_data["from"].value and pct <= row_data["to"].value:
			return row_data["picker"].color
	return single_color

# ===========================================================================
#  По итерациям — ствол / ветки / кончики
# ===========================================================================
func _build_iter_color_ui() -> void:
	for child in iter_color_container.get_children(): child.queue_free()
	if segments.is_empty():
		iter_info.text = "Сначала сгенерируйте кривую"; return
	if not _has_branching:
		iter_info.text = "Нет ветвлений — все сегменты одной категории"
		_add_iter_picker_row("Все:", iter_trunk_color, iter_trunk_width,
			func(c: Color): iter_trunk_color = c; draw_node.queue_redraw(),
			func(w: float): iter_trunk_width = w; draw_node.queue_redraw())
		return
	iter_info.text = "Ствол / Ветки / Кончики:"
	_add_iter_picker_row("Ствол:", iter_trunk_color, iter_trunk_width,
		func(c: Color): iter_trunk_color = c; draw_node.queue_redraw(),
		func(w: float): iter_trunk_width = w; draw_node.queue_redraw())
	_add_iter_picker_row("Ветки:", iter_branch_color, iter_branch_width,
		func(c: Color): iter_branch_color = c; draw_node.queue_redraw(),
		func(w: float): iter_branch_width = w; draw_node.queue_redraw())
	_add_iter_picker_row("Кончики:", iter_tip_color, iter_tip_width,
		func(c: Color): iter_tip_color = c; draw_node.queue_redraw(),
		func(w: float): iter_tip_width = w; draw_node.queue_redraw())

func _add_iter_picker_row(label_text: String, color: Color, width: float, on_color_change: Callable, on_width_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text; label.custom_minimum_size.x = 65; hbox.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(40, 28); picker.color = color; hbox.add_child(picker)
	picker.color_changed.connect(on_color_change)
	var width_label := Label.new()
	width_label.text = " ш:"; hbox.add_child(width_label)
	var width_spin := SpinBox.new()
	width_spin.min_value = 0.5; width_spin.max_value = 10.0; width_spin.step = 0.5
	width_spin.value = width; width_spin.custom_minimum_size.x = 60; hbox.add_child(width_spin)
	width_spin.value_changed.connect(on_width_change)
	iter_color_container.add_child(hbox)

func _get_color_for_category(category: int) -> Color:
	match category:
		CAT_TRUNK:  return iter_trunk_color
		CAT_BRANCH: return iter_branch_color
		CAT_TIP:    return iter_tip_color
	return single_color

func _get_width_for_category(category: int) -> float:
	match category:
		CAT_TRUNK:  return iter_trunk_width
		CAT_BRANCH: return iter_branch_width
		CAT_TIP:    return iter_tip_width
	return 1.0

# ===========================================================================
#  Классификация сегментов
# ===========================================================================
func _classify_segments(char_data: Array) -> Array[int]:
	var seg_info: Array[int] = []
	var nesting: int = 0
	var branch_passages_at_zero: int = 0
	var was_in_branch: bool = false
	for i in range(char_data.size()):
		var ch: String = char_data[i]["char"]
		match ch:
			"F", "G":
				if nesting == 0 and branch_passages_at_zero <= trunk_depth:
					seg_info.append(CAT_TRUNK)
				elif nesting == 0:
					var has_child: bool = _look_ahead_for_branch(char_data, i + 1, nesting)
					seg_info.append(CAT_BRANCH if has_child else CAT_TIP)
				else:
					var has_child: bool = _look_ahead_for_branch(char_data, i + 1, nesting)
					seg_info.append(CAT_BRANCH if has_child else CAT_TIP)
			"[":
				nesting += 1; was_in_branch = true
			"]":
				nesting -= 1
				if nesting < 0: nesting = 0
				if nesting == 0 and was_in_branch:
					branch_passages_at_zero += 1; was_in_branch = false
	return seg_info

func _look_ahead_for_branch(char_data: Array, start_idx: int, current_nesting: int) -> bool:
	var n: int = current_nesting
	for i in range(start_idx, char_data.size()):
		var ch: String = char_data[i]["char"]
		match ch:
			"[": return true
			"]":
				n -= 1
				if n < current_nesting: return false
	return false

# ===========================================================================
#  Цвет сегмента
# ===========================================================================
func _get_segment_color(seg: Dictionary, seg_index: int = 0) -> Color:
	match color_mode:
		ColorMode.SINGLE:           return single_color
		ColorMode.BY_SYMBOL:        return symbol_colors.get(seg["symbol"], single_color)
		ColorMode.GRADIENT:
			var t: float = 0.0
			if segments.size() > 1: t = float(seg_index) / float(segments.size() - 1)
			return gradient.sample(t)
		ColorMode.BY_SEGMENT_RANGE: return _get_color_for_segment_index(seg_index, segments.size())
		ColorMode.BY_ITERATION:     return _get_color_for_category(seg.get("category", CAT_TRUNK))
	return single_color

func _get_export_segment_color(seg: Dictionary, seg_index: int, total: int) -> Color:
	match color_mode:
		ColorMode.SINGLE:           return single_color
		ColorMode.BY_SYMBOL:        return symbol_colors.get(seg["symbol"], single_color)
		ColorMode.GRADIENT:
			var t: float = 0.0
			if total > 1: t = float(seg_index) / float(total - 1)
			return gradient.sample(t)
		ColorMode.BY_SEGMENT_RANGE: return _get_color_for_segment_index(seg_index, total)
		ColorMode.BY_ITERATION:     return _get_color_for_category(seg.get("category", CAT_TRUNK))
	return single_color

# ===========================================================================
#  Экспорт / настройки путей
# ===========================================================================
func _get_export_path() -> String:
	return custom_export_path if not custom_export_path.is_empty() else DEFAULT_EXPORT_PATH

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

func _to_resource_save_path(path: String) -> String:
	var localized := ProjectSettings.localize_path(path)
	if localized.begins_with("res://") or localized.begins_with("user://"):
		return localized
	return path

func _pick_export_path() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Выбрать папку экспорта L-систем"; dialog.access = 2
	dialog.dir_selected.connect(func(path: String):
		custom_export_path = path; _update_export_path_button(); _save_settings()
		_set_status("Папка экспорта: " + path); dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _update_export_path_button() -> void:
	if custom_export_path.is_empty():
		export_path_button.text = "Папка экспорта: по умолчанию"
	else:
		var parts := custom_export_path.replace("\\", "/").split("/")
		var short: String = parts[-2] + "/" + parts[-1] if parts.size() >= 2 else custom_export_path
		export_path_button.text = "Экспорт: .../" + short

func _save_settings() -> void:
	var cfg := ConfigFile.new(); cfg.load(SETTINGS_PATH)
	cfg.set_value("export", "export_path", custom_export_path if not custom_export_path.is_empty() else "")
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		custom_export_path = cfg.get_value("export", "export_path", "")
	_update_export_path_button()

func _regenerate_for_current_size() -> void:
	if _cached_char_data.is_empty(): return
	_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
	draw_node.queue_redraw()

func _refresh_preview() -> void:
	if _cached_char_data.is_empty(): return
	_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
	draw_node.queue_redraw()

# ===========================================================================
#  Отрисовка
# ===========================================================================
func _on_draw_node_draw() -> void:
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var color: Color = _get_segment_color(seg, i)
		var width: float = 1.0
		if color_mode == ColorMode.BY_ITERATION:
			width = _get_width_for_category(seg.get("category", CAT_TRUNK))
		draw_node.draw_line(seg["from"], seg["to"], color, width, true)

# ===========================================================================
#  Пресеты
# ===========================================================================
func _populate_presets() -> void:
	preset_selector.clear()
	for preset_name in BUILTIN_PRESETS.keys(): preset_selector.add_item(preset_name)
	for preset_name in user_presets.keys(): preset_selector.add_item("★ " + preset_name)
	preset_selector.add_item("✦ Создать свой...")

func _on_preset_selected(index: int) -> void:
	var item_text: String = preset_selector.get_item_text(index)
	if item_text == "✦ Создать свой...":
		axiom_edit.text = ""; _clear_rule_rows(); _add_rule_row()
		angle_slider.value = 90.0; step_slider.value = 5.0; iter_slider.value = 3
		_set_fields_editable(true); _update_delete_button_visibility()
		segments.clear(); _cached_char_data.clear(); draw_node.queue_redraw()
		_set_status(""); return
	if item_text.begins_with("★ "):
		var preset_name: String = item_text.substr(2)
		if user_presets.has(preset_name):
			_load_preset_to_ui(user_presets[preset_name]); _set_fields_editable(true)
			_current_seed = int(user_presets[preset_name].get("seed", randi()))
			_generate_with_seed(_current_seed)
	else:
		if BUILTIN_PRESETS.has(item_text):
			_load_preset_to_ui(BUILTIN_PRESETS[item_text]); _set_fields_editable(false); _generate()
	_update_delete_button_visibility()

func _load_preset_to_ui(preset: Dictionary) -> void:
	axiom_edit.text = preset.get("axiom", ""); _clear_rule_rows()
	var rules = preset.get("rules", {})
	for symbol in rules.keys():
		var value = rules[symbol]
		if value is String: _add_rule_row(symbol, value, 1.0)
		elif value is Array:
			for rule_data in value:
				var repl: String = rule_data.get("replacement", "") if rule_data is Dictionary else str(rule_data)
				var w: float = rule_data.get("weight", 1.0) if rule_data is Dictionary else 1.0
				_add_rule_row(symbol, repl, w)
		else: _add_rule_row(symbol, str(value), 1.0)
	angle_slider.value = preset.get("angle", 90.0)
	step_slider.value = preset.get("step", 5.0)
	iter_slider.value = preset.get("iterations", 4)
	_update_labels()

func _set_fields_editable(editable: bool) -> void:
	axiom_edit.editable = editable; add_rule_button.visible = editable; save_preset_button.visible = editable
	for row in rule_rows:
		row["symbol"].editable = editable; row["replacement"].editable = editable; row["weight"].editable = editable
		var remove_btn = row["row"].get_child(row["row"].get_child_count() - 1)
		if remove_btn is Button: remove_btn.visible = editable

func _update_delete_button_visibility() -> void:
	delete_preset_button.visible = preset_selector.get_item_text(preset_selector.selected).begins_with("★ ")

func _update_labels() -> void:
	angle_label.text = "Угол: %.0f°" % angle_slider.value
	step_label.text = "Длина шага: %.1f" % step_slider.value
	iter_label.text = "Итераций: %d" % int(iter_slider.value)
	zoom_label.text = "Зум: %.2f" % zoom_slider.value

func _set_status(text: String) -> void:
	status_label.text = text

# ===========================================================================
#  Правила
# ===========================================================================
func _add_rule_row(symbol: String = "", replacement: String = "", weight: float = 1.0) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var symbol_edit := LineEdit.new()
	symbol_edit.custom_minimum_size.x = 35; symbol_edit.max_length = 1
	symbol_edit.text = symbol; symbol_edit.placeholder_text = "F"
	symbol_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER; hbox.add_child(symbol_edit)
	var arrow := Label.new(); arrow.text = " → "; hbox.add_child(arrow)
	var replacement_edit := LineEdit.new()
	replacement_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement_edit.text = replacement; replacement_edit.placeholder_text = "F+F-F-F+F"
	hbox.add_child(replacement_edit)
	var weight_label := Label.new(); weight_label.text = " вес:"; hbox.add_child(weight_label)
	var weight_spin := SpinBox.new()
	weight_spin.min_value = 0.01; weight_spin.max_value = 100.0; weight_spin.step = 0.01
	weight_spin.value = weight; weight_spin.custom_minimum_size.x = 65; hbox.add_child(weight_spin)
	var remove_btn := Button.new(); remove_btn.text = "✕"; remove_btn.custom_minimum_size.x = 32
	hbox.add_child(remove_btn)
	rules_container.add_child(hbox)
	var row_data: Dictionary = {"symbol": symbol_edit, "replacement": replacement_edit, "weight": weight_spin, "row": hbox}
	rule_rows.append(row_data)
	remove_btn.pressed.connect(func(): rule_rows.erase(row_data); hbox.queue_free())

func _clear_rule_rows() -> void:
	for row in rule_rows:
		if is_instance_valid(row["row"]): row["row"].queue_free()
	rule_rows.clear()

func _collect_rules_from_ui() -> Dictionary:
	var rules: Dictionary = {}
	for row in rule_rows:
		var s: String = row["symbol"].text.strip_edges()
		var r: String = row["replacement"].text.strip_edges()
		var w: float = row["weight"].value
		if not s.is_empty() and not r.is_empty():
			if not rules.has(s): rules[s] = []
			rules[s].append({"replacement": r, "weight": w})
	return rules

func _pick_weighted_rule(rule_list: Array) -> String:
	if rule_list.size() == 1: return rule_list[0]["replacement"]
	var total_weight: float = 0.0
	for rule in rule_list: total_weight += rule["weight"]
	var roll: float = _rng.randf() * total_weight
	var cumulative: float = 0.0
	for rule in rule_list:
		cumulative += rule["weight"]
		if roll <= cumulative: return rule["replacement"]
	return rule_list[-1]["replacement"]

# ===========================================================================
#  Генерация
# ===========================================================================
func _generate() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	if axiom.is_empty():
		segments.clear(); _cached_char_data.clear(); draw_node.queue_redraw(); return
	var rules: Dictionary = _collect_rules_from_ui()
	if rules.is_empty():
		segments.clear(); _cached_char_data.clear(); draw_node.queue_redraw(); return
	_current_seed = randi()
	_generate_with_seed(_current_seed)

func _generate_with_seed(seed_value: int) -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	if axiom.is_empty() or rules.is_empty(): return
	_rng.seed = seed_value
	_cached_char_data = _apply_rules_with_depth(axiom, rules, int(iter_slider.value))
	_interpret_colored(_cached_char_data, angle_slider.value, step_slider.value, _current_render_size)
	draw_node.queue_redraw()
	if color_mode == ColorMode.BY_SYMBOL: _rebuild_symbol_color_rows()
	if color_mode == ColorMode.BY_SEGMENT_RANGE: _update_segment_range_info()
	if color_mode == ColorMode.BY_ITERATION: _build_iter_color_ui()
	_set_status("Сгенерировано: %d сегментов" % segments.size())

func _apply_rules_with_depth(axiom: String, rules: Dictionary, iterations: int) -> Array:
	var result: Array = []
	for ch in axiom: result.append({"char": ch, "depth": 0})
	for iter_idx in range(iterations):
		var next: Array = []
		for item in result:
			var ch: String = item["char"]
			if rules.has(ch):
				var chosen: String = _pick_weighted_rule(rules[ch])
				for new_ch in chosen: next.append({"char": new_ch, "depth": iter_idx + 1})
			else: next.append(item)
			if next.size() > MAX_LSTRING_LENGTH:
				push_warning("[LSystem] Превышен лимит"); return next
		result = next
	return result

# ===========================================================================
#  Интерпретация (превью)
# ===========================================================================
func _interpret_colored(char_data: Array, angle_deg: float, step: float, target_size: int) -> void:
	segments.clear(); max_depth = 0; _has_branching = false
	for item in char_data:
		if item["char"] == "[": _has_branching = true; break
	var categories: Array[int] = _classify_segments(char_data)
	var pos: Vector2 = Vector2.ZERO; var angle: float = -90.0
	var stack: Array = []; var seg_idx: int = 0
	var raw_segs: Array = []
	for item in char_data:
		var ch: String = item["char"]; var depth: int = item["depth"]
		if depth > max_depth: max_depth = depth
		match ch:
			"F", "G":
				var new_pos := pos + Vector2(cos(deg_to_rad(angle)) * step, sin(deg_to_rad(angle)) * step)
				var cat: int = categories[seg_idx] if seg_idx < categories.size() else CAT_TRUNK
				raw_segs.append({"from": pos, "to": new_pos, "symbol": ch, "depth": depth, "category": cat})
				pos = new_pos; seg_idx += 1
			"+": angle += angle_deg
			"-": angle -= angle_deg
			"[": stack.push_back({"pos": pos, "angle": angle})
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back(); pos = state["pos"]; angle = state["angle"]
	if raw_segs.is_empty(): return
	var center := Vector2(float(target_size), float(target_size)) / 2.0
	var min_pos := Vector2.INF; var max_pos := -Vector2.INF
	for seg in raw_segs:
		for key in ["from", "to"]:
			var p: Vector2 = seg[key]
			min_pos.x = min(min_pos.x, p.x); min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x); max_pos.y = max(max_pos.y, p.y)
	var bounds_center := (min_pos + max_pos) / 2.0
	var offset := center - bounds_center * user_scale + pan_offset
	for seg in raw_segs:
		segments.append({
			"from": seg["from"] * user_scale + offset,
			"to": seg["to"] * user_scale + offset,
			"symbol": seg["symbol"], "depth": seg["depth"], "category": seg["category"]
		})

# ===========================================================================
#  Сырая интерпретация (для графа)
# ===========================================================================
func _interpret_raw(char_data: Array, angle_deg: float, step: float) -> Array:
	var raw_segments: Array = []
	var pos: Vector2 = Vector2.ZERO; var angle: float = -90.0; var stack: Array = []
	var categories: Array[int] = _classify_segments(char_data); var seg_idx: int = 0
	for item in char_data:
		var ch: String = item["char"]; var depth: int = item["depth"]
		match ch:
			"F", "G":
				var new_pos := pos + Vector2(cos(deg_to_rad(angle)) * step, sin(deg_to_rad(angle)) * step)
				var cat: int = categories[seg_idx] if seg_idx < categories.size() else CAT_TRUNK
				raw_segments.append({"from": pos, "to": new_pos, "symbol": ch, "depth": depth, "category": cat})
				pos = new_pos; seg_idx += 1
			"+": angle += angle_deg
			"-": angle -= angle_deg
			"[": stack.push_back({"pos": pos, "angle": angle})
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back(); pos = state["pos"]; angle = state["angle"]
	return raw_segments

# ===========================================================================
#  Извлечение веток с иерархией
# ===========================================================================
func _extract_branch_tree(char_data: Array, angle_deg: float, step: float) -> Array:
	var branch_id_counter: int = 0
	var pos: Vector2 = Vector2.ZERO; var angle: float = -90.0
	var root_branch: Dictionary = {"points": [pos], "children": [], "id": branch_id_counter}
	branch_id_counter += 1
	var current_branch: Dictionary = root_branch
	var stack: Array = []
	for item in char_data:
		var ch: String = item["char"]
		match ch:
			"F", "G":
				var new_pos: Vector2 = pos + Vector2(cos(deg_to_rad(angle)) * step, sin(deg_to_rad(angle)) * step)
				current_branch["points"].append(new_pos)
				pos = new_pos
			"+": angle += angle_deg
			"-": angle -= angle_deg
			"[":
				stack.push_back({"pos": pos, "angle": angle, "branch": current_branch})
				var child_branch: Dictionary = {"points": [pos], "children": [], "id": branch_id_counter}
				branch_id_counter += 1
				current_branch["children"].append(child_branch)
				current_branch = child_branch
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back()
					pos = state["pos"]; angle = state["angle"]
					current_branch = state["branch"]
	return [root_branch]

func _build_path2d_tree(branch: Dictionary, parent_node: Node2D, owner: Node2D) -> void:
	var points: Array = branch["points"]
	if points.size() >= 2:
		var path_node := Path2D.new()
		path_node.name = "Branch_%d" % branch["id"]
		var curve := Curve2D.new()
		for point in points: curve.add_point(point)
		path_node.curve = curve
		parent_node.add_child(path_node)
		path_node.owner = owner
		for child in branch["children"]:
			_build_path2d_tree(child, path_node, owner)
	else:
		for child in branch["children"]:
			_build_path2d_tree(child, parent_node, owner)

func _collect_all_points_from_tree(branch: Dictionary) -> Array:
	var all_points: Array = []
	for p in branch["points"]: all_points.append(p)
	for child in branch["children"]:
		all_points.append_array(_collect_all_points_from_tree(child))
	return all_points

# ===========================================================================
#  Экспорт Path3D с 3D-вращением веток
# ===========================================================================
func _build_path3d_tree(branch: Dictionary, parent_node: Node3D, owner: Node3D, norm_scale: float, center_2d: Vector2, rng: RandomNumberGenerator = null, parent_tip: Vector3 = Vector3.ZERO, parent_rotation: float = 0.0, is_root: bool = true) -> void:
	var points: Array = branch["points"]
	if points.size() < 2:
		for child in branch["children"]:
			_build_path3d_tree(child, parent_node, owner, norm_scale, center_2d, rng, parent_tip, parent_rotation, false)
		return

	var raw_points: Array[Vector3] = []
	for point in points:
		var p: Vector2 = point
		var p3 := Vector3((p.x - center_2d.x) * norm_scale, -(p.y - center_2d.y) * norm_scale, 0.0)
		raw_points.append(p3)

	var branch_origin: Vector3 = raw_points[0]
	var local_points: Array[Vector3] = []
	for p3 in raw_points:
		local_points.append(p3 - branch_origin)

	var rotated_points: Array[Vector3] = []
	for lp in local_points:
		var rotated := Vector3(
			lp.x * cos(parent_rotation) + lp.z * sin(parent_rotation),
			lp.y,
			-lp.x * sin(parent_rotation) + lp.z * cos(parent_rotation)
		)
		rotated_points.append(rotated)

	var actual_origin: Vector3
	if is_root:
		actual_origin = branch_origin
	else:
		actual_origin = parent_tip

	var final_points: Array[Vector3] = []
	for rp in rotated_points:
		var fp: Vector3 = actual_origin + rp
		if final_points.is_empty() or final_points[-1].distance_to(fp) > 0.001:
			final_points.append(fp)

	# --- Выпрямление ствола (если включено) ---
	if is_root and straighten_trunk_check.button_pressed and final_points.size() >= 2:
		var root_x: float = final_points[0].x
		var root_z: float = final_points[0].z
		for i in range(final_points.size()):
			final_points[i] = Vector3(root_x, final_points[i].y, root_z)

	if final_points.size() < 2:
		for child in branch["children"]:
			_build_path3d_tree(child, parent_node, owner, norm_scale, center_2d, rng, parent_tip, parent_rotation, false)
		return

	var path_node := Path3D.new()
	path_node.name = "Branch_%d" % branch["id"]
	var curve := Curve3D.new()
	for p3 in final_points:
		curve.add_point(p3)
	path_node.curve = curve
	parent_node.add_child(path_node)
	path_node.owner = owner

	var this_tip: Vector3 = final_points[-1]

	var child_count: int = branch["children"].size()
	for i in range(child_count):
		var child_angle: float = parent_rotation
		if rng and child_count > 0:
			child_angle += (float(i) / float(child_count)) * TAU + rng.randf_range(-0.3, 0.3)
		_build_path3d_tree(branch["children"][i], path_node, owner, norm_scale, center_2d, rng, this_tip, child_angle, false)

# ===========================================================================
#  Экспорт Path2D
# ===========================================================================
func _on_export_path2d_pressed() -> void:
	if _cached_char_data.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте"); return
	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)
	var tree: Array = _extract_branch_tree(_cached_char_data, angle_slider.value, step_slider.value)
	if tree.is_empty():
		_set_status("Нет веток для экспорта"); return
	var root := Node2D.new()
	root.name = "LSystemPaths"
	for branch in tree: _build_path2d_tree(branch, root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free(); _set_status("Ошибка упаковки Path2D"); return
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var save_path: String = _to_resource_save_path(abs_export_dir + "lsystem_path2d_" + timestamp + ".tscn")
	if ResourceSaver.save(packed, save_path) != OK:
		root.free(); _set_status("Ошибка сохранения Path2D"); return
	root.free()
	if save_path.begins_with("res://"): EditorInterface.get_resource_filesystem().scan()
	_set_status("Path2D экспортирован (с иерархией)")

# ===========================================================================
#  Экспорт Path3D (3D с вращением)
# ===========================================================================
func _on_export_path3d_pressed() -> void:
	if _cached_char_data.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте"); return
	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)
	var tree: Array = _extract_branch_tree(_cached_char_data, angle_slider.value, step_slider.value)
	if tree.is_empty():
		_set_status("Нет веток для экспорта"); return
	var all_points: Array = []
	for branch in tree: all_points.append_array(_collect_all_points_from_tree(branch))
	var all_min := Vector2.INF; var all_max := -Vector2.INF
	for point in all_points:
		var p: Vector2 = point
		all_min.x = min(all_min.x, p.x); all_min.y = min(all_min.y, p.y)
		all_max.x = max(all_max.x, p.x); all_max.y = max(all_max.y, p.y)
	var bounds_size := all_max - all_min
	var max_extent: float = max(bounds_size.x, bounds_size.y)
	if max_extent < 0.001: max_extent = 1.0
	var norm_scale: float = 10.0 / max_extent
	var center_2d := (all_min + all_max) / 2.0
	var root := Node3D.new()
	root.name = "LSystemPaths3D"
	var export_rng := RandomNumberGenerator.new()
	export_rng.seed = _current_seed
	for branch in tree:
		_build_path3d_tree(branch, root, root, norm_scale, center_2d, export_rng, Vector3.ZERO, 0.0, true)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free(); _set_status("Ошибка упаковки Path3D"); return
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var save_path: String = _to_resource_save_path(abs_export_dir + "lsystem_path3d_" + timestamp + ".tscn")
	if ResourceSaver.save(packed, save_path) != OK:
		root.free(); _set_status("Ошибка сохранения Path3D"); return
	root.free()
	if save_path.begins_with("res://"): EditorInterface.get_resource_filesystem().scan()
	_set_status("Path3D экспортирован (3D с иерархией)")

# ===========================================================================
#  Экспорт графа (JSON)
# ===========================================================================
func _on_export_graph_pressed() -> void:
	if _cached_char_data.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте"); return
	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)
	var raw_segments: Array = _interpret_raw(_cached_char_data, angle_slider.value, step_slider.value)
	if raw_segments.is_empty():
		_set_status("Нет сегментов для графа"); return
	var graph: Dictionary = _build_graph(raw_segments)
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var json_path: String = abs_export_dir + "lsystem_graph_" + timestamp + ".json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null: _set_status("Ошибка записи JSON"); return
	file.store_string(JSON.stringify(_graph_to_json(graph), "\t")); file.close()
	_set_status("Граф экспортирован (.json)")

# ===========================================================================
#  Экспорт графа (.tres)
# ===========================================================================
func _on_export_graph_res_pressed() -> void:
	if _cached_char_data.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте"); return
	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)
	var raw_segments: Array = _interpret_raw(_cached_char_data, angle_slider.value, step_slider.value)
	if raw_segments.is_empty():
		_set_status("Нет сегментов для графа"); return
	var graph: Dictionary = _build_graph(raw_segments)
	var res := LSystemGraphResource.new()
	var packed_nodes := PackedVector2Array()
	for node_pos in graph["nodes"]: packed_nodes.append(node_pos)
	res.nodes = packed_nodes
	var edge_list: Array[Vector2i] = []
	var sym_list := PackedStringArray(); var depth_list := PackedInt32Array()
	for e in graph["edges"]:
		edge_list.append(Vector2i(e["from"], e["to"]))
		sym_list.append(e["symbol"]); depth_list.append(e["depth"])
	res.edges = edge_list; res.edge_symbols = sym_list; res.edge_depths = depth_list
	var adj_list: Array[PackedInt32Array] = []
	for i in range(graph["nodes"].size()):
		if graph["adjacency"].has(i):
			var neighbors := PackedInt32Array()
			for n in graph["adjacency"][i]: neighbors.append(n)
			adj_list.append(neighbors)
		else: adj_list.append(PackedInt32Array())
	res.adjacency = adj_list
	res.axiom = axiom_edit.text.strip_edges(); res.angle = angle_slider.value
	res.step = step_slider.value; res.iterations = int(iter_slider.value)
	res.generation_seed = _current_seed
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var save_path: String = _to_resource_save_path(abs_export_dir + "lsystem_graph_" + timestamp + ".tres")
	if ResourceSaver.save(res, save_path) != OK:
		_set_status("Ошибка сохранения .tres"); return
	if save_path.begins_with("res://"): EditorInterface.get_resource_filesystem().scan()
	_set_status("Граф-ресурс экспортирован (.tres)")

# ===========================================================================
#  Построение графа
# ===========================================================================
func _build_graph(raw_segments: Array) -> Dictionary:
	var nodes: Array = []; var node_ids: Dictionary = {}
	var edges: Array = []; var adjacency: Dictionary = {}
	for seg in raw_segments:
		var from_id: int = _get_or_create_node(seg["from"], nodes, node_ids)
		var to_id: int = _get_or_create_node(seg["to"], nodes, node_ids)
		edges.append({"from": from_id, "to": to_id, "symbol": seg["symbol"], "depth": seg["depth"]})
		if not adjacency.has(from_id): adjacency[from_id] = []
		if to_id not in adjacency[from_id]: adjacency[from_id].append(to_id)
		if not adjacency.has(to_id): adjacency[to_id] = []
		if from_id not in adjacency[to_id]: adjacency[to_id].append(from_id)
	return {"nodes": nodes, "edges": edges, "adjacency": adjacency}

func _get_or_create_node(pos: Vector2, nodes: Array, node_ids: Dictionary) -> int:
	var key: String = "%.2f,%.2f" % [pos.x, pos.y]
	if node_ids.has(key): return node_ids[key]
	for i in range(nodes.size()):
		if (nodes[i] as Vector2).distance_to(pos) < NODE_MERGE_THRESHOLD:
			node_ids[key] = i; return i
	var new_id: int = nodes.size()
	nodes.append(pos); node_ids[key] = new_id; return new_id

func _graph_to_json(graph: Dictionary) -> Dictionary:
	var json_nodes: Array = []
	for i in range(graph["nodes"].size()):
		var v: Vector2 = graph["nodes"][i]
		json_nodes.append({"id": i, "x": snappedf(v.x, 0.01), "y": snappedf(v.y, 0.01)})
	var json_edges: Array = []
	for e in graph["edges"]:
		json_edges.append({"from": e["from"], "to": e["to"], "symbol": e["symbol"], "depth": e["depth"]})
	var json_adjacency: Dictionary = {}
	for key in graph["adjacency"]: json_adjacency[str(key)] = graph["adjacency"][key]
	return {
		"version": "1.0", "type": "lsystem_graph",
		"exported_at": Time.get_datetime_string_from_system(), "seed": _current_seed,
		"params": {"axiom": axiom_edit.text.strip_edges(), "angle": angle_slider.value, "step": step_slider.value, "iterations": int(iter_slider.value)},
		"node_count": graph["nodes"].size(), "edge_count": graph["edges"].size(),
		"nodes": json_nodes, "edges": json_edges, "adjacency": json_adjacency
	}

# ===========================================================================
#  Экспорт PNG (с автоподгонкой)
# ===========================================================================
func _on_export_pressed() -> void:
	if segments.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте"); return
	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)
	var export_size: int = 1024
	var export_segments := _generate_segments_for_export(export_size)
	var image: Image = Image.create(export_size, export_size, false, Image.FORMAT_RGBA8)
	if transparent_bg_check.button_pressed:
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
	else:
		image.fill(Color(0.05, 0.05, 0.05, 1.0))
	var total: int = export_segments.size()
	for i in range(total):
		var seg: Dictionary = export_segments[i]
		var color: Color = _get_export_segment_color(seg, i, total)
		var width: float = 1.0
		if color_mode == ColorMode.BY_ITERATION:
			width = _get_width_for_category(seg.get("category", CAT_TRUNK))
		_draw_thick_line_on_image(image, seg["from"], seg["to"], color, int(max(width, 1.0)))
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_name: String = "lsystem_" + timestamp
	if image.save_png(abs_export_dir + file_name + ".png") != OK:
		_set_status("Ошибка сохранения PNG"); return
	_export_lsystem_metadata(abs_export_dir + file_name + ".json")
	_set_status("Экспортировано: " + file_name)

func _generate_segments_for_export(img_size: int) -> Array:
	if _cached_char_data.is_empty(): return []
	var export_segments: Array = []
	var center: float = float(img_size) / 2.0
	var pos: Vector2 = Vector2(center, center); var angle: float = -90.0; var stack: Array = []
	var categories: Array[int] = _classify_segments(_cached_char_data); var seg_idx: int = 0
	for item in _cached_char_data:
		var ch: String = item["char"]; var depth: int = item["depth"]
		match ch:
			"F", "G":
				var new_pos := pos + Vector2(cos(deg_to_rad(angle)) * step_slider.value, sin(deg_to_rad(angle)) * step_slider.value)
				var cat: int = categories[seg_idx] if seg_idx < categories.size() else CAT_TRUNK
				export_segments.append({"from": pos, "to": new_pos, "symbol": ch, "depth": depth, "category": cat})
				pos = new_pos; seg_idx += 1
			"+": angle += angle_slider.value
			"-": angle -= angle_slider.value
			"[": stack.push_back({"pos": pos, "angle": angle})
			"]":
				if stack.size() > 0:
					var state: Dictionary = stack.pop_back(); pos = state["pos"]; angle = state["angle"]
	if export_segments.is_empty(): return []
	var min_pos := Vector2.INF; var max_pos := -Vector2.INF
	for seg in export_segments:
		for key in ["from", "to"]:
			var p: Vector2 = seg[key]
			min_pos.x = min(min_pos.x, p.x); min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x); max_pos.y = max(max_pos.y, p.y)
	var bounds_size := max_pos - min_pos
	if bounds_size.x < 1.0 or bounds_size.y < 1.0: return export_segments
	var target: float = float(img_size) * 0.8
	var scale_factor: float = min(target / bounds_size.x, target / bounds_size.y)
	var img_center := Vector2(float(img_size), float(img_size)) / 2.0
	var center_offset: Vector2 = img_center - (min_pos + bounds_size / 2.0) * scale_factor
	for seg in export_segments:
		seg["from"] = seg["from"] * scale_factor + center_offset
		seg["to"] = seg["to"] * scale_factor + center_offset
	return export_segments

# ===========================================================================
#  Брезенхэм
# ===========================================================================
func _draw_line_on_image(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var x0: int = int(round(from.x)); var y0: int = int(round(from.y))
	var x1: int = int(round(to.x)); var y1: int = int(round(to.y))
	var dx: int = abs(x1 - x0); var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1; var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy; var w: int = image.get_width(); var h: int = image.get_height()
	while true:
		if x0 >= 0 and x0 < w and y0 >= 0 and y0 < h: image.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1: break
		var e2: int = 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy

func _draw_thick_line_on_image(image: Image, from: Vector2, to: Vector2, color: Color, thickness: int) -> void:
	if thickness <= 1: _draw_line_on_image(image, from, to, color); return
	var half: int = thickness / 2
	for offset_x in range(-half, half + 1):
		for offset_y in range(-half, half + 1):
			if offset_x * offset_x + offset_y * offset_y <= half * half:
				_draw_line_on_image(image, from + Vector2(offset_x, offset_y), to + Vector2(offset_x, offset_y), color)

# ===========================================================================
#  Метаданные
# ===========================================================================
func _export_lsystem_metadata(path: String) -> void:
	var rules: Dictionary = _collect_rules_from_ui()
	var rules_export: Dictionary = {}
	for symbol in rules.keys():
		var export_list: Array = []
		for rule_data in rules[symbol]:
			export_list.append({"replacement": rule_data["replacement"], "weight": rule_data["weight"]})
		rules_export[symbol] = export_list
	var color_info: Dictionary = {}
	match color_mode:
		ColorMode.SINGLE:
			color_info = {"mode": "single", "color": _color_to_hex(single_color)}
		ColorMode.BY_SYMBOL:
			var sym_cols: Dictionary = {}
			for sym in symbol_colors: sym_cols[sym] = _color_to_hex(symbol_colors[sym])
			color_info = {"mode": "by_symbol", "colors": sym_cols}
		ColorMode.GRADIENT:
			var pts: Array = []
			for idx in range(gradient.get_point_count()):
				pts.append({"offset": gradient.get_offset(idx), "color": _color_to_hex(gradient.get_color(idx))})
			color_info = {"mode": "gradient", "points": pts}
		ColorMode.BY_SEGMENT_RANGE:
			var ranges: Array = []
			for row_data in segment_range_rows:
				if is_instance_valid(row_data["row"]):
					ranges.append({"from_pct": int(row_data["from"].value), "to_pct": int(row_data["to"].value), "color": _color_to_hex(row_data["picker"].color)})
			color_info = {"mode": "by_segment_range", "ranges": ranges}
		ColorMode.BY_ITERATION:
			color_info = {
				"mode": "by_iteration",
				"trunk": _color_to_hex(iter_trunk_color), "branch": _color_to_hex(iter_branch_color), "tip": _color_to_hex(iter_tip_color),
				"trunk_width": iter_trunk_width, "branch_width": iter_branch_width, "tip_width": iter_tip_width,
				"trunk_depth": trunk_depth
			}
	var metadata: Dictionary = {
		"version": "3.1", "type": "lsystem",
		"exported_at": Time.get_datetime_string_from_system(), "seed": _current_seed,
		"params": {"axiom": axiom_edit.text.strip_edges(), "rules": rules_export, "angle": angle_slider.value, "step": step_slider.value, "iterations": int(iter_slider.value)},
		"colors": color_info
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(metadata, "\t")); file.close()

func _color_to_hex(c: Color) -> String:
	return "#" + c.to_html(false)

# ===========================================================================
#  Папка экспорта
# ===========================================================================
func _on_open_export_folder() -> void:
	DirAccess.make_dir_recursive_absolute(_get_export_dir_absolute())
	OS.shell_open(_get_export_dir_absolute())

# ===========================================================================
#  Пресеты — сохранение / удаление
# ===========================================================================
func _on_save_preset_pressed() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	if axiom.is_empty() or rules.is_empty():
		_set_status("Заполните аксиому и правила"); return
	_show_name_dialog(func(preset_name: String):
		user_presets[preset_name] = {"axiom": axiom, "rules": rules, "angle": angle_slider.value, "step": step_slider.value, "iterations": int(iter_slider.value), "seed": _current_seed}
		_save_user_presets(); _populate_presets()
		for i in range(preset_selector.item_count):
			if preset_selector.get_item_text(i) == "★ " + preset_name:
				preset_selector.selected = i; break
		_set_status("Пресет сохранён: " + preset_name)
	)

func _show_name_dialog(callback: Callable) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Имя пресета"; dialog.ok_button_text = "Сохранить"
	var vbox := VBoxContainer.new()
	var hint_label := Label.new(); hint_label.text = "Введите имя для пресета:"; vbox.add_child(hint_label)
	var line_edit := LineEdit.new(); line_edit.placeholder_text = "Мой пресет"; line_edit.custom_minimum_size.x = 250; vbox.add_child(line_edit)
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var pn: String = line_edit.text.strip_edges()
		if not pn.is_empty(): callback.call(pn)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered(Vector2i(320, 120))

func _on_delete_preset_pressed() -> void:
	var item_text: String = preset_selector.get_item_text(preset_selector.selected)
	if not item_text.begins_with("★ "): return
	var preset_name: String = item_text.substr(2)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Подтверждение"
	dialog.dialog_text = "Удалить пресет \"" + preset_name + "\"?"
	dialog.ok_button_text = "Удалить"
	dialog.confirmed.connect(func():
		user_presets.erase(preset_name); _save_user_presets(); _populate_presets()
		if preset_selector.item_count > 0: preset_selector.selected = 0; _on_preset_selected(0)
		_set_status("Пресет удалён: " + preset_name); dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

func _save_user_presets() -> void:
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(user_presets, "\t")); file.close()

func _load_user_presets() -> void:
	if not FileAccess.file_exists(USER_PRESETS_PATH): return
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.READ)
	if file == null: return
	var content: String = file.get_as_text(); file.close()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary: user_presets = json.data