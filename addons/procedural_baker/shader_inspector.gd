@tool
class_name ShaderInspector
extends RefCounted

const HIDDEN_UNIFORMS: Array[String] = ["baking_mode"]

func parse_shader(shader: Shader) -> Array[Dictionary]:
	var uniforms := shader.get_shader_uniform_list()
	var result: Array[Dictionary] = []

	for u in uniforms:
		var name: String = u["name"]
		if name in HIDDEN_UNIFORMS:
			continue

		var info: Dictionary = {
			"name": name,
			"type": u["type"],
			"hint": u["hint"],
			"hint_string": u["hint_string"],
		}

		if u["hint"] == PROPERTY_HINT_RANGE:
			info["range"] = _parse_range_hint(u["hint_string"])

		result.append(info)

	return result

func _parse_range_hint(hint_string: String) -> Dictionary:
	var parts := hint_string.split(",")
	var result: Dictionary = {"min": 0.0, "max": 1.0, "step": 0.01}
	if parts.size() >= 1:
		result["min"] = float(parts[0])
	if parts.size() >= 2:
		result["max"] = float(parts[1])
	if parts.size() >= 3:
		result["step"] = float(parts[2])
	return result

func get_default_value(shader: Shader, uniform_name: String) -> Variant:
	return RenderingServer.shader_get_parameter_default(shader.get_rid(), uniform_name)

func build_controls(
	shader: Shader,
	uniforms: Array[Dictionary],
	container: VBoxContainer,
	callback: Callable
) -> Dictionary:
	var controls: Dictionary = {}

	for u in uniforms:
		var name: String = u["name"]
		var type: int = u["type"]
		var default_val = get_default_value(shader, name)

		var ctrl: Control = null

		match type:
			TYPE_FLOAT:
				if u.has("range"):
					ctrl = _build_slider(name, u["range"], default_val if default_val is float else u["range"]["min"], callback)
				else:
					ctrl = _build_spinbox(name, default_val if default_val is float else 0.0, callback)

			TYPE_INT:
				ctrl = _build_int_spinbox(name, default_val if default_val is int else 0, callback)

			TYPE_BOOL:
				ctrl = _build_checkbox(name, default_val if default_val is bool else false, callback)

			TYPE_COLOR:
				ctrl = _build_color_picker(name, default_val if default_val is Color else Color.WHITE, callback)

			TYPE_VECTOR2:
				ctrl = _build_vec2_controls(name, default_val if default_val is Vector2 else Vector2.ZERO, callback)

			TYPE_VECTOR3:
				ctrl = _build_vec3_controls(name, default_val if default_val is Vector3 else Vector3.ZERO, callback)

			TYPE_OBJECT:
				ctrl = _build_texture_selector(name, callback)

		if ctrl != null:
			container.add_child(ctrl)
			controls[name] = ctrl

	return controls

func _build_slider(name: String, range: Dictionary, default_val: float, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = range["min"]
	slider.max_value = range["max"]
	slider.step = range["step"]
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%.2f" % default_val
	value_label.custom_minimum_size.x = 50
	hbox.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%.2f" % v
		callback.call(name, v)
	)

	return hbox

func _build_spinbox(name: String, default_val: float, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = -10000
	spin.max_value = 10000
	spin.step = 0.01
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)

	spin.value_changed.connect(func(v: float):
		callback.call(name, v)
	)

	return hbox

func _build_int_spinbox(name: String, default_val: int, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = -10000
	spin.max_value = 10000
	spin.step = 1
	spin.rounded = true
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)

	spin.value_changed.connect(func(v: float):
		callback.call(name, int(v))
	)

	return hbox

func _build_checkbox(name: String, default_val: bool, callback: Callable) -> Control:
	var check := CheckBox.new()
	check.text = name
	check.button_pressed = default_val
	check.toggled.connect(func(v: bool):
		callback.call(name, v)
	)
	return check

func _build_color_picker(name: String, default_val: Color, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = default_val
	picker.custom_minimum_size = Vector2(60, 30)
	hbox.add_child(picker)

	picker.color_changed.connect(func(c: Color):
		callback.call(name, c)
	)

	return hbox

func _build_vec2_controls(name: String, default_val: Vector2, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var spin_x := SpinBox.new()
	spin_x.min_value = -10000
	spin_x.max_value = 10000
	spin_x.step = 0.01
	spin_x.value = default_val.x
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin_x)

	var spin_y := SpinBox.new()
	spin_y.min_value = -10000
	spin_y.max_value = 10000
	spin_y.step = 0.01
	spin_y.value = default_val.y
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin_y)

	spin_x.value_changed.connect(func(v: float):
		callback.call(name, Vector2(v, spin_y.value))
	)
	spin_y.value_changed.connect(func(v: float):
		callback.call(name, Vector2(spin_x.value, v))
	)

	return hbox

func _build_vec3_controls(name: String, default_val: Vector3, callback: Callable) -> Control:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = name + ":"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	var spin_x := SpinBox.new()
	spin_x.min_value = -10000
	spin_x.max_value = 10000
	spin_x.step = 0.01
	spin_x.value = default_val.x
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin_x)

	var spin_y := SpinBox.new()
	spin_y.min_value = -10000
	spin_y.max_value = 10000
	spin_y.step = 0.01
	spin_y.value = default_val.y
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin_y)

	var spin_z := SpinBox.new()
	spin_z.min_value = -10000
	spin_z.max_value = 10000
	spin_z.step = 0.01
	spin_z.value = default_val.z
	spin_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin_z)

	spin_x.value_changed.connect(func(v: float):
		callback.call(name, Vector3(v, spin_y.value, spin_z.value))
	)
	spin_y.value_changed.connect(func(v: float):
		callback.call(name, Vector3(spin_x.value, v, spin_z.value))
	)
	spin_z.value_changed.connect(func(v: float):
		callback.call(name, Vector3(spin_x.value, spin_y.value, v))
	)

	return hbox

func _build_texture_selector(name: String, callback: Callable) -> Control:
	var vbox := VBoxContainer.new()

	var label := Label.new()
	label.text = name + " (текстура):"
	vbox.add_child(label)

	var option := OptionButton.new()
	option.add_item("Шум Perlin")
	option.add_item("Шум Cellular")
	option.add_item("Шум Simplex")
	option.add_item("Шум Value")
	option.add_item("Из файла...")
	vbox.add_child(option)

	var tex := _create_noise_texture(FastNoiseLite.TYPE_PERLIN)
	callback.call(name, tex)

	option.item_selected.connect(func(index: int):
		match index:
			0: callback.call(name, _create_noise_texture(FastNoiseLite.TYPE_PERLIN))
			1: callback.call(name, _create_noise_texture(FastNoiseLite.TYPE_CELLULAR))
			2: callback.call(name, _create_noise_texture(FastNoiseLite.TYPE_SIMPLEX))
			3: callback.call(name, _create_noise_texture(FastNoiseLite.TYPE_VALUE))
			4: _open_texture_file_dialog(name, callback)
	)

	return vbox

func _create_noise_texture(type: FastNoiseLite.NoiseType, freq: float = 0.05) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = type
	noise.frequency = freq
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	return tex

func _open_texture_file_dialog(name: String, callback: Callable) -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.png ; PNG Textures")
	dialog.add_filter("*.jpg ; JPG Textures")
	dialog.add_filter("*.jpeg ; JPEG Textures")
	dialog.add_filter("*.svg ; SVG Textures")
	dialog.add_filter("*.tres ; Godot Resources")
	dialog.title = "Выбрать текстуру для " + name
	dialog.file_selected.connect(func(path: String):
		var tex := load(path) as Texture2D
		if tex != null:
			callback.call(name, tex)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))
