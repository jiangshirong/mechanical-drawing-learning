extends RefCounted
# A separate demonstration scene leaves the free-observation state intact.
var r
var active := false
var current_step := 0
var free_snapshot: Dictionary = {}
var free_point: Array = []
var visual: Array = [0.0,0.0,0.0,0.0,0.0]
var animation: Tween
var scene_root: Node3D
var complete: Node3D
var removed: Node3D
var cut_plane: Node3D
var material_notes: Node3D
var projection: Node3D
var rib_notes: Node3D
var labels: Array[Label3D] = []
var label_scale_key := Vector2.ZERO
var last_visual: Array = []
const Stroke = preload("res://stroke_3d.gd")
const Focus = preload("res://guide_focus.gd")
var focus_materials: Array[ShaderMaterial] = []
var busy := false
var fullscreen_requested := false
var window_snapshot: Dictionary = {}
var free_parents: Array = []
var locked_controls: Array = []

func _init(root) -> void:
	r = root
	r.observer.resized.connect(on_stage_resized)

func enter() -> void:
	if active or not r.data.has("guide"): return
	r.remember_current()
	free_snapshot = r.states[r.data.id].duplicate(true)
	free_point = r.observer.picked_world.duplicate()
	active = true
	busy = true
	enter_presentation()
	r.selected = ""
	r.observer.picking_enabled = false
	r.observer.interaction_enabled = false
	r.observer.dragging = false
	r.paper.picking_enabled = false
	r.paper.dragging_point = false
	r.guide_button.hide()
	r.section_toggle.hide()
	r.guide_panel.show()
	var cut_data: Dictionary = r.data.duplicate(false)
	cut_data["section_active"] = true
	cut_data.curves = r.data.section.curves
	r.observer.install(cut_data,"res://"+str(r.data.section.model))
	r.observer.restore_state(free_snapshot.camera)
	build_scene()
	current_step = 0
	for i in range(r.data.guide.steps.size()):
		if r.data.guide.steps[i].id == r.guide_step_id: current_step = i
	visual = r.data.guide.steps[current_step].state.duplicate()
	apply_visual(visual)
	update_lesson()
	await r.get_tree().process_frame
	if not active: return
	apply_camera(camera_target())
	finish_animation()
	r.schedule_save()

func branch(name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	scene_root.add_child(node)
	return node

func lines(parent: Node3D, pairs: Array, color: Color) -> void:
	if pairs.is_empty(): return
	parent.add_child(Stroke.make(pairs,color))

func note(parent: Node3D, text: String, point: Array, color := Color("ffdfa5")) -> void:
	var node := Label3D.new()
	node.text = text
	node.font = load("res://assets/fonts/msyh.ttc")
	node.font_size = 36
	node.pixel_size = 0.00012
	node.position = r.observer.g(point)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.outline_size = 6
	node.outline_modulate = Color("101d29")
	node.modulate = color
	parent.add_child(node)
	labels.append(node)

func quad(parent: Node3D, points: Array, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]: mesh.surface_add_vertex(r.observer.g(points[i]))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = r.observer.material(color,color.a)
	parent.add_child(node)
	var edges: Array = []
	for i in range(4): edges.append([r.observer.g(points[i]),r.observer.g(points[(i+1)%4])])
	lines(parent,edges,Color(color,0.8))

func arrow(parent: Node3D, a: Array, b: Array, color: Color) -> void:
	var start: Vector3 = r.observer.g(a)
	var finish: Vector3 = r.observer.g(b)
	var direction := (finish-start).normalized()
	var side := direction.cross(Vector3.UP).normalized()*0.004
	lines(parent,[[start,finish],[finish,finish-direction*0.010+side],[finish,finish-direction*0.010-side]],color)

func wire(parent: Node3D, curves: Array) -> void:
	var pairs: Array = []
	for c in curves:
		if c.get("projection_only",false): continue
		for i in range(c.points.size()-1): pairs.append([r.observer.g(c.points[i]),r.observer.g(c.points[i+1])])
	lines(parent,pairs,Color("264656"))

func build_scene() -> void:
	label_scale_key = Vector2.ZERO
	last_visual.clear()
	scene_root = Node3D.new()
	scene_root.name = "SectionGuideScene"
	r.observer.world.add_child(scene_root)
	complete = load("res://"+str(r.catalog[r.index].model)).instantiate()
	complete.name = "Complete"
	scene_root.add_child(complete)
	r.observer.decorate(complete)
	wire(complete,r.data.curves)
	removed = load("res://"+str(r.data.guide.removed_model)).instantiate()
	removed.name = "RemovedHalf"
	scene_root.add_child(removed)
	r.observer.decorate(removed)
	wire(removed,r.data.guide.removed_curves)
	cut_plane = branch("CutPlane")
	var b: Array = r.data.bounds
	var p: Dictionary = r.data.parameters
	var xmin := float(b[0][0])-12.0
	var xmax := float(b[0][1])+12.0
	var zmax := float(b[2][1])+24.0
	quad(cut_plane,[[xmin,0,-7],[xmax,0,-7],[xmax,0,zmax],[xmin,0,zmax]],Color(0.95,0.7,0.25,0.16))
	note(cut_plane,"剖切面",[-16,0,zmax-6])
	arrow(cut_plane,[xmin,-58,30],[xmin,10,30],Color("ffdfa5"))
	note(cut_plane,"观察方向",[xmin,-35,42])
	material_notes = branch("MaterialAndVoid")
	note(material_notes,"材料切面",[p.left_x-p.left_radius+6,-8,p.left_height*0.4])
	note(material_notes,"孔洞",[p.right_x,-8,p.right_height+13])
	note(material_notes,"孔壁",[p.right_x+p.right_radius,-8,(p.counterbore_floor+p.right_height)*0.5])
	var wall_x := float(p.right_x)+float(p.counterbore_radius)/sqrt(2.0)
	var wall_y := float(p.counterbore_radius)/sqrt(2.0)
	var wall_z := (float(p.counterbore_floor)+float(p.right_height))*0.5
	lines(material_notes,[[r.observer.g([p.right_x,-8,p.right_height+9]),r.observer.g([p.right_x,0,wall_z])],[r.observer.g([p.right_x+p.right_radius-2,-8,wall_z]),r.observer.g([wall_x,wall_y,wall_z])]],Color("ffdfa5"))
	projection = branch("Projection")
	quad(projection,[[xmin,88,-7],[xmax,88,-7],[xmax,88,zmax],[xmin,88,zmax]],Color(0.36,0.72,0.88,0.10))
	note(projection,"主视方向投影",[-10,88,zmax-6],Color("a7dfef"))
	var pairs: Array = []
	for s in r.data.section.views.front.segments:
		pairs.append([r.observer.g([s.a[0],88,s.a[1]]),r.observer.g([s.b[0],88,s.b[1]])])
	for h in r.data.section.hatches:
		pairs.append([r.observer.g([h.a[0],88,h.a[1]]),r.observer.g([h.b[0],88,h.b[1]])])
	lines(projection,pairs,Color("a7dfef"))
	for point in [[p.left_x-p.left_radius,0,p.left_height*0.5],[p.left_x+p.bore_radius,0,p.left_height*0.7],[p.right_x-p.counterbore_radius,0,p.right_height*0.74],[p.right_x+p.counterbore_radius,0,p.right_height*0.85]]:
		arrow(projection,point,[point[0],88,point[2]],Color(0.6,0.85,0.96,0.6))
	rib_notes = branch("Rib")
	var rib_center := Vector2.ZERO
	for point in r.data.section.rib_polygon: rib_center += Vector2(point[0],point[1])
	rib_center /= r.data.section.rib_polygon.size()
	note(rib_notes,"肋板",[rib_center.x,-10,p.rib_end_z+6])
	lines(rib_notes,[[r.observer.g([rib_center.x,-10,p.rib_end_z+1]),r.observer.g([rib_center.x,0,rib_center.y])]],Color("ffdfa5"))
	focus_materials.clear()
	for pair in [[complete,false],[removed,true],[r.observer.model,false],[r.observer.helpers,false]]:
		focus_materials.append_array(Focus.install(pair[0],r.data,pair[1]))
	# Capture base alpha once; animation must not multiply the previous frame's alpha.
	for node in [removed,cut_plane,material_notes,projection,rib_notes]: capture_alpha(node)
	sync_label_size()

func sync_label_size() -> void:
	var key := Vector2(r.observer.zoom,r.observer.viewport.size.y)
	if key == label_scale_key: return
	label_scale_key = key
	r.observer.request_render()
	# Keep teaching labels readable while the orthographic camera is freely zoomed.
	for node in labels:
		node.pixel_size = 18.0*r.observer.render_scale*r.observer.zoom/(maxf(r.observer.viewport.size.y,1)*node.font_size)

func capture_alpha(node: Node) -> void:
	if node is MeshInstance3D and node.material_override:
		var mat = node.material_override
		var color: Color = mat.get_shader_parameter("line_color") if mat is ShaderMaterial else mat.albedo_color
		node.set_meta("base_alpha",color.a)
	if node is Label3D: node.set_meta("base_alpha",node.modulate.a)
	for child in node.get_children(): capture_alpha(child)

func opacity(node: Node, amount: float) -> void:
	if node is MeshInstance3D and node.material_override:
		var mat = node.material_override
		var color: Color = mat.get_shader_parameter("line_color") if mat is ShaderMaterial else mat.albedo_color
		color.a = float(node.get_meta("base_alpha",1.0))*amount
		if mat is ShaderMaterial:
			mat.shader = Focus.shader_for(color.a < 0.9999) if node.get_meta("guide_body",false) else Stroke.shader_for(color.a < 0.9999)
			mat.set_shader_parameter("line_color",color)
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.9999 else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = color
	if node is Label3D:
		node.modulate.a = float(node.get_meta("base_alpha",1.0))*amount
	for child in node.get_children(): opacity(child,amount)

func apply_visual(values: Array) -> void:
	if values == last_visual: return
	var previous := last_visual
	last_visual = values.duplicate()
	visual = values.duplicate()
	r.observer.request_render()
	var split := float(values[0])
	complete.visible = split < 0.00001
	r.observer.model.visible = not complete.visible
	r.observer.helpers.visible = not complete.visible
	removed.visible = split >= 0.00001 and split < 0.99999
	removed.position = r.observer.g([0,-160.0*split,0])
	if previous.is_empty() or previous[0] != values[0]: opacity(removed,clampf((1.0-split)/0.20,0.0,1.0))
	var nodes := [cut_plane,material_notes,projection,rib_notes]
	for i in range(nodes.size()):
		nodes[i].visible = float(values[i+1]) > 0.00001
		if previous.is_empty() or previous[i+1] != values[i+1]: opacity(nodes[i],float(values[i+1]))
	var show_rib := float(values[4]) > 0.5
	if r.paper.guide_rib != show_rib:
		r.paper.guide_rib = show_rib
		r.paper.queue_redraw()

func blend(t: float, start: Array, finish: Array) -> void:
	var result: Array = []
	for i in range(start.size()): result.append(lerpf(float(start[i]),float(finish[i]),t))
	apply_visual(result)

func stop_animation() -> void:
	if animation and animation.is_valid(): animation.kill()
	animation = null

func go_to(target: int, animate := true) -> void:
	if not active or busy: return
	var destination := clampi(target,0,r.data.guide.steps.size()-1)
	if destination == current_step: return
	current_step = destination
	stop_animation()
	busy = animate
	update_lesson()
	var finish: Array = r.data.guide.steps[current_step].state
	if animate:
		var start := visual.duplicate()
		var camera_start: Dictionary = r.observer.get_state()
		await r.get_tree().process_frame
		if not active: return
		animation = r.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		animation.tween_method(animate_frame.bind(start,finish,camera_start,camera_target()),0.0,1.0,1.5)
		animation.finished.connect(finish_animation)
	else:
		apply_visual(finish)
		apply_camera(camera_target())
		finish_animation()
	r.schedule_save()

func animate_frame(t: float, start: Array, finish: Array, camera_start: Dictionary, camera_finish: Dictionary) -> void:
	blend(t,start,finish)
	var state := camera_start.duplicate(true)
	for key in ["yaw","pitch","zoom"]: state[key] = lerpf(camera_start[key],camera_finish[key],t)
	for i in range(3): state.target[i] = lerpf(camera_start.target[i],camera_finish.target[i],t)
	apply_camera(state)

func finish_animation() -> void:
	if not active: return
	busy = false
	update_navigation()

func update_navigation() -> void:
	r.guide_prev.disabled = busy or current_step == 0
	r.guide_next.disabled = busy or current_step == r.data.guide.steps.size()-1

func update_lesson() -> void:
	var lesson: Dictionary = r.data.guide.steps[current_step]
	r.guide_step_id = lesson.id
	r.guide_heading.text = "%d / %d · %s" % [current_step+1,r.data.guide.steps.size(),lesson.title]
	r.guide_copy.text = lesson.get("conclusion", lesson.text)
	r.guide_reason.text = lesson.get("reason", "")
	r.guide_detail.text = lesson.get("detail", "")
	r.guide_reason.visible = not r.guide_reason.text.is_empty()
	r.guide_detail.visible = not r.guide_detail.text.is_empty()
	update_navigation()
	r.guide_paper.visible = bool(lesson.get("show_projection",current_step>=4))
	for mat in focus_materials: mat.set_shader_parameter("focus_mode",current_step)
	r.observer.request_render()
	var shown: Dictionary = r.data.duplicate(false)
	shown["section_active"] = current_step >= 4
	if shown.section_active:
		shown.views = r.data.section.views
		shown.curves = r.data.section.curves
	r.paper.setup(shown)
	r.paper.selected = ""
	r.paper.guide_rib = current_step == 5
	r.paper.guide_focus = str(lesson.get("focus",""))
	r.paper.queue_redraw()

func lesson_text() -> String:
	return "\n".join([r.guide_copy.text, r.guide_reason.text, r.guide_detail.text])

func exit() -> void:
	if not active: return
	stop_animation()
	active = false
	busy = false
	exit_presentation()
	if is_instance_valid(scene_root):
		scene_root.get_parent().remove_child(scene_root)
		scene_root.queue_free()
	scene_root = null
	labels.clear()
	focus_materials.clear()
	r.section_enabled = bool(free_snapshot.section)
	r.selected = str(free_snapshot.selected)
	r.observer.install(r.display_data(),r.model_path())
	r.observer.restore_state(free_snapshot.camera)
	r.paper.setup(r.display_data())
	r.observer.picked_world = free_point.duplicate()
	r.paper.picked_world = free_point.duplicate()
	r.observer.picking_enabled = true
	r.observer.interaction_enabled = true
	r.paper.picking_enabled = true
	r.paper.guide_rib = false
	r.paper.guide_focus = ""
	r.guide_panel.hide()
	r.guide_button.show()
	r.section_toggle.show()
	r.section_toggle.set_pressed_no_signal(r.section_enabled)
	r.refresh()
	r.schedule_save()
	if r.chapter_lessons and r.chapter_lessons.returning:r.chapter_lessons.resume()

func lock_free_controls(node: Node) -> void:
	if node is BaseButton:
		locked_controls.append([node,node.disabled])
		node.disabled = true
	for child in node.get_children(): lock_free_controls(child)

func enter_presentation() -> void:
	window_snapshot = {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	fullscreen_requested = true
	# Native fullscreen is suppressed in offscreen QA so tests cannot cover or
	# focus the user's desktop. Production uses the actual fullscreen window mode.
	if not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	r.hide_source()
	var focus: Control = r.get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	free_parents = [[r.observer,r.observer.get_parent(),r.observer.get_index()],[r.paper,r.paper.get_parent(),r.paper.get_index()]]
	r.observer.reparent(r.guide_space,false)
	r.paper.reparent(r.guide_paper,false)
	locked_controls.clear()
	lock_free_controls(r.free_shell)
	r.free_shell.hide()
	r.guide_shell.show()

func exit_presentation() -> void:
	for entry in free_parents:
		entry[0].reparent(entry[1],false)
		entry[1].move_child(entry[0],entry[2])
	free_parents.clear()
	for entry in locked_controls: entry[0].disabled = entry[1]
	locked_controls.clear()
	r.guide_shell.hide()
	r.free_shell.show()
	if not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(window_snapshot.mode)
	if window_snapshot.mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(window_snapshot.size)
		DisplayServer.window_set_position(window_snapshot.position)
	fullscreen_requested = false

func camera_target() -> Dictionary:
	var pose: Dictionary = r.data.guide.steps[current_step].camera
	var zoom := float(pose.zoom)
	if not r.guide_paper.visible:
		# Fit the part in short wide windows as well as tall fullscreen layouts.
		zoom = maxf(zoom,0.21*float(r.observer.size.y)/maxf(r.observer.size.x,1))
	var target: Vector3 = r.observer.g(pose.target_mm)
	return {"yaw":float(pose.yaw),"pitch":float(pose.pitch),"zoom":zoom,"target":[target.x,target.y,target.z]}

func apply_camera(state: Dictionary) -> void:
	r.observer.restore_state(state)

func on_stage_resized() -> void:
	if active and not busy: apply_camera(camera_target())
