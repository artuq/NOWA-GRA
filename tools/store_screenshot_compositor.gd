extends Node

const WIDTH := 1080
const HEIGHT := 1920
const SOURCE := "res://marketing/screenshots/store-9x16/Grow Even While Offline!.png"
const OUTPUT := "res://marketing/screenshots/store-9x16-with-copy/Grow Even While Offline!.png"
const FONT := preload("res://assets/ui/fonts/VT323-Regular.ttf")


func _ready() -> void:
	var source_image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if source_image == null or source_image.is_empty():
		push_error("Could not load store screenshot: %s" % SOURCE)
		get_tree().quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDTH, HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	var canvas := Control.new()
	canvas.position = Vector2.ZERO
	canvas.size = Vector2(WIDTH, HEIGHT)
	viewport.add_child(canvas)

	var background := TextureRect.new()
	background.texture = ImageTexture.create_from_image(source_image)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	var headline := RichTextLabel.new()
	headline.position = Vector2(60, 205)
	headline.size = Vector2(960, 260)
	headline.bbcode_enabled = true
	headline.fit_content = false
	headline.scroll_active = false
	headline.add_theme_font_override("normal_font", FONT)
	headline.add_theme_color_override("default_color", Color("f3f1ff"))
	headline.add_theme_color_override("font_outline_color", Color("08090e"))
	headline.add_theme_constant_override("outline_size", 10)
	headline.add_theme_constant_override("line_separation", -12)
	headline.text = (
		"[center][font_size=104]Grow Even While[/font_size]\n"
		+ "[font_size=132][color=#39d4eb]Offline![/color][/font_size][/center]"
	)
	canvas.add_child(headline)

	var accent := ColorRect.new()
	accent.position = Vector2(405, 468)
	accent.size = Vector2(270, 5)
	accent.color = Color("39d4eb")
	canvas.add_child(accent)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var output_dir := ProjectSettings.globalize_path(OUTPUT.get_base_dir())
	DirAccess.make_dir_recursive_absolute(output_dir)
	var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if result != OK:
		push_error("Could not save composed store screenshot: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("COMPOSED: %s" % OUTPUT)
	get_tree().quit()
