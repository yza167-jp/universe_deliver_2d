extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	expect_true(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"The authored viewport must remain 640x360.",
		failures
	)
	expect_true(
		int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1280
		and int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 720,
		"The default desktop window must remain an exact 2x viewport.",
		failures
	)
	expect_true(
		String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport",
		"Display scaling must preserve viewport rendering.",
		failures
	)
	expect_true(
		String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep",
		"Display scaling must preserve the 16:9 aspect ratio without cropping.",
		failures
	)
	expect_true(
		String(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "fractional",
		"Display scaling must allow the largest 16:9 fit in actual fullscreen.",
		failures
	)
	expect_true(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
		== CanvasItem.TEXTURE_FILTER_NEAREST,
		"World and UI canvas textures must retain nearest filtering.",
		failures
	)
	expect_true(
		UniverseDeliverApp.is_fullscreen_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		and UniverseDeliverApp.is_fullscreen_mode(
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		)
		and not UniverseDeliverApp.is_fullscreen_mode(DisplayServer.WINDOW_MODE_WINDOWED),
		"Fullscreen mode detection must cover both actual fullscreen modes only.",
		failures
	)
	return failures
