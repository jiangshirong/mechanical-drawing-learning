extends MarginContainer
const Board = preload("res://practice_board.gd")
const Observer = preload("res://observer.gd")
const Stroke = preload("res://stroke_3d.gd")
const UI = preload("res://ui_style.gd")
const Callout = preload("res://points_callout.gd")
const Progress = preload("res://points_progress.gd")
const Question = preload("res://points_question.gd")
const Concept = preload("res://points_concept.gd")
var r
var config: Dictionary
var active := false
var manual_camera := false
var emphasis_clock := 0.0
var busy := false
var kind := "concept"
var phase := "idle"
var current_step := 0
var current_beat := 0
var steps: Array = []
var beats: Array = []
var before_states: Array = []
var after_states: Array = []
var state: Array = []
var tween: Tween
var previous: Button
var next: Button
var leave: Button
var heading: Label
var copy: RichTextLabel
var stage: HBoxContainer
var space
var sheet
var overlay
var scene: Node3D
var planes: Array = []
var plane_materials: Array = []
var feet: Array = []
var rays: Array = []
var distance_notes: Array = []
var concept_value := Vector3.ZERO
var window_state: Dictionary = {}
var locked: Array = []
var builds := 0
var spatial_meshes: Array = []
var point_note: Label3D
var refs: Dictionary = {}
var substitutions: Dictionary = {}
var hint_progress := 0.0
var typing_clock := 0.0
var typing_schedule: Array[float] = []
var epoch := 0
var held_keys: Dictionary = {}
var progress
var question
var concept

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: add_theme_constant_override("margin_"+side,22)
	var column := VBoxContainer.new()
	add_child(column)
	stage = HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	space = Observer.new()
	space.custom_minimum_size = Vector2(350,300)
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(space)
	space.interaction_enabled = true
	space.rotation_only = true
	space.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: manual_camera=true)
	space.picking_enabled = false
	sheet = Board.new()
	sheet.readonly = true
	stage.add_child(sheet)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",UI.CAPTION)
	heading.add_theme_color_override("font_color",UI.MUTED)
	column.add_child(heading)
	var row := HBoxContainer.new()
	column.add_child(row)
	leave = r.btn("退出",exit)
	leave.name = "PointsExit"
	row.add_child(leave)
	progress = Progress.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.chapter_chosen.connect(jump_chapter)
	row.add_child(progress)
	previous = r.btn("上一步",retreat)
	previous.name = "PointsPrevious"
	next = r.btn("下一步",advance)
	next.name = "PointsNext"
	for pair in [[previous,"A"],[next,"D"]]:
		var unit := HBoxContainer.new()
		unit.add_theme_constant_override("separation",7)
		row.add_child(unit)
		unit.add_child(pair[0])
		UI.teaching_navigation(pair[0])
		var key := Label.new()
		key.text = pair[1]
		key.add_theme_font_size_override("font_size",UI.CAPTION)
		key.add_theme_color_override("font_color",UI.MUTED)
		unit.add_child(key)
	for b in [leave,previous,next]: b.focus_mode = Control.FOCUS_NONE
	overlay = Callout.new()
	overlay.demo = self
	add_child(overlay)
	copy = overlay.label
	question = Question.new()
	question.demo = self
	add_child(question)
	concept = Concept.new()
	concept.d = self
	resized.connect(func(): if active: call_deferred("fit_paper"))
	hide()

func _process(delta: float) -> void:
	if not active: return
	emphasis_clock += delta
	update_emphasis()
	if phase == "typing":
		typing_clock += delta
		while copy.visible_characters < typing_schedule.size() and typing_clock >= typing_schedule[copy.visible_characters]:
			copy.visible_characters += 1
		if copy.visible_characters == typing_schedule.size() and typing_clock >= typing_schedule[-1]+punctuation_pause():
			phase = text_complete_phase()
			update_controls()
	overlay.refresh()

func punctuation_pause() -> float:
	return float(config.presentation.punctuation_pause)

func lock(node: Node) -> void:
	if node is BaseButton:
		locked.append([node,"disabled",node.disabled])
		node.disabled = true
	elif node is LineEdit:
		locked.append([node,"editable",node.editable])
		node.editable = false
	for child in node.get_children(): lock(child)

func enter(mode: String) -> void:
	if active or r.data.id != config.chapter_id: return
	r.practice.cancel_pending()
	r.practice.view.cancel_drag()
	r.practice.save_draft()
	r.remember_current()
	r.hide_source()
	active = true
	kind = mode
	epoch += 1
	held_keys.clear()
	steps = config.concept if kind == "concept" else config.solution
	progress.configure(steps)
	question.reset()
	question.visible = kind == "solution"
	beats.clear()
	for i in range(steps.size()):
		for original in steps[i].beats:
			var b: Dictionary = original.duplicate(true)
			b.group = i
			beats.append(b)
	resolve_parameters()
	current_beat = 0
	if kind == "concept":
		var target: String = config.get("knowledge_resume_aliases",{}).get(r.points_step_id,r.points_step_id)
		for i in range(beats.size()):
			if beats[i].id == target or steps[beats[i].group].id == target:
				current_beat = i
				break
	locked.clear()
	lock(r.free_shell)
	lock(r.practice_shell)
	r.free_shell.hide()
	r.practice_shell.hide()
	r.observer.interaction_enabled = false
	r.paper.picking_enabled = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	window_state = {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	if not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show()
	space.visible = kind == "concept"
	if kind == "concept" and not is_instance_valid(scene):
		build_concept()
		concept.build()
	compile_states()
	sheet.canvas.concept_focus = false
	sheet.canvas.primitives = solution_primitives() if kind == "solution" else []
	prepare_beat()

func resolve_parameters() -> void:
	refs = {"O":[0.0,0.0]}
	substitutions.clear()
	var extent := 5.0
	for coordinates in r.data.parameters.points_mm.values():
		for coordinate in coordinates: extent = maxf(extent,absf(float(coordinate))+7.0)
	for key in ["A","B"]:
		var p: Array = r.data.parameters.points_mm[key]
		refs[key+"_front"] = [p[0],p[2]]
		refs[key+"_top"] = [p[0],p[1]]
		refs[key+"_left"] = [-float(p[1]),p[2]]
		refs[key+"_x"] = [p[0],0.0]
		refs[key+"_top_axis"] = [0.0,p[1]]
		refs[key+"_side_axis"] = [-float(p[1]),0.0]
		refs[key+"_height"] = [0.0,p[2]]
		refs[key+"_turn"] = [-float(p[1]),p[1]]
		refs[key+"_depth0"] = [0.0,0.0]
		refs[key+"_height_start"] = [-extent,p[2]]
		refs[key+"_depth_start"] = [-extent,p[1]]
		refs[key+"_x_upper"] = [p[0],extent]
		refs[key+"_x_lower"] = [p[0],-extent]
		refs[key+"_side_upper"] = [-float(p[1]),extent]
		refs[key+"_level_end"] = [extent,p[2]]
		substitutions[key+"_x"] = str(int(absf(p[0])))
		substitutions[key+"_y"] = str(int(absf(p[1])))
		substitutions[key+"_z"] = str(int(p[2]))
	var a: Array = r.data.parameters.points_mm.A
	var b: Array = r.data.parameters.points_mm.B
	refs.B_left_offset = [b[0],a[2]]
	refs.B_back_offset = [a[0],b[1]]
	substitutions.dx = str(int(absf(b[0]-a[0])))
	substitutions.dy = str(int(absf(b[1]-a[1])))
	substitutions.dz = str(int(absf(b[2]-a[2])))

func projection(key: String,view: String) -> Array:
	return refs[key+"_"+("left" if view=="left" else "top" if view=="top" else "front")]

func solution_primitives() -> Array:
	var result: Array = []
	var guides: Dictionary = {}
	for i in range(beats.size()):
		var action: Dictionary = beats[i].action
		if action.type == "line":
			var line := {"kind":"line","a":refs[action.a],"b":refs[action.b],"step":i,"order":result.size(),"dashed":action.get("dashed",false),"id":action.get("id",beats[i].id)}
			guides[line.id] = line
			result.append(line)
		elif action.type == "point":
			result.append({"kind":"point","p":refs[action.p],"name":action.name,"step":i,"order":result.size()})
		elif action.type == "erase":
			for j in range(action.targets.size()):
				var line: Dictionary = guides[action.targets[j]]
				line.erase_order = result.size()
				line.erase_index = j
				line.erase_count = action.targets.size()
			result.append({"kind":"erase","step":i,"order":result.size()})
	return result

func compile_states() -> void:
	before_states.clear()
	after_states.clear()
	var s: Array = concept.initial_state()
	var scene_id := ""
	for b in beats:
		if kind=="concept":
			if b.get("scene","")!=scene_id:
				s[8] = 0.0
				scene_id = b.get("scene","")
			if b.has("setup"): concept.setup_state(s,b.setup)
		before_states.append(s.duplicate())
		var a: Dictionary = b.action
		var plane_index := ["V","H","W"].find(a.get("plane",""))
		if a.type == "ray": s[plane_index] = 1.0
		elif a.type == "foot": s[plane_index+3] = 1.0
		elif a.type == "unfold": s[6 if a.plane == "H" else 7] = 1.0
		elif a.type in ["line","point","erase"]: s[8] += 1.0
		elif a.type=="move":
			concept.put_pose(s,a.point,concept.resolve_pose(a.to))
			if a.get("show_point",false): s[15]=1.0
		after_states.append(s.duplicate())

func prepare_beat() -> void:
	manual_camera=false
	emphasis_clock=0
	if tween and tween.is_valid(): tween.kill()
	epoch += 1
	var b: Dictionary = beats[current_beat]
	current_step = int(b.group)
	hint_progress = 0.0
	sheet.visible = kind == "solution" or b.get("show_sheet",false)
	space.visible = kind=="concept" and b.get("show_space",true)
	var extent: Array = b.get("paper_extent",[600,600])
	sheet.canvas.size = Vector2(extent[0],extent[1])
	apply_state(before_states[current_beat])
	sheet.canvas.focused_step = current_beat
	heading.text = "%d / %d · %s" % [current_step+1,steps.size(),steps[current_step].title]
	progress.set_current(current_step)
	progress.queue_redraw()
	if kind == "concept":
		r.points_step_id = b.id
		r.schedule_save()
	overlay.set_copy(str(b.text).format(substitutions))
	typing_clock = 0.0
	typing_schedule.clear()
	var at := 0.0
	for ch in copy.text:
		at += 1.0/float(config.presentation.characters_per_second)
		typing_schedule.append(at)
		if ch in "，。；：！？": at += punctuation_pause()
	phase = "typing"
	update_controls()
	call_deferred("fit_paper")

func fit_paper() -> void:
	var captured := epoch
	await get_tree().process_frame
	if not active or captured != epoch: return
	if sheet.visible: sheet.view.fit_content()
	overlay.geometry_key.clear()
	overlay.refresh()

func update_controls() -> void:
	busy = phase in ["typing","playing"]
	previous.disabled = current_beat == 0 and not busy
	next.disabled = phase == "complete"

func complete_current() -> bool:
	if phase == "typing":
		copy.visible_characters = copy.text.length()
		phase = text_complete_phase()
		update_controls()
		return true
	if phase == "playing":
		finish_action()
		return true
	return false

func jump_chapter(index: int) -> void:
	if not active or index < 0 or index >= steps.size(): return
	for i in range(beats.size()):
		if beats[i].group == index:
			current_beat = i
			question.reset()
			prepare_beat()
			return

func advance() -> void:
	if active: reset_lesson_camera()
	if not active or phase == "complete": return
	if complete_current(): return
	if phase == "ready":
		if has_action(): play_action()
		else: next_copy()
	elif phase == "settled":
		next_copy()

func has_action() -> bool:
	return before_states[current_beat]!=after_states[current_beat]

func text_complete_phase() -> String:
	return "complete" if current_beat==beats.size()-1 and not has_action() else "ready"

func next_copy() -> void:
	if current_beat==beats.size()-1:
		phase = "complete"
		update_controls()
		return
	current_beat += 1
	prepare_beat()

func retreat() -> void:
	if active: reset_lesson_camera()
	if not active: return
	if complete_current(): return
	if current_beat == 0: return
	current_beat -= 1
	prepare_beat()

func handle_key(event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code not in [KEY_A,KEY_D]: return
	if not event.pressed:
		held_keys.erase(code)
		return
	if event.echo or held_keys.has(code): return
	held_keys[code] = true
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed: return
	if code == KEY_A: retreat()
	else: advance()

func play_action() -> void:
	phase = "playing"
	update_controls()
	var captured := epoch
	var start: Array = before_states[current_beat]
	var goal: Array = after_states[current_beat]
	var duration := 1.4 if beats[current_beat].action.type == "unfold" else 1.8 if beats[current_beat].action.type == "erase" else 0.9
	tween = create_tween()
	tween.tween_method(func(amount: float):
		if not active or captured != epoch: return
		hint_progress = amount
		var value: Array = []
		for i in range(start.size()): value.append(lerpf(float(start[i]),float(goal[i]),amount))
		if kind=="solution" and beats[current_beat].action.has("measure_from"):
			value[8] = lerpf(float(start[8]),float(goal[8]),clampf((amount-.4)/.6,0,1))
		apply_state(value)
	,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if not active or captured != epoch: return
		finish_action())

func finish_action() -> void:
	if tween and tween.is_valid(): tween.kill()
	epoch += 1
	hint_progress = 1.0
	apply_state(after_states[current_beat])
	phase = "complete" if current_beat == beats.size()-1 else "settled"
	update_controls()
	overlay.refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: held_keys.clear()

func apply_state(value: Array) -> void:
	state = value.duplicate()
	if kind == "solution":
		sheet.canvas.progress = float(value[8])
	else:
		if is_instance_valid(scene):
			planes[1].rotation.x = float(value[6])*PI/2
			planes[2].rotation.y = float(value[7])*PI/2
			var u := (float(value[6])+float(value[7]))/2
			var unfolded: bool = float(value[6])>.999 and float(value[7])>.999
			concept_value = Vector3(float(value[0]),float(value[3]),u)
			for mesh in spatial_meshes: mesh.visible = not unfolded
			point_note.visible = not unfolded
			for i in range(3):
				feet[i].scale = Vector3.ONE*maxf(.001,float(value[i+3]))
				feet[i].visible = float(value[i+3]) > .001
				rays[i].scale = Vector3.ONE*maxf(.001,float(value[i]))
				rays[i].visible = float(value[i])>.001 and not unfolded and not (i==1 and float(value[6])>.001) and not (i==2 and float(value[7])>.001)
				distance_notes[i].hide()
				var focused: bool = ["V","H","W"][i] in beats[current_beat].focus
				plane_materials[i].albedo_color = Color("7593a5",.30) if focused else Color("567181",.17)
			if not manual_camera:
				space.yaw = lerpf(-.48,0,u)
				space.pitch = lerpf(.38,0,u)
				space.zoom = lerpf(.064,.070,u)
				space.update_camera()
			concept.apply(value)
	sheet.canvas.queue_redraw()

func world_anchor(ref: String) -> Vector3:
	var a: Array = concept.position(state,"A")
	if ref == "A": return space.g(a)
	if ref == "B": return space.g(concept.position(state,"B"))
	if ref in ["X","Y","Z"]:
		return space.g({"X":[-14,0,0],"Y":[0,-14,0],"Z":[0,0,14]}[ref])
	var i := ["V","H","W"].find(ref)
	if i >= 0:
		var centers: Array = [[-14,0,14],[-14,-14,0],[0,-14,14]]
		return planes[i].to_global(space.g(centers[i]))
	if ref.begins_with("foot_"):
		return feet[["V","H","W"].find(ref.substr(5))].global_position
	if ref == "H_origin": return planes[1].to_global(space.g([a[0],0,0]))
	if ref == "W_origin": return planes[2].to_global(space.g([0,0,a[2]]))
	return Vector3.ZERO

func screen_anchor(ref: String,paper: bool) -> Vector2:
	if paper:
		var p: Array = refs.get(ref,[0.0,0.0])
		return sheet.canvas.get_global_transform_with_canvas()*preload("res://practice_canvas.gd").at(p)
	var p: Vector2 = space.camera.unproject_position(world_anchor(ref))
	return space.global_position+p*space.size/Vector2(space.viewport.size)

func screen_plane(ref: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var i := ["V","H","W"].find(ref)
	var quads: Array = [
		[[-28,0,0],[0,0,0],[0,0,28],[-28,0,28]],
		[[-28,-28,0],[0,-28,0],[0,0,0],[-28,0,0]],
		[[0,0,0],[0,-28,0],[0,-28,28],[0,0,28]]]
	for q in quads[i]:
		var p: Vector2 = space.camera.unproject_position(planes[i].to_global(space.g(q)))
		result.append(space.global_position+p*space.size/Vector2(space.viewport.size))
	return result

func unfold_arc(plane: String,offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var sample: Vector3 = space.g([-14,-28,0] if plane == "H" else [0,-28,14])
	var axis := Vector3.RIGHT if plane == "H" else Vector3.UP
	for i in range(25):
		var point: Vector3 = scene.to_global(Basis(axis,float(i)/24.0*PI/2)*sample)
		var pixel: Vector2 = space.camera.unproject_position(point)
		result.append(space.global_position+pixel*space.size/Vector2(space.viewport.size)-offset)
	return result

func distance_caption(names: Array,paper: bool) -> String:
	if names.size()<2: return ""
	var distance := 0.0
	if paper:
		var a: Array = refs.get(names[0],[0,0])
		var b: Array = refs.get(names[1],[0,0])
		distance = Vector2(float(a[0]),float(a[1])).distance_to(Vector2(float(b[0]),float(b[1])))
	else: distance = world_anchor(names[0]).distance_to(world_anchor(names[1]))*1000
	return "%d mm" % roundi(distance)

func protected_rects(paper: bool,offset: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if paper:
		var canvas = sheet.canvas
		var zoom: float = canvas.scale_factor()
		var lo: Vector2 = -sheet.view.pan/zoom
		var hi: Vector2 = (sheet.view.size-sheet.view.pan)/zoom
		var transform: Transform2D = canvas.get_global_transform_with_canvas()
		var text_scale: float = transform.get_scale().y/zoom
		for label_data in [
			["X",Vector2(lo.x+28/zoom,canvas.ORIGIN.y),Vector2(0,-12)],
			["Y_W",Vector2(hi.x-58/zoom,canvas.ORIGIN.y),Vector2(0,-12)],
			["Z",Vector2(canvas.ORIGIN.x,lo.y+28/zoom),Vector2(10,0)],
			["Y_H",Vector2(canvas.ORIGIN.x,hi.y-22/zoom),Vector2(10,0)]]:
			var label_point: Vector2 = transform*(label_data[1]+label_data[2]/zoom)-offset
			var measure: Vector2 = canvas.get_theme_default_font().get_string_size(label_data[0],HORIZONTAL_ALIGNMENT_LEFT,-1,18)
			result.append(Rect2(label_point-Vector2(4,22)*text_scale,Vector2(measure.x+8,28)*text_scale))
		for item in sheet.canvas.primitives:
			if item.kind != "point" or sheet.canvas.progress <= float(item.order): continue
			var p: Vector2 = sheet.canvas.get_global_transform_with_canvas()*preload("res://practice_canvas.gd").at(item.p)-offset
			result.append(Rect2(p-Vector2(14,30),Vector2(52,46)))
		for name in ["O","A_x","B_x","A_height","B_height","A_top_axis","B_top_axis","A_side_axis","B_side_axis"]:
			var p := screen_anchor(name,true)-offset
			result.append(Rect2(p-Vector2(16,16),Vector2(32,32)))
	else:
		for name in ["A","foot_V","foot_H","foot_W","V","H","W"]:
			var p := screen_anchor(name,false)-offset
			result.append(Rect2(p-Vector2(12,28),Vector2(55,40)))
		for n in scene.find_children("*","Label3D",true,false):
			if not n.is_visible_in_tree(): continue
			var pixel: Vector2 = space.camera.unproject_position(n.global_position)
			var p: Vector2 = space.global_position+pixel*space.size/Vector2(space.viewport.size)-offset
			var measure: Vector2 = n.font.get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,n.font_size)*n.pixel_size*space.size.y/space.camera.size
			result.append(Rect2(p-Vector2(measure.x*.5+8,measure.y+8),Vector2(measure.x+16,measure.y+16)))
	return result

func exit() -> void:
	if not active: return
	epoch += 1
	if tween and tween.is_valid(): tween.kill()
	active = false
	concept.highlight_labels([])
	phase = "idle"
	busy = false
	held_keys.clear()
	question.reset()
	overlay.geometry_key.clear()
	hide()
	for entry in locked: entry[0].set(entry[1],entry[2])
	locked.clear()
	if not "--qa" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(window_state.mode)
		if window_state.mode == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(window_state.size)
			DisplayServer.window_set_position(window_state.position)
	r.observer.interaction_enabled = true
	r.paper.picking_enabled = true
	r.apply_points_mode()
	r.observer.request_render()
	r.schedule_save()
	if r.chapter_lessons and r.chapter_lessons.returning:r.chapter_lessons.resume()

func node(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	return n

func note(parent: Node3D,text: String,p: Array,plane := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/msyh.ttc")
	l.font_size = 36
	l.pixel_size = 0.000055
	l.position = space.g(p)
	l.modulate = UI.EMPHASIS
	l.no_depth_test = false
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED if plane else BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 0
	parent.add_child(l)
	return l

func build_concept() -> void:
	builds += 1
	space.install(r.data,"res://"+r.catalog[r.index].model)
	space.helpers.hide()
	scene = node(space.world)
	for mesh in space.model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = space.material(UI.EMPHASIS if str(mesh.name).begins_with("A") else Color("263747"))
		spatial_meshes.append(mesh)
	var a: Array = r.data.parameters.points_mm.A
	point_note = note(scene,"A",[a[0]+2,a[1],a[2]+2])
	var quads: Array = [
		[[-28,0,0],[0,0,0],[0,0,28],[-28,0,28]],
		[[-28,-28,0],[0,-28,0],[0,0,0],[-28,0,0]],
		[[0,0,0],[0,-28,0],[0,-28,28],[0,0,28]]]
	var positions: Array = [[-21,0,3],[-23,-23,0],[0,-23,3]]
	var captions: Array = ["V 正面","H 水平面","W 侧面"]
	var p: Array = r.data.parameters.points_mm.A
	var projected: Array = [[p[0],0,p[2]],[p[0],p[1],0],[0,p[1],p[2]]]
	var labels: Array = ["a′","a","a″"]
	for i in range(3):
		var plane := node(scene)
		planes.append(plane)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in [0,1,2,0,2,3]: mesh.surface_add_vertex(space.g(quads[i][j]))
		mesh.surface_end()
		var surface := MeshInstance3D.new()
		surface.mesh = mesh
		var mat = space.material(Color("567181"),0.23)
		surface.material_override = mat
		plane_materials.append(mat)
		plane.add_child(surface)
		var edges: Array = []
		for j in range(4): edges.append([space.g(quads[i][j]),space.g(quads[i][(j+1)%4])])
		plane.add_child(Stroke.make(edges,Color("7593a5")))
		var caption := note(plane,captions[i],positions[i],true)
		if i == 1: caption.rotation_degrees.x = -90
		if i == 2: caption.rotation_degrees.y = -90
		var foot := node(plane)
		foot.position = space.g(projected[i])
		var sphere := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.00065
		sphere_mesh.height = 0.0013
		sphere.mesh = sphere_mesh
		sphere.material_override = space.material(UI.EMPHASIS)
		foot.add_child(sphere)
		note(foot,labels[i],[1.7,0,1.5])
		feet.append(foot)
		var ray := node(scene)
		ray.position = space.g(p)
		ray.add_child(Stroke.make([[Vector3.ZERO,space.g(projected[i])-space.g(p)]],UI.EMPHASIS))
		rays.append(ray)
		var distance := node(scene)
		var mm_position: Array = [[p[0]-12,p[1]/2,p[2]+4],[p[0]-10,p[1],p[2]/2],[p[0]/2+2,p[1],p[2]+6]][i]
		note(distance,["距 V：%d mm" % absf(p[1]),"距 H：%d mm" % p[2],"距 W：%d mm" % absf(p[0])][i],mm_position)
		distance_notes.append(distance)
	space.target = Vector3(0,0,0)
	space.zoom = 0.064
	space.update_camera()


func reset_lesson_camera() -> void:
	manual_camera=false
	space.dragging=false
	if kind=="concept": apply_state(state)

func emphasis_scale() -> float:
	return 1.0+.35*(.5-.5*cos(emphasis_clock*TAU/1.2))

func update_emphasis() -> void:
	if kind=="concept":
		concept.highlight_labels(beats[current_beat].get("label_focus",[]))
		if not beats[current_beat].get("label_focus",[]).is_empty(): space.request_render()
