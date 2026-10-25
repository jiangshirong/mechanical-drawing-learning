extends RefCounted
var r
var checks: Array = []

func wait_frames(count: int = 3) -> void:
	for i in range(count): await r.get_tree().process_frame

func click(p: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = p
	r.get_viewport().push_input(motion, true)
	await wait_frames()
	for pressed in [true,false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		r.get_viewport().push_input(e, true)
		await wait_frames(1)

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check": name, "passed": passed, "detail": detail})

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	r.get_viewport().push_input(e, true)
	await wait_frames()
	e.pressed = false
	r.get_viewport().push_input(e, true)
	await wait_frames()

func choose(i: int) -> void:
	r.show_knowledge_map()
	await wait_frames(3)
	var id: String = r.catalog[i].id
	# The 16-chapter map folds three former model entries into combination.
	# Use its visible chapter card, then the actual observation subtopic tab.
	var old_id:=id
	var alias:Dictionary=r.course_workspace.registry.get("aliases",{}).get(id,{})
	if not alias.is_empty():id=alias.chapter
	r.knowledge_map.view.center_on(r.knowledge_map.canvas.cards[id].get_rect().get_center())
	await wait_frames(3)
	await click(r.knowledge_map.buttons[id].get_global_rect().get_center())
	await wait_frames(5)
	if alias.has("group"):
		var tab:Control=r.course_workspace.scene_tabs.get_node_or_null("Scene_"+alias.group)
		if tab:await click(tab.get_global_rect().get_center());await wait_frames(3)

func run(root) -> Array:
	r = root
	r.save_path = "user://qa-observation-v1.json"
	r.states = {}
	r.colors = true
	r.projections = true
	for i in range(r.catalog.size()):
		await choose(i)
		check("map_entry_"+str(i), r.data.id==r.catalog[i].id, r.data.id)
		await click(r.find_child("SourceButton", true, false).get_global_rect().get_center())
		check("original_"+r.data.id, r.source_window.visible and r.source_image.texture.get_width()>100)
		r.source_window.hide()
		await wait_frames()
		await click(r.find_child("AnswerButton", true, false).get_global_rect().get_center())
		check("answer_"+r.data.id, r.source_window.visible and r.source_image.texture.get_width()>100)
		r.source_window.hide()
		await wait_frames()
	await choose(0)
	await wait_frames(5)
	var before: Dictionary = r.observer.get_state()
	var point: Array = r.data.features[0].points[0]
	var pos: Vector2 = r.observer.global_position+r.observer.camera.unproject_position(r.observer.g(point))
	await click(pos)
	check("3d_point_link", r.selected=="A" and r.paper.picked_world==point)
	point = r.data.features[1].points[0]
	pos = r.paper.global_position+r.paper.screen(Vector2(point[0],point[2]),"front")
	await click(pos)
	check("2d_point_link", r.selected=="B" and r.observer.picked_world==point)
	var selected_before: String = r.selected
	pos = r.observer.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position=pos
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	r.get_viewport().push_input(down, true)
	await wait_frames()
	var motion := InputEventMouseMotion.new()
	motion.position=pos+Vector2(72,20)
	motion.relative=Vector2(72,20)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	r.get_viewport().push_input(motion, true)
	await wait_frames()
	down.position=motion.position
	down.pressed=false
	r.get_viewport().push_input(down, true)
	await wait_frames()
	check("rotate_no_selection", r.selected==selected_before and before!=r.observer.get_state())
	var zoom_before: float = r.observer.zoom
	var wheel := InputEventMouseButton.new()
	wheel.position=pos
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	r.get_viewport().push_input(wheel, true)
	await wait_frames()
	check("wheel_zoom", r.observer.zoom<zoom_before)
	var wheel_release: InputEventMouseButton = wheel.duplicate()
	wheel_release.pressed = false
	r.get_viewport().push_input(wheel_release,true)
	await wait_frames()
	var remembered: Dictionary = r.observer.get_state()
	await choose(3)
	await choose(0)
	check("switch_restores", remembered==r.observer.get_state() and r.projections)
	await choose(3)
	r.observer.standard_view("front")
	await wait_frames(6)
	pos=r.observer.global_position+r.observer.camera.unproject_position(r.observer.g([20,-15,25]))
	await click(pos)
	check("solid_face_link", r.selected=="body" and not r.paper.picked_world.is_empty(), r.selected)
	await choose(1)
	await wait_frames()
	var s: Dictionary = r.paper.screen_segments[0]
	await click(r.paper.global_position+(s.a+s.b)*0.5)
	check("2d_edge_link", r.selected=="AB" and not r.observer.picked_world.is_empty())
	r.save_states()
	await wait_frames()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(r.save_path))
	check("state_file", saved.last_example==r.data.id and saved.states.size()==r.catalog.size())
	FileAccess.open("res://qa/interaction-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	return checks
