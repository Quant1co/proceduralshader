@tool
extends Control

@onready var shader_selector:    OptionButton         = $ScrollContainer/MainVBox/SelectorHBox/ShaderSelector
@onready var refresh_button:     Button               = $ScrollContainer/MainVBox/SelectorHBox/RefreshButton
@onready var load_shader_button: Button               = $ScrollContainer/MainVBox/LoadShaderButton
@onready var params_container:   VBoxContainer        = $ScrollContainer/MainVBox/ParamsContainer
@onready var preview_container:  SubViewportContainer = $ScrollContainer/MainVBox/PreviewContainer
@onready var preview_viewport:   SubViewport          = $ScrollContainer/MainVBox/PreviewContainer/PreviewViewport
@onready var preview_rect:       ColorRect            = $ScrollContainer/MainVBox/PreviewContainer/PreviewViewport/PreviewRect
@onready var resolution_selector:OptionButton         = $ScrollContainer/MainVBox/ResHBox/ResolutionSelector
@onready var bake_button:        Button               = $ScrollContainer/MainVBox/BakeButton
@onready var export_path_button: Button               = $ScrollContainer/MainVBox/ExportPathButton
@onready var open_folder_button: Button               = $ScrollContainer/MainVBox/OpenFolderButton
@onready var unity_path_button:  Button               = $ScrollContainer/MainVBox/UnityPathButton
@onready var copy_to_unity_btn:  Button               = $ScrollContainer/MainVBox/CopyToUnityButton
@onready var status_label:       Label                = $ScrollContainer/MainVBox/StatusLabel

var current_shader: Shader
var current_material: ShaderMaterial
var preview_material: ShaderMaterial
var shader_inspector: ShaderInspector
var texture_exporter: TextureExporter
var param_controls: Dictionary = {}
var shader_dir: String = "res://shaders"
var unity_import_path: String = ""
var last_baked_name: String = ""
var current_shader_name: String = ""
var custom_export_path: String = ""

var bake_viewport: SubViewport
var bake_rect: ColorRect

var _last_preview_width: float = 0.0

const DEFAULT_EXPORT_PATH: String = "user://export/"
const SETTINGS_PATH: String = "user://settings.cfg"

func _ready() -> void:
	shader_inspector = ShaderInspector.new()
	texture_exporter = TextureExporter.new()

	_setup_bake_viewport()

	refresh_button.pressed.connect(_scan_shaders)
	shader_selector.item_selected.connect(_on_shader_selected)
	load_shader_button.pressed.connect(_on_load_shader_pressed)
	bake_button.pressed.connect(_on_bake_pressed)
	export_path_button.pressed.connect(_pick_export_path)
	open_folder_button.pressed.connect(_on_open_folder_pressed)
	unity_path_button.pressed.connect(_pick_unity_path)
	copy_to_unity_btn.pressed.connect(_copy_to_unity)

	_resolution_selector_add_item(256)
	_resolution_selector_add_item(512)
	_resolution_selector_add_item(1024)
	_resolution_selector_add_item(2048)
	resolution_selector.selected = 1

	_scan_shaders()
	_load_settings()

	if shader_selector.item_count > 0:
		shader_selector.selected = 0
		await get_tree().process_frame
		_on_shader_selected(0)

func _process(_delta: float) -> void:
	if preview_container == null:
		return

	var current_width: float = preview_container.size.x
	if current_width < 50.0:
		return

	if abs(current_width - _last_preview_width) > 2.0:
		_last_preview_width = current_width
		preview_container.custom_minimum_size.y = current_width


#  Текущий путь экспорта
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
	dialog.title = "Выбрать папку экспорта"
	dialog.access = 2
	dialog.dir_selected.connect(func(path: String):
		custom_export_path = path
		_update_export_path_button()
		_save_settings()
		status_label.text = "Папка экспорта: " + path
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _update_export_path_button() -> void:
	if custom_export_path.is_empty():
		export_path_button.text = "Папка экспорта: по умолчанию"
	else:
		# Показываем последние 2 части пути для краткости
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
	# Загружаем существующие настройки чтобы не потерять unity_path
	cfg.load(SETTINGS_PATH)
	if not custom_export_path.is_empty():
		cfg.set_value("export", "export_path", custom_export_path)
	else:
		# Если сброшен — удаляем ключ
		if cfg.has_section_key("export", "export_path"):
			cfg.set_value("export", "export_path", "")
	if not unity_import_path.is_empty():
		cfg.set_value("export", "unity_path", unity_import_path)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		custom_export_path = cfg.get_value("export", "export_path", "")
		unity_import_path = cfg.get_value("export", "unity_path", "")
	_update_export_path_button()
	_update_unity_button_text()


#  Bake viewport
func _setup_bake_viewport() -> void:
	bake_viewport = SubViewport.new()
	bake_viewport.size = Vector2i(512, 512)
	bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	bake_viewport.transparent_bg = false
	bake_rect = ColorRect.new()
	bake_rect.anchors_preset = Control.PRESET_FULL_RECT
	bake_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bake_viewport.add_child(bake_rect)
	add_child(bake_viewport)

func _resolution_selector_add_item(val: int) -> void:
	resolution_selector.add_item(str(val))
	resolution_selector.set_item_metadata(resolution_selector.item_count - 1, val)


#  Сканирование шейдеров
func _scan_shaders() -> void:
	shader_selector.clear()
	var dir := DirAccess.open(shader_dir)
	if dir == null:
		status_label.text = "Папка шейдеров не найдена: " + shader_dir
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gdshader"):
			var path := shader_dir + "/" + file_name
			if _is_canvas_item_shader(path):
				var display_name := file_name.get_basename()
				shader_selector.add_item(display_name)
				shader_selector.set_item_metadata(
					shader_selector.item_count - 1, path
				)
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_canvas_item_shader(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	for i in range(10):
		if file.eof_reached():
			break
		var line := file.get_line().strip_edges()
		if line.begins_with("shader_type"):
			file.close()
			return "canvas_item" in line
	file.close()
	return false


#  Загрузка шейдера
func _on_shader_selected(index: int) -> void:
	var shader_path: String = shader_selector.get_item_metadata(index)
	_load_shader(shader_path)

func _load_shader(path: String) -> void:
	current_shader = load(path)
	if current_shader == null:
		status_label.text = "Ошибка загрузки: " + path
		return

	current_material = ShaderMaterial.new()
	current_material.shader = current_shader

	var shader_name := path.get_file().get_basename()
	current_shader_name = shader_name

	var found_index: int = -1
	for i in range(shader_selector.item_count):
		if shader_selector.get_item_metadata(i) == path:
			found_index = i
			break

	if found_index == -1:
		shader_selector.add_item(shader_name)
		shader_selector.set_item_metadata(shader_selector.item_count - 1, path)
		found_index = shader_selector.item_count - 1

	shader_selector.selected = found_index

	for child in params_container.get_children():
		child.queue_free()

	var uniforms := shader_inspector.parse_shader(current_shader)

	var callback := func(name: String, value: Variant):
		if current_material:
			current_material.set_shader_parameter(name, value)
		if preview_material:
			preview_material.set_shader_parameter(name, value)

	param_controls = shader_inspector.build_controls(
		current_shader,
		uniforms,
		params_container,
		callback
	)

	for u in uniforms:
		var default_val = shader_inspector.get_default_value(current_shader, u["name"])
		if default_val != null:
			current_material.set_shader_parameter(u["name"], default_val)

	bake_rect.material = current_material
	preview_material = current_material.duplicate()
	preview_rect.material = preview_material

	for u in uniforms:
		var val = current_material.get_shader_parameter(u["name"])
		if val != null and preview_material:
			preview_material.set_shader_parameter(u["name"], val)

	status_label.text = "Загружен: " + shader_name

func _on_load_shader_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.gdshader ; Godot Shaders")
	dialog.title = "Выбрать шейдер"
	dialog.file_selected.connect(func(p: String):
		if _is_canvas_item_shader(p):
			_load_shader(p)
		else:
			status_label.text = "Ошибка: шейдер должен быть canvas_item"
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


#  Запекание
func _on_bake_pressed() -> void:
	if current_material == null:
		status_label.text = "Сначала загрузите шейдер"
		return

	bake_button.disabled = true
	status_label.text = "Запекание..."

	var shader_name := current_shader_name
	var resolution: int = resolution_selector.get_item_metadata(resolution_selector.selected)
	var params := _collect_params()
	var export_path := _get_export_path()

	var result: Dictionary = await texture_exporter.bake(
		bake_viewport,
		current_material,
		shader_name,
		resolution,
		params,
		export_path
	)

	bake_button.disabled = false

	if result.has("error"):
		status_label.text = "Ошибка: " + result["error"]
	else:
		var short_name: String = result["png_path"].get_file()
		status_label.text = "Готово! " + short_name
		last_baked_name = shader_name

func _collect_params() -> Dictionary:
	var params := {}
	if current_material == null or current_shader == null:
		return params
	for u in current_shader.get_shader_uniform_list():
		var name: String = u["name"]
		if name in ShaderInspector.HIDDEN_UNIFORMS:
			continue
		if u["type"] == TYPE_OBJECT:
			continue
		var val = current_material.get_shader_parameter(name)
		if val is Color:
			params[name] = {"r": val.r, "g": val.g, "b": val.b, "a": val.a}
		elif val is Vector2:
			params[name] = {"x": val.x, "y": val.y}
		elif val is Vector3:
			params[name] = {"x": val.x, "y": val.y, "z": val.z}
		else:
			params[name] = val
	return params


#  Открытие папки экспорта
func _on_open_folder_pressed() -> void:
	var abs_dir := _get_export_dir_absolute()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	OS.shell_open(abs_dir)


#  Unity
func _pick_unity_path() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Выбери папку Assets/ProceduralImport/Imported в Unity"
	dialog.access = 2
	dialog.dir_selected.connect(func(path: String):
		unity_import_path = path
		_update_unity_button_text()
		_save_settings()
		status_label.text = "Путь Unity сохранён"
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _update_unity_button_text() -> void:
	if unity_import_path.is_empty():
		unity_path_button.text = "Выбрать папку Unity"
	else:
		var parts := unity_import_path.split("/")
		unity_path_button.text = "Unity: ..." + parts[-1]

func _copy_to_unity() -> void:
	if unity_import_path.is_empty():
		status_label.text = "Сначала выбери папку Unity!"
		return
	if last_baked_name.is_empty():
		status_label.text = "Сначала запеки текстуру!"
		return

	var src_dir := _get_export_dir_absolute()
	var files_to_copy := [
		last_baked_name + "_albedo.png",
		last_baked_name + "_metadata.json"
	]

	var copied := 0
	for file_name in files_to_copy:
		var src: String = src_dir + file_name
		var dst: String = unity_import_path + "/" + file_name
		var err := DirAccess.copy_absolute(src, dst)
		if err == OK:
			copied += 1
		else:
			push_error("[Baker] Ошибка копирования %s: %s" % [file_name, err])

	if copied == 2:
		status_label.text = "Скопировано в Unity: " + last_baked_name
	else:
		status_label.text = "Скопировано файлов: %d/2" % copied