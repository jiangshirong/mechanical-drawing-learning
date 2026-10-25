extends RefCounted
var r
var h
var checks: Array = []

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check": name, "passed": passed, "detail": detail})

func screenshot(name: String) -> void:
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/" + name + ".png")

func camera_close(a: Dictionary, b: Dictionary) -> bool:
	for key in ["yaw", "pitch", "zoom"]:
		if not is_equal_approx(float(a[key]), float(b[key])): return false
	for i in range(3):
		if not is_equal_approx(float(a.target[i]), float(b.target[i])): return false
	return true

func export_map() -> void:
	# Render the exact map control in a tall offscreen viewport, without resizing
	# or focusing a desktop window. This captures the whole graph for review.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1550)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	r.add_child(viewport)
	var view = load("res://knowledge_map.gd").new()
	view.theme = r.theme
	viewport.add_child(view)
	await h.wait_frames(6)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://qa/knowledge-map-full.png")
	viewport.queue_free()

func export_map_with_root(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	await export_map()

func press_node(id: String) -> void:
	r.knowledge_map.view.center_on(r.knowledge_map.canvas.cards[id].get_rect().get_center())
	await h.wait_frames(5)
	await h.click(r.knowledge_map.buttons[id].get_global_rect().get_center())
	await h.wait_frames(6)

func dag_valid() -> bool:
	var indegree: Dictionary = {}
	for node in r.knowledge_map.graph.nodes: indegree[node.id] = 0
	for edge in r.knowledge_map.graph.edges:
		if not indegree.has(edge.from) or not indegree.has(edge.to): return false
		indegree[edge.to] += 1
	var queue: Array = []
	for id in indegree:
		if indegree[id] == 0: queue.append(id)
	var count := 0
	while not queue.is_empty():
		var id: String = queue.pop_front()
		count += 1
		for edge in r.knowledge_map.graph.edges:
			if edge.from == id:
				indegree[edge.to] -= 1
				if indegree[edge.to] == 0: queue.append(edge.to)
	return count == indegree.size()

func run(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	await h.wait_frames(15)
	check("startup_map", r.map_active and r.knowledge_map.visible and not r.free_shell.visible and not r.guide.active)
	check("separate_save", r.save_path == "user://qa-knowledge-map.json")
	check("offscreen_no_focus", DisplayServer.window_get_position().x < 0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	check("acyclic_dependencies", dag_valid())
	check("seven_model_entries", r.knowledge_map.buttons.size() == r.catalog.size())
	check("map_blocks_hidden_controls", r.find_child("MapEntry",true,false).disabled and not r.observer.interaction_enabled and not r.paper.picking_enabled)
	check("pending_nodes_have_no_button", not r.knowledge_map.buttons.has("half_section") and not r.knowledge_map.buttons.has("part_drawing"))
	await screenshot("knowledge-map-top")
	# Actual internal clicks after moving the graph camera to each node.
	for entry in r.catalog:
		r.show_knowledge_map()
		await h.wait_frames(4)
		await press_node(str(entry.id))
		check("node_opens_" + str(entry.id), r.data.id == entry.id and not r.map_active and r.free_shell.visible and not r.guide.active)
		check("observation_restored_" + str(entry.id), r.observer.interaction_enabled and r.paper.picking_enabled and not r.find_child("MapEntry",true,false).disabled)
		await h.click(r.find_child("SourceButton", true, false).get_global_rect().get_center())
		check("original_available_" + str(entry.id), r.source_window.visible and r.source_image.texture != null)
		r.source_window.hide()
		await h.click(r.find_child("MapEntry", true, false).get_global_rect().get_center())
		check("return_button_" + str(entry.id), r.map_active and not r.free_shell.visible)
	await press_node("points")
	r.observer.standard_view("left")
	r.select_feature("A", r.data.features[0].points[0])
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var point: Array = r.observer.picked_world.duplicate()
	await h.click(r.find_child("MapEntry", true, false).get_global_rect().get_center())
	await press_node("points")
	check("same_example_camera_point", r.observer.get_state() == camera and r.observer.picked_world == point and r.paper.picked_world == point)
	r.show_knowledge_map()
	await press_node("base")
	r.show_knowledge_map()
	await press_node("points")
	check("different_example_camera_restored", r.observer.get_state() == camera)
	r.show_knowledge_map()
	r.knowledge_map.view.center_on(r.knowledge_map.canvas.cards.half_section.get_rect().get_center())
	await h.wait_frames(6)
	var before: String = r.data.id
	await h.click(r.knowledge_map.canvas.cards.half_section.get_global_rect().get_center())
	check("pending_click_inert", r.map_active and r.data.id == before)
	await screenshot("knowledge-map-sections")
	# All nodes remain reachable at the project's supported minimum window size.
	DisplayServer.window_set_size(Vector2i(1060, 720))
	await h.wait_frames(15)
	var reachable := true
	for entry in r.catalog:
		r.knowledge_map.view.center_on(r.knowledge_map.canvas.cards[entry.id].get_rect().get_center())
		await h.wait_frames(4)
		var area: Rect2 = r.knowledge_map.view.get_global_rect()
		var card: Rect2 = r.knowledge_map.buttons[entry.id].get_global_rect()
		reachable = reachable and area.encloses(card)
	check("minimum_window_all_entries_reachable", reachable)
	await screenshot("knowledge-map-minimum")
	await export_map()
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await h.wait_frames(15)
	await press_node("section")
	await h.click(r.guide_button.get_global_rect().get_center())
	await h.wait_frames(8)
	check("guide_from_map_entry", r.guide.active and not r.knowledge_map.visible and not r.free_shell.visible)
	r.show_knowledge_map()
	check("guide_cannot_open_map", r.guide.active and not r.map_active and not r.knowledge_map.visible)
	await h.click(r.find_child("GuideExit", true, false).get_global_rect().get_center())
	await h.wait_frames(8)
	check("guide_exits_to_observation", not r.guide.active and not r.map_active and r.free_shell.visible)
	r.observer.standard_view("left")
	r.set_section(false)
	r.save_states()
	FileAccess.open("res://qa/knowledge-map-expected.json", FileAccess.WRITE).store_string(JSON.stringify({"id":r.data.id, "camera":r.observer.get_state(), "section":r.section_enabled}))
	r.show_knowledge_map()
	r.save_states()
	FileAccess.open("res://qa/knowledge-map-check.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	var failures := checks.filter(func(c): return not c.passed)
	print("KNOWLEDGE_MAP_CHECK ", JSON.stringify({"total": checks.size(), "failures": failures}))
	if not failures.is_empty(): push_error("Knowledge map acceptance failed")

func reopen(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	await h.wait_frames(15)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/knowledge-map-expected.json"))
	check("reopen_starts_on_map", r.map_active and not r.guide.active and not r.free_shell.visible)
	await press_node("section")
	check("reopen_saved_observation", r.data.id == expected.id and r.section_enabled == expected.section and camera_close(r.observer.get_state(), expected.camera), {"id":r.data.id, "camera":r.observer.get_state(), "section":r.section_enabled})
	FileAccess.open("res://qa/knowledge-map-reopen.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("KNOWLEDGE_MAP_REOPEN ", JSON.stringify(checks))
