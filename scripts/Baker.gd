extends Node

@onready var bake_viewport:     SubViewport        = $BakeViewport
@onready var bake_rect:         ColorRect          = $BakeViewport/BakeRect
@onready var preview_rect:      ColorRect          = $PreviewContainer/PreviewViewport/PreviewRect
@onready var shader_selector:   OptionButton       = $UI/MainPanel/VBox/ShaderSelector
@onready var scale_slider:      HSlider            = $UI/MainPanel/VBox/ScaleSlider
@onready var scale_label:       Label              = $UI/MainPanel/VBox/ScaleLabel
@onready var threshold_slider:  HSlider            = $UI/MainPanel/VBox/ThresholdSlider
@onready var threshold_label:   Label              = $UI/MainPanel/VBox/ThresholdLabel
@onready var color1_picker:     ColorPickerButton  = $UI/MainPanel/VBox/ColorPicker1
@onready var color2_picker:     ColorPickerButton  = $UI/MainPanel/VBox/ColorPicker2
@onready var bake_button:       Button             = $UI/MainPanel/VBox/BakeButton
@onready var open_folder_btn:   Button             = $UI/MainPanel/VBox/OpenFolderButton
@onready var unity_path_btn:    Button             = $UI/MainPanel/VBox/UnityPathButton
@onready var copy_to_unity_btn: Button             = $UI/MainPanel/VBox/CopyToUnityButton
@onready var status_label:      Label              = $UI/MainPanel/VBox/StatusLabel

const SHADERS: Dictionary = {
	"cloud":   "res://shaders/cloud_shader.gdshader",
	"stone":   "res://shaders/stone_shader.gdshader",
	"asphalt": "res://shaders/asphalt_shader.gdshader",
	"fractal": "res://shaders/fractal_shader.gdshader",
}

const DEFAULT_SCALE: Dictionary = {
	"cloud":   4.0,
	"stone":   8.0,
	"asphalt": 12.0,
	"fractal": 2.5,
}

const EXPORT_PATH: String = "user://export/"

var unity_import_path: String = ""
var last_baked_shader: String = ""
var current_material: ShaderMaterial
var perlin_tex: NoiseTexture2D
var cell_tex:   NoiseTexture2D

func _ready() -> void:
	bake_viewport.size = Vector2i(512, 512)
	bake_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bake_viewport.transparent_bg = false

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EXPORT_PATH)
	)

	perlin_tex = _create_noise_texture(FastNoiseLite.TYPE_PERLIN, 0.05)
	cell_tex   = _create_noise_texture(FastNoiseLite.TYPE_CELLULAR, 0.05)

	for shader_name in SHADERS.keys():
		shader_selector.add_item(shader_name)

	bake_button.pressed.connect(_on_bake_pressed)
	open_folder_btn.pressed.connect(_on_open_folder_pressed)
	shader_selector.item_selected.connect(_on_shader_selected)
	scale_slider.value_changed.connect(_on_scale_changed)
	threshold_slider.value_changed.connect(_on_threshold_changed)
	color1_picker.color_changed.connect(_on_color_changed)
	color2_picker.color_changed.connect(_on_color_changed)
	unity_path_btn.pressed.connect(_pick_unity_path)
	copy_to_unity_btn.pressed.connect(_copy_to_unity)

	_load_unity_path()
	_update_unity_button_text()

	_load_shader(0)
	preview_rect.material = current_material.duplicate()

func _create_noise_texture(
		type: FastNoiseLite.NoiseType,
		freq: float = 0.05) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = type
	noise.frequency  = freq
	var tex := NoiseTexture2D.new()
	tex.noise    = noise
	tex.width    = 512
	tex.height   = 512
	tex.seamless = true
	return tex

func _on_shader_selected(index: int) -> void:
	_load_shader(index)

func _load_shader(index: int) -> void:
	var shader_name: String = shader_selector.get_item_text(index)
	var shader_path: String = SHADERS[shader_name]

	var shader: Shader = load(shader_path)
	if shader == null:
		status_label.text = "Ошибка: не найден шейдер " + shader_name
		return

	current_material = ShaderMaterial.new()
	current_material.shader = shader

	scale_slider.value = DEFAULT_SCALE.get(shader_name, 4.0)
	scale_label.text = "Масштаб: %.1f" % scale_slider.value

	_assign_noise_textures(shader_name)
	_update_shader_params()

	bake_rect.material = current_material
	preview_rect.material = current_material.duplicate()
	_assign_noise_textures_preview(shader_name)
	status_label.text  = "Шейдер загружен: " + shader_name

func _assign_noise_textures(shader_name: String) -> void:
	match shader_name:
		"cloud":
			current_material.set_shader_parameter("perlin_noise", perlin_tex)
			current_material.set_shader_parameter("cell_noise",   cell_tex)
		"stone", "asphalt":
			current_material.set_shader_parameter("noise_texture", perlin_tex)
		"fractal":
			pass

func _assign_noise_textures_preview(shader_name: String) -> void:
	match shader_name:
		"cloud":
			preview_rect.material.set_shader_parameter("perlin_noise", perlin_tex)
			preview_rect.material.set_shader_parameter("cell_noise",   cell_tex)
		"stone", "asphalt":
			preview_rect.material.set_shader_parameter("noise_texture", perlin_tex)
		"fractal":
			pass

func _on_scale_changed(value: float) -> void:
	scale_label.text = "Масштаб: %.1f" % value
	_update_shader_params()

func _on_threshold_changed(value: float) -> void:
	threshold_label.text = "Порог: %.2f" % value
	_update_shader_params()

func _on_color_changed(_color: Color) -> void:
	_update_shader_params()

func _update_shader_params() -> void:
	if current_material == null:
		return
	current_material.set_shader_parameter("scale",        scale_slider.value)
	current_material.set_shader_parameter("threshold",    threshold_slider.value)
	current_material.set_shader_parameter("color1",       color1_picker.color)
	current_material.set_shader_parameter("color2",       color2_picker.color)
	current_material.set_shader_parameter("baking_mode",  false)

	if preview_rect.material != null:
		preview_rect.material.set_shader_parameter("scale",        scale_slider.value)
		preview_rect.material.set_shader_parameter("threshold",    threshold_slider.value)
		preview_rect.material.set_shader_parameter("color1",       color1_picker.color)
		preview_rect.material.set_shader_parameter("color2",       color2_picker.color)
		preview_rect.material.set_shader_parameter("baking_mode",  false)

func _on_bake_pressed() -> void:
	status_label.text      = "Запекание..."
	bake_button.disabled   = true

	await get_tree().process_frame
	await get_tree().process_frame

	await _bake_current_shader()

	bake_button.disabled = false

func _bake_current_shader() -> void:
	var shader_name: String = shader_selector.get_item_text(shader_selector.selected)

	current_material.set_shader_parameter("baking_mode", true)

	await get_tree().process_frame
	await get_tree().process_frame

	var image: Image = bake_viewport.get_texture().get_image()
	if image == null:
		status_label.text    = "Ошибка: не удалось получить изображение из Viewport"
		current_material.set_shader_parameter("baking_mode", false)
		return

	image.flip_y()
	image.convert(Image.FORMAT_RGB8)

	var file_name: String = shader_name + "_albedo.png"
	var export_dir: String = ProjectSettings.globalize_path(EXPORT_PATH)
	var file_path: String  = export_dir + file_name

	var err: Error = image.save_png(file_path)
	if err != OK:
		status_label.text = "Ошибка сохранения PNG: " + str(err)
		current_material.set_shader_parameter("baking_mode", false)
		return

	_export_metadata(shader_name, file_name)

	current_material.set_shader_parameter("baking_mode", false)

	status_label.text = "Готово! Сохранено: " + file_path
	last_baked_shader = shader_name

func _export_metadata(shader_name: String, albedo_file: String) -> void:
	var export_dir: String = ProjectSettings.globalize_path(EXPORT_PATH)

	var metadata: Dictionary = {
		"version":       "1.0",
		"exported_at":   Time.get_datetime_string_from_system(),
		"material_name": shader_name,
		"textures": {
			"albedo": albedo_file,
		},
		"params": {
			"scale":      scale_slider.value,
			"threshold":  threshold_slider.value,
			"roughness":  0.5,
			"specular":   0.0,
			"wave_speed": 1.0,
		}
	}

	var json_string: String = JSON.stringify(metadata, "\t")
	var meta_path: String   = export_dir + shader_name + "_metadata.json"

	var file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[Baker] Метаданные сохранены: ", meta_path)
	else:
		push_error("[Baker] Не удалось записать метаданные: " + meta_path)

func _on_open_folder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(EXPORT_PATH))

func _pick_unity_path() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode  = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title      = "Выбери папку Assets/ProceduralImport/Imported в Unity"
	dialog.access     = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String) -> void:
		unity_import_path = path
		_update_unity_button_text()
		var cfg := ConfigFile.new()
		cfg.set_value("export", "unity_path", path)
		cfg.save("user://settings.cfg")
		status_label.text = "Путь Unity сохранён"
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _load_unity_path() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		unity_import_path = cfg.get_value("export", "unity_path", "")

func _update_unity_button_text() -> void:
	if unity_import_path.is_empty():
		unity_path_btn.text = "Выбрать папку Unity"
	else:
		var parts := unity_import_path.split("/")
		unity_path_btn.text = "Unity: ..." + parts[-1]

func _copy_to_unity() -> void:
	if unity_import_path.is_empty():
		status_label.text = "Сначала выбери папку Unity!"
		return
	if last_baked_shader.is_empty():
		status_label.text = "Сначала запеки текстуру!"
		return

	var src_dir := ProjectSettings.globalize_path(EXPORT_PATH)
	var files_to_copy := [
		last_baked_shader + "_albedo.png",
		last_baked_shader + "_metadata.json"
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
		status_label.text = "Скопировано в Unity: " + last_baked_shader
	else:
		status_label.text = "Скопировано файлов: %d/2" % copied
