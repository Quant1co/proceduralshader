@tool
extends Control


#  Встроенные пресеты

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


#  Пути

const USER_PRESETS_PATH: String = "user://lsystem_presets.json"
const DEFAULT_EXPORT_PATH: String = "res://export/lsystem/"
const SETTINGS_PATH: String = "user://lsystem_settings.cfg"


#  Константы

const MAX_LSTRING_LENGTH: int = 500_000


#  Переменные

var user_presets: Dictionary = {}
var rule_rows: Array = []
var lines: Array[PackedVector2Array] = []
var user_scale: float = 1.0
var _last_preview_size: float = 0.0
var _current_render_size: int = 300
var custom_export_path: String = ""


#  UI-ссылки

@onready var preset_selector:        OptionButton         = $ScrollContainer/VBox/PresetSelector
@onready var axiom_edit:             LineEdit             = $ScrollContainer/VBox/AxiomEdit
@onready var rules_container:        VBoxContainer        = $ScrollContainer/VBox/RulesContainer
@onready var add_rule_button:        Button               = $ScrollContainer/VBox/AddRuleButton
@onready var angle_label:            Label                = $ScrollContainer/VBox/AngleLabel
@onready var angle_slider:           HSlider              = $ScrollContainer/VBox/AngleSlider
@onready var step_label:             Label                = $ScrollContainer/VBox/StepLabel
@onready var step_slider:            HSlider              = $ScrollContainer/VBox/StepSlider
@onready var iter_label:             Label                = $ScrollContainer/VBox/IterLabel
@onready var iter_slider:            HSlider              = $ScrollContainer/VBox/IterSlider
@onready var zoom_label:             Label                = $ScrollContainer/VBox/ZoomLabel
@onready var zoom_slider:            HSlider              = $ScrollContainer/VBox/ZoomSlider
@onready var preview_container:      SubViewportContainer = $ScrollContainer/VBox/PreviewContainer
@onready var preview_viewport:       SubViewport          = $ScrollContainer/VBox/PreviewContainer/PreviewViewport
@onready var draw_node:              Node2D               = $ScrollContainer/VBox/PreviewContainer/PreviewViewport/DrawNode
@onready var generate_btn:           Button               = $ScrollContainer/VBox/GenerateButton
@onready var export_button:          Button               = $ScrollContainer/VBox/ExportButton
@onready var export_path_button:     Button               = $ScrollContainer/VBox/ExportPathButton
@onready var open_export_folder_btn: Button               = $ScrollContainer/VBox/OpenExportFolderButton
@onready var save_preset_button:     Button               = $ScrollContainer/VBox/SavePresetButton
@onready var delete_preset_button:   Button               = $ScrollContainer/VBox/DeletePresetButton
@onready var status_label:           Label                = $ScrollContainer/VBox/StatusLabel


#  _ready

func _ready() -> void:
	_load_user_presets()
	_load_settings()
	_populate_presets()

	draw_node.draw.connect(_on_draw_node_draw)

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
		_generate()
	)

	if preset_selector.item_count > 0:
		preset_selector.selected = 0
		_on_preset_selected(0)


#  _process — квадратное превью

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


#  Путь экспорта

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


#  Выбор папки экспорта

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


#  Сохранение / загрузка настроек

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	if not custom_export_path.is_empty():
		cfg.set_value("export", "export_path", custom_export_path)
	else:
		cfg.set_value("export", "export_path", "")
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		custom_export_path = cfg.get_value("export", "export_path", "")
	_update_export_path_button()


#  Перегенерация под текущий размер

func _regenerate_for_current_size() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	if axiom.is_empty():
		return
	var rules: Dictionary = _collect_rules_from_ui()
	if rules.is_empty():
		return

	var angle: float     = angle_slider.value
	var step: float      = step_slider.value
	var iterations: int  = int(iter_slider.value)

	var lstring: String = _apply_rules(axiom, rules, iterations)
	_interpret(lstring, angle, step, _current_render_size)
	draw_node.queue_redraw()


#  Отрисовка в SubViewport

func _on_draw_node_draw() -> void:
	for line in lines:
		if line.size() >= 2:
			draw_node.draw_polyline(line, Color(0.2, 0.9, 0.3), 1.0, true)


#  Заполнение списка пресетов

func _populate_presets() -> void:
	preset_selector.clear()

	for preset_name in BUILTIN_PRESETS.keys():
		preset_selector.add_item(preset_name)

	for preset_name in user_presets.keys():
		preset_selector.add_item("★ " + preset_name)

	preset_selector.add_item("✦ Создать свой...")


#  Выбор пресета

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
		lines.clear()
		draw_node.queue_redraw()
		_set_status("")
		return

	if item_text.begins_with("★ "):
		var preset_name: String = item_text.substr(2)
		if user_presets.has(preset_name):
			_load_preset_to_ui(user_presets[preset_name])
			_set_fields_editable(true)
			_generate()
	else:
		if BUILTIN_PRESETS.has(item_text):
			_load_preset_to_ui(BUILTIN_PRESETS[item_text])
			_set_fields_editable(false)
			_generate()

	_update_delete_button_visibility()


#  Загрузка пресета в UI

func _load_preset_to_ui(preset: Dictionary) -> void:
	axiom_edit.text = preset.get("axiom", "")

	_clear_rule_rows()
	var rules: Dictionary = preset.get("rules", {})
	for symbol in rules.keys():
		_add_rule_row(symbol, rules[symbol])

	angle_slider.value = preset.get("angle", 90.0)
	step_slider.value  = preset.get("step", 5.0)
	iter_slider.value  = preset.get("iterations", 4)

	_update_labels()


#  Управление редактируемостью

func _set_fields_editable(editable: bool) -> void:
	axiom_edit.editable = editable
	add_rule_button.visible = editable
	save_preset_button.visible = editable

	for row in rule_rows:
		row["symbol"].editable = editable
		row["replacement"].editable = editable
		var remove_btn = row["row"].get_child(3)
		if remove_btn:
			remove_btn.visible = editable

func _update_delete_button_visibility() -> void:
	var item_text: String = preset_selector.get_item_text(preset_selector.selected)
	delete_preset_button.visible = item_text.begins_with("★ ")


#  Обновление меток

func _update_labels() -> void:
	angle_label.text = "Угол: %.0f°" % angle_slider.value
	step_label.text  = "Длина шага: %.1f" % step_slider.value
	iter_label.text  = "Итераций: %d" % int(iter_slider.value)
	zoom_label.text  = "Зум: %.1f" % zoom_slider.value

func _set_status(text: String) -> void:
	status_label.text = text


#  Динамические строки правил

func _add_rule_row(symbol: String = "", replacement: String = "") -> void:
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

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size.x = 32
	hbox.add_child(remove_btn)

	rules_container.add_child(hbox)

	var row_data: Dictionary = {
		"symbol":      symbol_edit,
		"replacement": replacement_edit,
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


#  Сбор правил из UI

func _collect_rules_from_ui() -> Dictionary:
	var rules: Dictionary = {}
	for row in rule_rows:
		var s: String = row["symbol"].text.strip_edges()
		var r: String = row["replacement"].text.strip_edges()
		if not s.is_empty() and not r.is_empty():
			rules[s] = r
	return rules


#  Генерация L-системы

func _generate() -> void:
	var axiom: String = axiom_edit.text.strip_edges()
	if axiom.is_empty():
		lines.clear()
		draw_node.queue_redraw()
		return

	var rules: Dictionary = _collect_rules_from_ui()
	if rules.is_empty():
		lines.clear()
		draw_node.queue_redraw()
		return

	var angle: float     = angle_slider.value
	var step: float      = step_slider.value
	var iterations: int  = int(iter_slider.value)

	var lstring: String = _apply_rules(axiom, rules, iterations)
	_interpret(lstring, angle, step, _current_render_size)
	draw_node.queue_redraw()
	_set_status("Сгенерировано: %d сегментов" % lines.size())


#  Применение правил подстановки

func _apply_rules(axiom: String, rules: Dictionary, iterations: int) -> String:
	var result: String = axiom
	for i in range(iterations):
		var next: String = ""
		for ch in result:
			next += rules.get(ch, ch)
			if next.length() > MAX_LSTRING_LENGTH:
				push_warning("[LSystem] Строка превысила %d символов, обрезка на итерации %d" % [MAX_LSTRING_LENGTH, i])
				return next
		result = next
	return result


#  Интерпретация строки — построение линий

func _interpret(lstring: String, angle_deg: float, step: float, target_size: int) -> void:
	lines.clear()

	var center: float = float(target_size) / 2.0
	var pos: Vector2  = Vector2(center, center)
	var angle: float  = -90.0
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
				stack.push_back({"pos": pos, "angle": angle, "line": current_line})
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
	_fit_lines_to_size(target_size)


#  Авто-масштабирование под заданный размер

func _fit_lines_to_size(target_size: int) -> void:
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

	var padding: float = 0.1
	var target: float  = float(target_size) * (1.0 - padding * 2.0)
	var base_scale: float   = min(target / bounds_size.x, target / bounds_size.y)
	var scale_factor: float = base_scale * user_scale

	var img_center := Vector2(float(target_size), float(target_size)) / 2.0
	var bounds_center := (min_pos + bounds_size / 2.0) * scale_factor
	var center_offset: Vector2 = img_center - bounds_center

	for i in range(lines.size()):
		for j in range(lines[i].size()):
			lines[i][j] = lines[i][j] * scale_factor + center_offset


#  Экспорт PNG

func _on_export_pressed() -> void:
	if lines.is_empty():
		_set_status("Нечего экспортировать — сначала сгенерируйте")
		return

	var abs_export_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_export_dir)

	var export_size: int = 1024
	var export_lines := _generate_lines_for_export(export_size)

	var image: Image = Image.create(export_size, export_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.05, 1.0))

	var line_color := Color(0.2, 0.9, 0.3)
	for line in export_lines:
		for k in range(line.size() - 1):
			_draw_line_on_image(image, line[k], line[k + 1], line_color)

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
	print("[LSystem] Метаданные: " + json_path)


#  Генерация линий для экспорта

func _generate_lines_for_export(img_size: int) -> Array[PackedVector2Array]:
	var axiom: String = axiom_edit.text.strip_edges()
	var rules: Dictionary = _collect_rules_from_ui()
	if axiom.is_empty() or rules.is_empty():
		return []

	var angle_val: float = angle_slider.value
	var step_val: float  = step_slider.value
	var iterations: int  = int(iter_slider.value)

	var lstring: String = _apply_rules(axiom, rules, iterations)

	var result_lines: Array[PackedVector2Array] = []
	var center: float = float(img_size) / 2.0
	var pos: Vector2  = Vector2(center, center)
	var angle: float  = -90.0
	var stack: Array   = []

	var current_line := PackedVector2Array()
	current_line.append(pos)

	for ch in lstring:
		match ch:
			"F", "G":
				var new_pos: Vector2 = pos + Vector2(
					cos(deg_to_rad(angle)) * step_val,
					sin(deg_to_rad(angle)) * step_val
				)
				current_line.append(new_pos)
				pos = new_pos
			"+":
				angle += angle_val
			"-":
				angle -= angle_val
			"[":
				stack.push_back({"pos": pos, "angle": angle, "line": current_line})
				current_line = PackedVector2Array()
				current_line.append(pos)
			"]":
				if stack.size() > 0:
					result_lines.append(current_line)
					var state: Dictionary = stack.pop_back()
					pos          = state["pos"]
					angle        = state["angle"]
					current_line = state["line"]

	result_lines.append(current_line)

	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for line in result_lines:
		for p in line:
			min_pos.x = min(min_pos.x, p.x)
			min_pos.y = min(min_pos.y, p.y)
			max_pos.x = max(max_pos.x, p.x)
			max_pos.y = max(max_pos.y, p.y)

	var bounds_size := max_pos - min_pos
	if bounds_size.x < 1.0 or bounds_size.y < 1.0:
		return result_lines

	var padding: float = 0.1
	var target: float  = float(img_size) * (1.0 - padding * 2.0)
	var scale_factor: float = min(target / bounds_size.x, target / bounds_size.y)
	var img_center := Vector2(float(img_size), float(img_size)) / 2.0
	var bounds_center := (min_pos + bounds_size / 2.0) * scale_factor
	var center_offset: Vector2 = img_center - bounds_center

	for i in range(result_lines.size()):
		for j in range(result_lines[i].size()):
			result_lines[i][j] = result_lines[i][j] * scale_factor + center_offset

	return result_lines


#  Рисование линии в Image (Брезенхэм)

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


#  Метаданные экспорта

func _export_lsystem_metadata(path: String) -> void:
	var rules: Dictionary = _collect_rules_from_ui()
	var metadata: Dictionary = {
		"version": "1.0",
		"type": "lsystem",
		"exported_at": Time.get_datetime_string_from_system(),
		"params": {
			"axiom":      axiom_edit.text.strip_edges(),
			"rules":      rules,
			"angle":      angle_slider.value,
			"step":       step_slider.value,
			"iterations": int(iter_slider.value)
		}
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()


#  Открытие папки экспорта

func _on_open_export_folder() -> void:
	var abs_dir: String = _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	OS.shell_open(abs_dir)


#  Сохранение пресета

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
			"iterations": int(iter_slider.value)
		}
		_save_user_presets()
		_populate_presets()

		for i in range(preset_selector.item_count):
			if preset_selector.get_item_text(i) == "★ " + preset_name:
				preset_selector.selected = i
				_on_preset_selected(i)
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
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 120))


#  Удаление пресета

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
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()


#  Сохранение / загрузка пользовательских пресетов

func _save_user_presets() -> void:
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(user_presets, "\t"))
		file.close()
		print("[LSystem] Пресеты сохранены: ", USER_PRESETS_PATH)

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
		print("[LSystem] Загружено пресетов: ", user_presets.size())
	else:
		push_warning("[LSystem] Не удалось загрузить пресеты: " + json.get_error_message())