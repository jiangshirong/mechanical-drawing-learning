extends RefCounted
var r
var h
var checks: Array = []

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check":name, "passed":passed, "detail":detail})

func contains_slider(node: Node) -> bool:
	if node is ScrollContainer or node is ScrollBar or node is Slider: return true
	for child in node.get_children():
		if contains_slider(child): return true
	return false

func mouse_button(area: Control, point: Vector2, code: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = area.get_global_transform_with_canvas() * point
	event.button_index = code
	event.pressed = pressed
	area.get_viewport().push_input(event, true)

func move(area: Control, point: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = area.get_global_transform_with_canvas() * point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	area.get_viewport().push_input(event, true)

func wheel(area: Control, point: Vector2, up: bool, count := 1) -> void:
	for i in range(count):
		mouse_button(area, point, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true)
		mouse_button(area, point, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, false)
	await h.wait_frames(3)

func drag(area: Control, start: Vector2, finish: Vector2, return_to_start := false) -> void:
	mouse_button(area, start, MOUSE_BUTTON_LEFT, true)
	await h.wait_frames(2)
	move(area, finish, finish-start)
	await h.wait_frames(2)
	if return_to_start:
		move(area, start, start-finish)
		await h.wait_frames(2)
	mouse_button(area, start if return_to_start else finish, MOUSE_BUTTON_LEFT, false)
	await h.wait_frames(3)

func screenshot(name: String) -> void:
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/" + name + ".png")

func close_source_x() -> void:
	var window: Window = r.source_window
	var point := Vector2(window.position) + Vector2(window.size.x-window.get_theme_constant("close_h_offset", "Window"), -window.get_theme_constant("close_v_offset", "Window"))
	await h.click(point)
	await h.wait_frames(4)
	check("source_x_closes", not window.visible, {"position":point, "size":window.size})
	# Keep the test recoverable if a changed decoration layout invalidates the hit.
	if window.visible: window.hide()

func run(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	await h.wait_frames(15)
	check("map_startup", r.map_active and r.knowledge_map.visible)
	check("no_chapter_dropdown", r.find_child("ExampleChoice", true, false) == null and r.free_shell.find_children("*", "OptionButton", true, false).is_empty())
	check("map_no_sliders", not contains_slider(r.knowledge_map))
	check("source_no_sliders", not contains_slider(r.source_window))
	check("source_no_duplicate_close", r.source_window.find_children("*", "BaseButton", true, false).is_empty())
	check("offscreen_no_focus", DisplayServer.window_get_position().x < 0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	var view = r.knowledge_map.view
	var pivot: Vector2 = view.size * Vector2(0.35, 0.4)
	var world: Vector2 = (pivot-view.pan)/view.zoom
	var old_zoom: float = view.zoom
	await wheel(view, pivot, true)
	check("map_wheel_zoom_in", view.zoom > old_zoom)
	check("map_zoom_mouse_anchor", ((pivot-view.pan)/view.zoom).distance_to(world) < 0.001)
	await wheel(view, pivot, false)
	check("map_wheel_zoom_out", is_equal_approx(view.zoom, old_zoom))
	var old_pan: Vector2 = view.pan
	await drag(view, view.size*0.5, view.size*0.5+Vector2(85, -45))
	check("map_left_drag_pan", view.pan.distance_to(old_pan+Vector2(85, -45)) < 0.01)
	check("map_drag_no_navigation", r.map_active)
	# A drag begun on a clickable node must stay a drag, even if released on it.
	view.center_on(r.knowledge_map.canvas.cards.points.get_rect().get_center())
	await h.wait_frames(3)
	await drag(view, view.size*0.5, view.size*0.5+Vector2(70, 30), true)
	check("node_drag_return_no_click", r.map_active and not view.holding)
	await wheel(view, pivot, true, 45)
	check("map_zoom_upper_bound", is_equal_approx(view.zoom, view.maximum_zoom))
	await wheel(view, pivot, false, 70)
	check("map_zoom_lower_bound", is_equal_approx(view.zoom, view.minimum_zoom))
	view.fit_content()
	view.center_on(r.knowledge_map.canvas.cards.section.get_rect().get_center())
	await h.wait_frames(4)
	await screenshot("canvas-map-pan-zoom")
	# Existing helper now selects all chapters through real map clicks.
	for i in range(r.catalog.size()):
		await h.choose(i)
		check("map_click_"+str(r.catalog[i].id), not r.map_active and r.data.id == r.catalog[i].id)
	await h.choose(6)
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	for mode in ["question", "answer"]:
		await h.click(r.find_child("SourceButton" if mode == "question" else "AnswerButton",true,false).get_global_rect().get_center())
		await h.wait_frames(8)
		check(mode+"_opens", r.source_window.visible and r.source_image.texture != null)
		var image_view = r.source_view
		var image_pivot: Vector2 = image_view.size*Vector2(0.4,0.45)
		var image_world: Vector2 = (image_pivot-image_view.pan)/image_view.zoom
		var image_zoom: float = image_view.zoom
		var image_rect := Rect2(image_view.pan, r.source_image.size*image_view.zoom)
		check(mode+"_initial_fit", Rect2(Vector2.ZERO,image_view.size).encloses(image_rect))
		await wheel(image_view, image_pivot, true, 3)
		check(mode+"_wheel_zoom", image_view.zoom > image_zoom)
		check(mode+"_zoom_mouse_anchor", ((image_pivot-image_view.pan)/image_view.zoom).distance_to(image_world) < 0.001)
		var image_pan: Vector2 = image_view.pan
		await drag(image_view, image_pivot, image_pivot+Vector2(-90,65))
		check(mode+"_left_drag_pan", image_view.pan.distance_to(image_pan+Vector2(-90,65)) < 0.01)
		await wheel(image_view, image_pivot, false)
		check(mode+"_wheel_zoom_out", image_view.zoom < image_zoom*pow(1.12,3))
		check(mode+"_no_sliders", not contains_slider(r.source_window))
		check(mode+"_observer_unchanged", r.observer.get_state()==camera)
		await screenshot("canvas-source-"+mode)
		await close_source_x()
		check(mode+"_close_preserves_observation", r.observer.get_state()==camera and not r.map_active)
	# The full-screen guide still owns input and exits to the free observer.
	await h.click(r.guide_button.get_global_rect().get_center())
	await h.wait_frames(8)
	check("guide_still_enters", r.guide.active and not r.knowledge_map.visible and not r.source_window.visible)
	await h.click(r.find_child("GuideExit",true,false).get_global_rect().get_center())
	await h.wait_frames(8)
	check("guide_exit_restores_observer", not r.guide.active and r.free_shell.visible and r.observer.get_state()==camera)
	FileAccess.open("res://qa/canvas-interaction-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failures := checks.filter(func(c):return not c.passed)
	print("CANVAS_CHECK ", JSON.stringify({"total":checks.size(),"failures":failures}))
	if not failures.is_empty(): push_error("Pan/zoom acceptance failed")
