extends Node2D

# =======================================================================
#  Демо: L-System текстуры в системах частиц
#  Показывает применение текстур, сгенерированных в L-System Editor,
#  в качестве частиц для визуальных эффектов видеоигр.
# =======================================================================

# --- UI ---
@onready var effect_selector: OptionButton = $UI/VBox/EffectSelector
@onready var spawn_button: Button          = $UI/VBox/SpawnButton
@onready var clear_button: Button          = $UI/VBox/ClearButton
@onready var bg_toggle_button: Button      = $UI/VBox/BgToggleButton
@onready var info_label: Label             = $UI/VBox/InfoLabel
@onready var hint_label: Label             = $UI/VBox/HintLabel
@onready var effects_root: Node2D         = $EffectsRoot
@onready var background: ColorRect         = $Background

# --- Настройки текстур ---
@export_file("*.png") var snowflake_texture_path: String = "res://demo/particles/textures/snowflake.png"
@export_file("*.png") var magic_rune_texture_path: String = "res://demo/particles/textures/magic_rune.png"
@export_file("*.png") var arcane_star_texture_path: String = "res://demo/particles/textures/arcane_star.png"
@export_file("*.png") var mystic_spiral_texture_path: String = "res://demo/particles/textures/mystic_spiral.png"

# --- Загруженные текстуры ---
var _textures: Dictionary = {}

# --- Камера ---
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _camera_start: Vector2 = Vector2.ZERO
@onready var camera: Camera2D = $Camera2D

# --- Фон ---
var _dark_bg: bool = true

# =======================================================================
#  Определения эффектов
# =======================================================================
enum Effect {
	SNOWFALL,
	MAGIC_AURA,
	ARCANE_EXPLOSION,
	MYSTIC_VORTEX,
	RUNE_TRAIL
}

const EFFECT_NAMES: Array[String] = [
	"❄ Снегопад",
	"✦ Магическая аура",
	"✦ Арканный взрыв",
	"✦ Мистический вихрь",
	"✦ Руновый след",
]

const EFFECT_DESCRIPTIONS: Array[String] = [
	"Снежинки Коха падают с неба — классический зимний эффект",
	"Магические руны вращаются вокруг точки — эффект заклинания",
	"Арканные звёзды разлетаются из центра — эффект взрыва магии",
	"Фрактальные спирали закручиваются в вихрь — эффект портала",
	"Руны появляются за курсором — эффект магического следа",
]

# =======================================================================
#  _ready
# =======================================================================
func _ready() -> void:
	_load_textures()

	for effect_name in EFFECT_NAMES:
		effect_selector.add_item(effect_name)
	effect_selector.selected = 0
	effect_selector.item_selected.connect(_on_effect_selected)

	spawn_button.pressed.connect(_on_spawn_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	bg_toggle_button.pressed.connect(_on_bg_toggle)

	_on_effect_selected(0)
	_update_bg_button_text()

func _load_textures() -> void:
	_textures["snowflake"] = _try_load_texture(snowflake_texture_path, "snowflake")
	_textures["magic_rune"] = _try_load_texture(magic_rune_texture_path, "magic_rune")
	_textures["arcane_star"] = _try_load_texture(arcane_star_texture_path, "arcane_star")
	_textures["mystic_spiral"] = _try_load_texture(mystic_spiral_texture_path, "mystic_spiral")

func _try_load_texture(path: String, name: String) -> Texture2D:
	if path.is_empty():
		push_warning("[ParticleDemo] Путь к текстуре '%s' не задан" % name)
		return _create_fallback_texture()

	# Загружаем изображение вручную для контроля фильтрации
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		# Пробуем через стандартный load
		var tex = load(path)
		if tex is Texture2D:
			return tex
		push_warning("[ParticleDemo] Не удалось загрузить '%s', используется заглушка" % path)
		return _create_fallback_texture()

	# Генерируем мипмапы для корректного отображения при уменьшении
	img.generate_mipmaps()

	var tex := ImageTexture.create_from_image(img)
	return tex

func _create_fallback_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in range(64):
		img.set_pixel(32, i, Color.WHITE)
		img.set_pixel(i, 32, Color.WHITE)
	return ImageTexture.create_from_image(img)

# =======================================================================
#  UI обработчики
# =======================================================================
func _on_effect_selected(index: int) -> void:
	info_label.text = EFFECT_DESCRIPTIONS[index]

func _on_spawn_pressed() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = camera.position

	match effect_selector.selected:
		Effect.SNOWFALL:
			_spawn_snowfall(center, viewport_size)
		Effect.MAGIC_AURA:
			_spawn_magic_aura(center)
		Effect.ARCANE_EXPLOSION:
			_spawn_arcane_explosion(center)
		Effect.MYSTIC_VORTEX:
			_spawn_mystic_vortex(center)
		Effect.RUNE_TRAIL:
			hint_label.text = "Двигайте мышь — руны появляются за курсором!"
			_spawn_rune_trail(center)

func _on_clear_pressed() -> void:
	for child in effects_root.get_children():
		child.queue_free()
	hint_label.text = ""

# =======================================================================
#  Переключение фона
# =======================================================================
func _on_bg_toggle() -> void:
	_dark_bg = not _dark_bg
	if _dark_bg:
		background.color = Color(0.05, 0.05, 0.1, 1.0)
	else:
		background.color = Color(0.85, 0.85, 0.9, 1.0)
	_update_bg_button_text()

func _update_bg_button_text() -> void:
	if _dark_bg:
		bg_toggle_button.text = "Фон: тёмный"
	else:
		bg_toggle_button.text = "Фон: светлый"

# =======================================================================
#  Камера
# =======================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom /= 1.1
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.global_position
				_camera_start = camera.position
			else:
				_is_panning = false

	if event is InputEventMouseMotion:
		if _is_panning:
			var delta: Vector2 = event.global_position - _pan_start
			camera.position = _camera_start - delta / camera.zoom

		_update_rune_trails(event.global_position)

# =======================================================================
#  Эффект 1: Снегопад
# =======================================================================
func _spawn_snowfall(center: Vector2, viewport_size: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "Snowfall"
	particles.amount = 80
	particles.lifetime = 6.0
	particles.texture = _textures["snowflake"]
	particles.position = Vector2(center.x, center.y - viewport_size.y * 0.5)

	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(viewport_size.x * 0.6, 10.0, 0.0)

	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 15.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0

	mat.gravity = Vector3(0.0, 15.0, 0.0)

	mat.angular_velocity_min = -45.0
	mat.angular_velocity_max = 45.0

	mat.scale_min = 0.03
	mat.scale_max = 0.08

	var color_curve := CurveTexture.new()
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.1, 1.0))
	alpha_curve.add_point(Vector2(0.8, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	color_curve.curve = alpha_curve
	mat.alpha_curve = color_curve

	mat.damping_min = 5.0
	mat.damping_max = 15.0

	particles.process_material = mat
	effects_root.add_child(particles)

# =======================================================================
#  Эффект 2: Магическая аура
# =======================================================================
func _spawn_magic_aura(center: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "MagicAura"
	particles.amount = 40
	particles.lifetime = 3.0
	particles.texture = _textures["magic_rune"]
	particles.position = center

	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 80.0

	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0

	mat.gravity = Vector3.ZERO

	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0

	mat.scale_min = 0.04
	mat.scale_max = 0.1

	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(0.7, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = sc
	mat.scale_curve = scale_curve

	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.3, 0.6, 1.0, 0.0))
	g.add_point(0.15, Color(0.3, 0.6, 1.0, 0.9))
	g.add_point(0.7, Color(0.7, 0.3, 1.0, 0.8))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.3, 0.8, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	particles.process_material = mat
	effects_root.add_child(particles)

# =======================================================================
#  Эффект 3: Арканный взрыв
# =======================================================================
func _spawn_arcane_explosion(center: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "ArcaneExplosion"
	particles.amount = 60
	particles.lifetime = 2.0
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.texture = _textures["arcane_star"]
	particles.position = center

	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0

	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 350.0

	mat.gravity = Vector3(0.0, 100.0, 0.0)

	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0

	mat.scale_min = 0.05
	mat.scale_max = 0.15

	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.5, 0.6))
	sc.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = sc
	mat.scale_curve = scale_curve

	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	g.add_point(0.3, Color(1.0, 0.5, 0.1, 0.9))
	g.add_point(0.6, Color(0.8, 0.2, 0.5, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.1, 0.6, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	mat.damping_min = 30.0
	mat.damping_max = 60.0

	particles.process_material = mat
	effects_root.add_child(particles)

	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free(); timer.queue_free())
	particles.add_child(timer)
	timer.start()

# =======================================================================
#  Эффект 4: Мистический вихрь
# =======================================================================
func _spawn_mystic_vortex(center: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "MysticVortex"
	particles.amount = 50
	particles.lifetime = 4.0
	particles.texture = _textures["mystic_spiral"]
	particles.position = center

	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 120.0
	mat.emission_ring_inner_radius = 40.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)

	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0

	mat.gravity = Vector3.ZERO

	mat.orbit_velocity_min = 0.3
	mat.orbit_velocity_max = 0.6

	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0

	mat.scale_min = 0.03
	mat.scale_max = 0.09

	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = sc
	mat.scale_curve = scale_curve

	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 1.0, 0.5, 0.0))
	g.add_point(0.2, Color(0.1, 1.0, 0.5, 0.8))
	g.add_point(0.6, Color(0.2, 0.6, 1.0, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.5, 0.2, 1.0, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	particles.process_material = mat
	effects_root.add_child(particles)

# =======================================================================
#  Эффект 5: Руновый след за курсором
# =======================================================================
var _rune_trail_particles: GPUParticles2D = null

func _spawn_rune_trail(center: Vector2) -> void:
	if _rune_trail_particles and is_instance_valid(_rune_trail_particles):
		_rune_trail_particles.queue_free()

	_rune_trail_particles = GPUParticles2D.new()
	_rune_trail_particles.name = "RuneTrail"
	_rune_trail_particles.amount = 25
	_rune_trail_particles.lifetime = 1.5
	_rune_trail_particles.texture = _textures["magic_rune"]
	_rune_trail_particles.position = center

	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0

	mat.gravity = Vector3(0.0, -20.0, 0.0)

	mat.angular_velocity_min = -60.0
	mat.angular_velocity_max = 60.0

	mat.scale_min = 0.03
	mat.scale_max = 0.07

	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.5, 0.8))
	sc.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = sc
	mat.scale_curve = scale_curve

	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	g.add_point(0.4, Color(1.0, 0.4, 0.1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.1, 0.3, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	_rune_trail_particles.process_material = mat
	effects_root.add_child(_rune_trail_particles)

func _update_rune_trails(screen_pos: Vector2) -> void:
	if _rune_trail_particles and is_instance_valid(_rune_trail_particles):
		var world_pos: Vector2 = camera.position + (screen_pos - get_viewport_rect().size / 2.0) / camera.zoom
		_rune_trail_particles.position = world_pos