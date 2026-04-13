extends Node3D

@onready var water_mesh:          MeshInstance3D = $WaterMesh
@onready var wave_speed_slider:   HSlider        = $UI/Panel/VBox/WaveSpeedSlider
@onready var wave_speed_label:    Label          = $UI/Panel/VBox/WaveSpeedLabel
@onready var wave_height_slider:  HSlider        = $UI/Panel/VBox/WaveHeightSlider
@onready var wave_height_label:   Label          = $UI/Panel/VBox/WaveHeightLabel
@onready var back_button:         Button         = $UI/Panel/VBox/BackButton

var water_material: ShaderMaterial

func _ready() -> void:
	var shader: Shader = load("res://shaders/water_shader.gdshader")
	water_material        = ShaderMaterial.new()
	water_material.shader = shader

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency  = 0.05
	var tex          := NoiseTexture2D.new()
	tex.noise         = noise
	tex.width         = 512
	tex.height        = 512
	tex.seamless      = true
	water_material.set_shader_parameter("noise_texture", tex)

	water_mesh.material_override = water_material

	wave_speed_slider.value_changed.connect(func(v: float) -> void:
		water_material.set_shader_parameter("wave_speed", v)
		wave_speed_label.text = "Скорость волн: %.1f" % v)
	wave_height_slider.value_changed.connect(func(v: float) -> void:
		water_material.set_shader_parameter("wave_height", v)
		wave_height_label.text = "Высота волн: %.2f" % v)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/BakerScene.tscn"))
