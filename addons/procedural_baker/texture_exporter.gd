@tool
class_name TextureExporter
extends RefCounted

const EXPORT_PATH: String = "user://export/"

func bake(
	bake_viewport: SubViewport,
	material: ShaderMaterial,
	shader_name: String,
	resolution: int,
	params: Dictionary,
	export_path: String = EXPORT_PATH
) -> Dictionary:
	var export_dir: String
	# Определяем абсолютный путь
	if export_path.begins_with("user://") or export_path.begins_with("res://"):
		export_dir = ProjectSettings.globalize_path(export_path)
	else:
		# Уже абсолютный путь (выбран через FileDialog)
		export_dir = export_path

	# Убедимся что путь заканчивается на /
	if not export_dir.ends_with("/") and not export_dir.ends_with("\\"):
		export_dir += "/"

	DirAccess.make_dir_recursive_absolute(export_dir)

	bake_viewport.size = Vector2i(resolution, resolution)

	var has_baking_mode := false
	if material.shader:
		for u in material.shader.get_shader_uniform_list():
			if u["name"] == "baking_mode":
				has_baking_mode = true
				break

	if has_baking_mode:
		material.set_shader_parameter("baking_mode", true)

	bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image: Image = bake_viewport.get_texture().get_image()

	if has_baking_mode:
		material.set_shader_parameter("baking_mode", false)

	if image == null:
		return {"error": "Не удалось получить изображение"}

	image.flip_y()
	image.convert(Image.FORMAT_RGB8)

	var png_name: String = shader_name + "_albedo.png"
	var png_path: String = export_dir + png_name
	var err := image.save_png(png_path)
	if err != OK:
		return {"error": "Ошибка сохранения PNG: " + str(err)}

	var json_path := export_dir + shader_name + "_metadata.json"
	_save_metadata(json_path, shader_name, png_name, params)

	return {"png_path": png_path, "json_path": json_path}

func _save_metadata(
	path: String,
	shader_name: String,
	albedo_file: String,
	params: Dictionary
) -> void:
	var metadata := {
		"version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"material_name": shader_name,
		"textures": {"albedo": albedo_file},
		"params": params
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()