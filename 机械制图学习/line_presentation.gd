extends MarginContainer
const UI = preload("res://ui_style.gd")
const Observer = preload("res://observer.gd")
const Geometry = preload("res://line_geometry.gd")
const Stroke = preload("res://stroke_3d.gd")
var r
var config: Dictionary
var return_to_practice := false
var geometry = Geometry.new()
var active := false
var manual_camera := false
var spatial_label_rects: Dictionary = {}
var spatial_label_layout: Dictionary = {}
var spatial_ink_segments: Array = []
var plane_edge_segments: Array = []
var sweep_key: Array = []
var sweep_rects: Array[Rect2] = []
var emphasis_clock := 0.0
var busy := false
var phase := "idle"
var current_beat := 0
var current_step := 0
var steps: Array = []
var beats: Array = []
var before_states: Array = []
var after_states: Array = []
var state: Dictionary = {}
var tween: Tween
var problem_preparing := false
var epoch := 0
var held_keys: Dictionary = {}
var typing_clock := 0.0
var typing_schedule: Array[float] = []
var hint_progress := 0.0
var window_state: Dictionary = {}
var locked: Array = []
var stage: HBoxContainer
var space
var paper
var overlay
var copy: RichTextLabel
var heading: Label
var previous: Button
var next: Button
var leave: Button
var progress
var scene: Node3D
var point_nodes: Dictionary = {}
var line_nodes: Dictionary = {}
var labels: Array = []
var plane_labels: Array = []
var builds := 0
var rendered_degenerate: Array = []
var ratio_ticks: MeshInstance3D
var space_tick_points: Array[Vector3] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: add_theme_constant_override("margin_"+side,22)
	var column := VBoxContainer.new()
	add_child(column)
	stage = HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation",12)
	column.add_child(stage)
	space = Observer.new()
	space.custom_minimum_size = Vector2(350,300)
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.interaction_enabled = true
	space.rotation_only = true
	space.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: manual_camera=true)
	space.picking_enabled = false
	stage.add_child(space)
	paper = preload("res://line_paper.gd").new()
	paper.demo = self
	paper.custom_minimum_size = Vector2(400,300)
	stage.add_child(paper)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",UI.CAPTION)
	heading.add_theme_color_override("font_color",UI.MUTED)
	column.add_child(heading)
	var row := HBoxContainer.new()
	column.add_child(row)
	leave = r.btn("退出",exit)
	leave.name = "LineExit"
	row.add_child(leave)
	progress = preload("res://points_progress.gd").new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.chapter_chosen.connect(jump_chapter)
	row.add_child(progress)
	previous = r.btn("上一步",retreat)
	previous.name = "LinePrevious"
	next = r.btn("下一步",advance)
	next.name = "LineNext"
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
	overlay = preload("res://line_callout.gd").new()
	overlay.demo = self
	add_child(overlay)
	copy = overlay.label
	geometry.load_config(config)
	resized.connect(func(): if active: call_deferred("fit_stage"))
	hide()

func lock(node: Node) -> void:
	if node is BaseButton:
		locked.append([node,"disabled",node.disabled]); node.disabled=true
	elif node is LineEdit:
		locked.append([node,"editable",node.editable]); node.editable=false
	for child in node.get_children(): lock(child)

func enter() -> void:
	return_to_practice=r.line_workspace!=null and r.line_workspace.visible
	if return_to_practice:r.line_workspace.board.cancel_pending();r.line_workspace.board.save_draft();r.line_workspace.hide()
	if active or r.data.id!="line" or r.map_active or r.presentation_active(): return
	r.practice.cancel_pending()
	r.practice.view.cancel_drag()
	r.remember_current()
	r.hide_source()
	active = true
	held_keys.clear()
	locked.clear()
	lock(r.free_shell)
	lock(r.practice_shell)
	r.free_shell.hide()
	r.practice_shell.hide()
	r.observer.interaction_enabled = false
	r.paper.picking_enabled = false
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	window_state={"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	if not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show()
	steps=config.concept
	progress.configure(steps)
	beats.clear(); before_states.clear(); after_states.clear()
	var working: Dictionary = {}
	for i in range(steps.size()):
		for original in steps[i].beats:
			var b: Dictionary = original.duplicate(true)
			b.group = i
			beats.append(b)
			if working.is_empty() or working.scene!=b.scene: working=geometry.initial(b.scene)
			before_states.append(working.duplicate(true))
			geometry.apply_action(working,b.action)
			after_states.append(working.duplicate(true))
	current_beat=0
	var resume: String = config.get("knowledge_resume_aliases",{}).get(r.line_step_id,r.line_step_id)
	for i in range(beats.size()):
		if beats[i].id==resume or steps[beats[i].group].id==resume:
			current_beat=i; break
	if not is_instance_valid(scene): build_space()
	prepare_beat()

func prepare_beat() -> void:
	spatial_label_layout.clear()
	manual_camera=false
	emphasis_clock=0
	if tween and tween.is_valid(): tween.kill()
	problem_preparing=false
	epoch+=1
	current_step=int(beats[current_beat].group)
	hint_progress=0
	apply_state(before_states[current_beat])
	heading.text="%d / %d · %s" % [current_step+1,steps.size(),steps[current_step].title]
	progress.set_current(current_step)
	r.line_step_id=beats[current_beat].id
	r.schedule_save()
	overlay.set_copy(beats[current_beat].text)
	typing_clock=0
	typing_schedule.clear()
	var at := 0.0
	for ch in copy.text:
		at+=1.0/float(config.presentation.characters_per_second)
		typing_schedule.append(at)
		if ch in "，。；：！？": at+=float(config.presentation.punctuation_pause)
	phase="typing"
	update_controls()
	call_deferred("fit_stage")
	if prepares_with_question(): play_action(true)

func fit_stage() -> void:
	var captured := epoch
	await get_tree().process_frame
	if not active or captured!=epoch: return
	paper.fit()
	if manual_camera: return
	space.target=Geometry.world(Vector3(-25,-20,23))
	space.yaw=-.55
	space.pitch=.38
	space.zoom=.108*maxf(1,space.size.y/maxf(space.size.x,1))
	space.update_camera()
	if not overlay.conditions.is_empty():
		# Keep the model at its normal scale; move the lecture view down to
		# reserve room for the longer task and its two condition rows.
		var reserved: float = maxf(0,overlay.copy_size().y-108)+16
		space.target+=space.camera.global_basis.y*space.camera.size*reserved/maxf(space.size.y,1)
		space.update_camera()
	apply_state(state)
	overlay.geometry_key.clear()
	overlay.refresh()

func _process(delta: float) -> void:
	if not active: return
	emphasis_clock += delta
	update_emphasis(delta)
	if phase=="typing":
		typing_clock+=delta
		while copy.visible_characters<typing_schedule.size() and typing_clock>=typing_schedule[copy.visible_characters]: copy.visible_characters+=1
		if copy.visible_characters==typing_schedule.size() and typing_clock>=typing_schedule[-1]+float(config.presentation.punctuation_pause):
			phase=text_complete_phase(); update_controls()
	overlay.refresh()

func has_action() -> bool:
	return before_states[current_beat]!=after_states[current_beat]

func prepares_with_question() -> bool:
	return beats[current_beat].get("callout_kind","")=="problem" and beats[current_beat].action.type=="scene" and has_action()

func text_complete_phase() -> String:
	if prepares_with_question(): return "playing" if problem_preparing else "settled"
	return "complete" if current_beat==beats.size()-1 and not has_action() else "ready"

func update_controls() -> void:
	busy=phase in ["typing","playing"]
	previous.disabled=current_beat==0 and not busy
	next.disabled=phase=="complete"

func complete_current() -> bool:
	if phase=="typing":
		copy.visible_characters=copy.text.length()
		phase=text_complete_phase()
		if problem_preparing: finish_action()
		else: update_controls()
		return true
	if phase=="playing": finish_action(); return true
	return false

func advance() -> void:
	if active: reset_lesson_camera()
	if not active or phase=="complete": return
	if complete_current(): return
	if phase=="ready" and has_action(): play_action()
	else:
		if current_beat<beats.size()-1: current_beat+=1; prepare_beat()

func retreat() -> void:
	if active: reset_lesson_camera()
	if not active or complete_current() or current_beat==0: return
	current_beat-=1; prepare_beat()

func jump_chapter(index: int) -> void:
	if not active or index<0 or index>=steps.size(): return
	for i in range(beats.size()):
		if beats[i].group==index: current_beat=i; prepare_beat(); return

func handle_key(event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code not in [KEY_A,KEY_D]: return
	if not event.pressed: held_keys.erase(code); return
	if event.echo or held_keys.has(code): return
	held_keys[code]=true
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed: return
	if code==KEY_A: retreat()
	else: advance()

func play_action(alongside_copy := false) -> void:
	# Scene changes follow the same cancellable playback as drawing actions.
	var changing_scene: bool = before_states[current_beat].scene!=after_states[current_beat].scene
	problem_preparing=alongside_copy
	if not alongside_copy: phase="playing"
	update_controls()
	var captured := epoch
	tween=create_tween()
	tween.tween_method(func(t: float):
		if not active or captured!=epoch: return
		hint_progress=t
		apply_state(geometry.transition(before_states[current_beat],after_states[current_beat],t) if changing_scene else Geometry.interpolate(before_states[current_beat],after_states[current_beat],t))
	,0.0,1.0,float(beats[current_beat].action.get("duration",1.1))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): if active and captured==epoch: finish_action())

func finish_action() -> void:
	if tween and tween.is_valid(): tween.kill()
	epoch+=1; hint_progress=1
	apply_state(after_states[current_beat])
	var keep_writing: bool = problem_preparing and phase=="typing"
	problem_preparing=false
	if not keep_writing: phase="complete" if current_beat==beats.size()-1 else "settled"
	update_controls()
	place_point_labels()
	overlay.refresh()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: held_keys.clear()

func label3(text: String,p: Vector3,parent: Node3D,billboard := true) -> Label3D:
	var note := Label3D.new()
	note.text=text
	note.position=Geometry.world(p)
	note.font=load("res://assets/fonts/msyh.ttc")
	note.font_size=36
	note.outline_size=0
	note.no_depth_test=false
	note.billboard=BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	note.modulate=Color("d9e1e7")
	parent.add_child(note)
	labels.append(note)
	return note

func build_space() -> void:
	builds+=1
	scene=Node3D.new(); space.world.add_child(scene)
	var planes: Array = [
		["V 正面",[Vector3(-58,0,0),Vector3.ZERO,Vector3(0,0,52),Vector3(-58,0,52)],Vector3(-48,0,5)],
		["H 水平面",[Vector3(-58,-52,0),Vector3(0,-52,0),Vector3.ZERO,Vector3(-58,0,0)],Vector3(-44,-43,0)],
		["W 侧面",[Vector3.ZERO,Vector3(0,-52,0),Vector3(0,-52,52),Vector3(0,0,52)],Vector3(0,-43,5)]]
	for i in range(planes.size()):
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in [0,1,2,0,2,3]: mesh.surface_add_vertex(Geometry.world(planes[i][1][j]))
		mesh.surface_end()
		var node := MeshInstance3D.new(); node.mesh=mesh
		node.material_override=space.material(Color("567181"),.19)
		scene.add_child(node)
		var edges: Array = []
		for j in range(4): edges.append([Geometry.world(planes[i][1][j]),Geometry.world(planes[i][1][(j+1)%4])])
		scene.add_child(Stroke.make(edges,Color("7593a5")))
		plane_edge_segments.append_array(edges)
		var note := label3(planes[i][0],planes[i][2],scene,false)
		if i==1: note.rotation_degrees.x=-90
		if i==2: note.rotation_degrees.y=-90
		plane_labels.append(note)
	var keys: Dictionary = {}
	var lines: Dictionary = {}
	for spec in geometry.scenes.values():
		for key in spec.resolved: keys[key]=true
		for key in spec.lines: lines[key]=true
	var shape := SphereMesh.new(); shape.radius=.00065; shape.height=.0013
	for key in keys:
		point_nodes[key]={}
		for view in Geometry.VIEWS:
			var ball := MeshInstance3D.new(); ball.mesh=shape; ball.material_override=space.material(Color("76b5d7") if view=="space" else Color("f0c67d"))
			scene.add_child(ball)
			var note := label3(str(key),Vector3.ZERO,scene)
			point_nodes[key][view]={"ball":ball,"label":note}
	for key in lines:
		line_nodes[key]={}
		for view in Geometry.VIEWS:
			var line := Stroke.make([[Vector3.ZERO,Vector3(0,0,.001)]],Color("e4edf3") if view=="space" else Color("e6bd7d"))
			scene.add_child(line)
			line_nodes[key][view]=line
	ratio_ticks=MeshInstance3D.new();var tick_material:StandardMaterial3D=space.material(Color("efab64"));tick_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ratio_ticks.material_override=tick_material;scene.add_child(ratio_ticks)

func on_plane(p: Vector3,view: String) -> Vector3:
	if view=="front": return Vector3(p.x,0,p.z)
	if view=="top": return Vector3(p.x,p.y,0)
	if view=="left": return Vector3(0,p.y,p.z)
	return p

func apply_state(value: Dictionary) -> void:
	if state.get("scene","")!=value.scene and state.get("morph_target","")!=value.scene: spatial_label_layout.clear()
	state=value.duplicate(true)
	if not is_instance_valid(scene): return
	rendered_degenerate.clear()
	var highlights: Array = beats[current_beat].get("label_focus",[])
	for note in labels:
		note.font_size=36
		note.pixel_size=18*space.zoom/(36*maxf(1,space.size.y))
		note.modulate=Color("d9e1e7")
	for note in plane_labels:
		if note.text.split(" ")[0] in highlights: note.font_size=roundi(36*emphasis_scale()); note.modulate=Color("e99c56")
	for key in point_nodes:
		for view in Geometry.VIEWS:
			var entry: Dictionary = point_nodes[key][view]
			var shown: bool = state.points.has(key) and float(state.points[key][view])>.001
			if shown and not state.has("morph_target") and state.scene=="third" and view=="left" and float(state.points[key][view])<preload("res://line_transfer.gd").POINT_TIME: shown=false
			entry.ball.visible=shown; entry.label.visible=shown
			if not shown: continue
			entry.ball.scale=Vector3.ONE*float(state.points[key][view]) if state.has("morph_target") else Vector3.ONE
			if state.has("morph_target") and float(state.points[key][view])<.3: entry.label.hide()
			var focused: bool = view+":"+key in beats[current_beat].focus
			entry.ball.material_override.albedo_color=Color("efab64") if focused else Color("76b5d7") if view=="space" else Color("f0c67d")
			var p := on_plane(geometry.point(state,key),view)
			entry.ball.position=Geometry.world(p)
			entry.label.position=Geometry.world(p+Vector3(1.5,0,2))
			entry.label.text=str(key) if view=="space" else str(key).to_lower()+{"front":"′","top":"","left":"″"}[view]
			if entry.label.text in highlights: entry.label.font_size=roundi(36*emphasis_scale()); entry.label.modulate=Color("e99c56")
	for view in Geometry.VIEWS:
		var entries: Array = []
		for key in point_nodes:
			var entry: Dictionary = point_nodes[key][view]
			if not entry.ball.visible: continue
			var same: Array = entries.filter(func(old):return old.ball.position.distance_to(entry.ball.position)<.000001)
			if same.is_empty(): entries.append(entry)
			else:
				same[0].label.text += "("+entry.label.text+")"
				entry.ball.hide(); entry.label.hide()
	for key in line_nodes:
		for view in Geometry.VIEWS:
			var node: MeshInstance3D = line_nodes[key][view]
			var focused: bool = view+":"+key in beats[current_beat].focus
			node.material_override.set_shader_parameter("line_color",Color("efab64") if focused else Color("e4edf3") if view=="space" else Color("e6bd7d"))
			node.material_override.set_shader_parameter("width_pixels",1.9 if focused else 1.4)
			var amount: float = float(state.lines[key][view]) if state.lines.has(key) else 0
			node.visible=amount>.001 and key!="guide"
			if not node.visible: continue
			var ends: Array[Vector3] = geometry.ends(state,key)
			var a := Geometry.world(on_plane(ends[0],view))
			var b := Geometry.world(on_plane(ends[0].lerp(ends[1],amount),view))
			var delta := b-a
			if delta.length()<.000001:
				node.hide(); rendered_degenerate.append(view+":"+key); continue
			var up := Vector3.UP if absf(delta.normalized().dot(Vector3.UP))<.99 else Vector3.RIGHT
			var orientation := Basis.looking_at(-delta.normalized(),up)
			node.transform=Transform3D(orientation*Basis.from_scale(Vector3(1,1,delta.length()/.001)),a)
	# In the multi-line construction, the right pane carries projection names;
	# the left pane names the spatial entities to keep its dense model readable.
	if state.scene=="both":
		for views in point_nodes.values():
			for view in ["front","top","left"]: views[view].label.hide()
	space_tick_points.clear();ratio_ticks.mesh=null
	if float(state.ticks)>0 and state.lines.has("AB"):
		var ends:Array[Vector3]=geometry.ends(state,"AB")
		var direction:Vector3=(ends[1]-ends[0]).normalized()
		var across:Vector3=direction.cross(Vector3.UP)
		if across.length()<.01:across=direction.cross(Vector3.RIGHT)
		across=across.normalized()*1.4
		var mesh:=ImmediateMesh.new();var started:=false
		for i in range(1,5):
			if float(i)/8>float(state.ticks):continue
			if not started:mesh.surface_begin(Mesh.PRIMITIVE_LINES);started=true
			var p:Vector3=ends[0].lerp(ends[1],float(i)/5);space_tick_points.append(p)
			mesh.surface_add_vertex(Geometry.world(p-across));mesh.surface_add_vertex(Geometry.world(p+across))
		if started:mesh.surface_end();ratio_ticks.mesh=mesh
	place_point_labels()
	paper.queue_redraw()
	space.request_render()

func place_point_labels(delta := 0.0) -> void:
	spatial_label_rects.clear(); spatial_ink_segments.clear()
	for segment in plane_edge_segments:
		var a: Vector2 = space.camera.unproject_position(segment[0])*space.size/Vector2(space.viewport.size)
		var b: Vector2 = space.camera.unproject_position(segment[1])*space.size/Vector2(space.viewport.size)
		spatial_ink_segments.append([a,b])
	for views in line_nodes.values():
		for node in views.values():
			if not node.visible: continue
			var a: Vector2 = space.camera.unproject_position(node.to_global(Vector3.ZERO))*space.size/Vector2(space.viewport.size)
			var b: Vector2 = space.camera.unproject_position(node.to_global(Vector3(0,0,.001)))*space.size/Vector2(space.viewport.size)
			spatial_ink_segments.append([a,b])
	var occupied: Array[Rect2] = []
	var balls: Array[Rect2] = []
	var pixels_per_world: float = space.size.y/space.camera.size
	for note in plane_labels:
		var p: Vector2 = space.camera.unproject_position(note.global_position)*space.size/Vector2(space.viewport.size)
		var reserved_font: int = 49 if note.text.split(" ")[0] in beats[current_beat].get("label_focus",[]) else 36
		var measure: Vector2 = note.font.get_string_size(note.text,HORIZONTAL_ALIGNMENT_LEFT,-1,reserved_font)*note.pixel_size*pixels_per_world
		occupied.append(Rect2(p-measure*.5,measure).grow(5))
	for views in point_nodes.values():
		for entry in views.values():
			if entry.ball.visible:
				var p: Vector2 = space.camera.unproject_position(entry.ball.global_position)*space.size/Vector2(space.viewport.size)
				balls.append(Rect2(p-Vector2(5,5),Vector2(10,10)))
	for views in point_nodes.values():
		for entry in views.values():
			if not entry.label.visible: continue
			var p: Vector2 = space.camera.unproject_position(entry.ball.global_position)*space.size/Vector2(space.viewport.size)
			var reserved_font: int = 49 if entry.label.text in beats[current_beat].get("label_focus",[]) else 36
			var measure: Vector2 = entry.label.font.get_string_size(entry.label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,reserved_font)*entry.label.pixel_size*pixels_per_world
			var layout_id := str(entry.label.get_instance_id())
			var cache: Dictionary = spatial_label_layout.get(layout_id,{})
			if cache.get("text","")!=entry.label.text or cache.get("size",Vector2.ZERO)!=space.size: cache={}
			var best := Vector2.ZERO
			var score := INF
			var candidates: Array[Vector2] = []
			if not cache.is_empty(): candidates.append(cache.target)
			for radius in [0,14,28,44,64]:
				for base in [Vector2(measure.x*.5+8,-measure.y*.5-10),Vector2(measure.x*.5+8,measure.y*.5+10),Vector2(-measure.x*.5-8,-measure.y*.5-10),Vector2(-measure.x*.5-8,measure.y*.5+10),Vector2(0,-measure.y*.5-20),Vector2(0,measure.y*.5+20)]:
					candidates.append(base+base.normalized()*radius)
			for candidate in candidates:
				var rect := Rect2(p+candidate-measure*.5,measure).grow(2)
				var cost: float = candidate.length()
				if not cache.is_empty():
					cost += candidate.distance_to(cache.target)*.5
					if candidate==cache.target: cost=0
				if not Rect2(Vector2.ZERO,space.size).encloses(rect): cost+=1000000
				for avoid in occupied:
					if rect.intersects(avoid): cost+=100000
				for ball in balls:
					if rect.intersects(ball): cost+=100000
				for segment in spatial_ink_segments:
					if preload("res://line_paper.gd").segment_hits_rect(rect.grow(3),segment[0],segment[1]): cost+=100000
				if cost<score: score=cost; best=candidate
			var target_offset: Vector2 = best
			if (manual_camera or phase=="playing") and not cache.is_empty():
				# Replanning may select a distant side. Only the endpoint follows
				# the camera immediately; the relative text offset moves smoothly.
				best=cache.offset.move_toward(target_offset,minf(180.0*delta,8.0))
			spatial_label_layout[layout_id]={"target":target_offset,"offset":best,"text":entry.label.text,"size":space.size}
			entry.label.position=entry.ball.position+space.camera.global_basis.x*best.x/pixels_per_world-space.camera.global_basis.y*best.y/pixels_per_world
			occupied.append(Rect2(p+best-measure*.5,measure).grow(2))
			spatial_label_rects[str(entry.label.get_instance_id())]=Rect2(p+best-measure*.5,measure).grow(2)

func screen_anchor(ref: String) -> Vector2:
	var parts := ref.split(":")
	var view: String = parts[0]
	var key: String = parts[1]
	var spec: Dictionary = geometry.scenes[state.scene]
	var p: Vector3 = geometry.point(state,key)
	if spec.lines.has(key):
		var ends: Array[Vector3] = geometry.ends(state,key); p=(ends[0]+ends[1])*.5
	if view!="space": return paper.global_position+paper.at(Geometry.project(p,view))
	var pixel: Vector2 = space.camera.unproject_position(Geometry.world(p))
	return space.global_position+pixel*space.size/Vector2(space.viewport.size)

func anchor_ends(ref: String) -> Array[Vector2]:
	var parts := ref.split(":")
	var spec: Dictionary = geometry.scenes[state.scene]
	if not spec.lines.has(parts[1]): return [screen_anchor(ref)]
	var pair: Array = spec.lines[parts[1]]
	return [screen_anchor(parts[0]+":"+pair[0]),screen_anchor(parts[0]+":"+pair[1])]

func distance_caption(refs: Array,_paper := true) -> String:
	if refs.size()<2: return ""
	var first := str(refs[0]).split(":"); var second := str(refs[1]).split(":")
	var a: Vector3 = geometry.point(state,first[1]); var b: Vector3 = geometry.point(state,second[1])
	var distance: float = a.distance_to(b) if first[0]=="space" else Geometry.project(a,first[0]).distance_to(Geometry.project(b,first[0]))
	return "%s mm" % (str(roundi(distance)) if is_equal_approx(distance,roundf(distance)) else str(roundf(distance*10)/10))

func protected_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect in paper.label_rects: result.append(Rect2(rect.position+paper.global_position-global_position,rect.size))
	for note in labels:
		if not note.is_visible_in_tree(): continue
		var pixel: Vector2 = space.camera.unproject_position(note.global_position)
		var p: Vector2 = space.global_position+pixel*space.size/Vector2(space.viewport.size)-global_position
		var measure: Vector2 = note.font.get_string_size(note.text,HORIZONTAL_ALIGNMENT_LEFT,-1,note.font_size)*note.pixel_size*space.size.y/space.camera.size
		result.append(Rect2(p-Vector2(measure.x*.5+5,measure.y*.6+5),measure+Vector2(10,10)))
	result.append_array(transition_sweep_rects())
	return result

func transition_sweep_rects() -> Array[Rect2]:
	if beats[current_beat].action.type!="scene": return []
	var key: Array = [current_beat,space.size,space.camera.global_transform,space.camera.size,space.global_position]
	if key==sweep_key: return sweep_rects
	sweep_key=key.duplicate(true); sweep_rects.clear()
	var bounds := Rect2()
	var found := false
	for i in range(9):
		var sample: Dictionary = geometry.transition(before_states[current_beat],after_states[current_beat],float(i)/8)
		for name in sample.points:
			for view in Geometry.VIEWS:
				if float(sample.points[name][view])<=.001: continue
				var p: Vector3 = on_plane(geometry.point(sample,name),view)
				var pixel: Vector2 = space.camera.unproject_position(Geometry.world(p))*space.size/Vector2(space.viewport.size)
				if not found: bounds=Rect2(pixel,Vector2.ZERO); found=true
				else: bounds=bounds.expand(pixel)
	if found:
		# Include the point names' avoidance offsets, not just the moving balls.
		sweep_rects.append(Rect2(bounds.position+space.global_position-global_position,bounds.size).grow(80))
	return sweep_rects

func exit() -> void:
	if not active: return
	epoch+=1
	if tween and tween.is_valid(): tween.kill()
	problem_preparing=false
	active=false; busy=false; phase="idle"
	spatial_label_layout.clear()
	space_tick_points.clear()
	if is_instance_valid(ratio_ticks):ratio_ticks.mesh=null
	sweep_key.clear(); sweep_rects.clear()
	held_keys.clear()
	hide()
	for entry in locked: entry[0].set(entry[1],entry[2])
	locked.clear()
	for note in labels: note.font_size=36; note.modulate=Color("d9e1e7")
	overlay.geometry_key.clear()
	overlay.clear_problem()
	if not "--qa" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(window_state.mode)
		if window_state.mode==DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(window_state.size); DisplayServer.window_set_position(window_state.position)
	r.free_shell.show()
	if return_to_practice:r.free_shell.hide();r.line_workspace.show()
	r.observer.interaction_enabled=true
	r.paper.picking_enabled=true
	r.observer.request_render()
	r.schedule_save()

func reset_lesson_camera() -> void:
	spatial_label_layout.clear()
	manual_camera=false
	space.dragging=false
	space.yaw=-.55
	space.pitch=.38
	space.update_camera()

func emphasis_scale() -> float:
	return 1.0+.35*(.5-.5*cos(emphasis_clock*TAU/1.2))

func update_emphasis(delta := 0.0) -> void:
	var targets: Array = beats[current_beat].get("label_focus",[])
	for note in labels:
		if note.text.split(" ")[0] in targets: note.font_size=roundi(36*emphasis_scale())
	if not targets.is_empty(): space.request_render(); paper.queue_redraw()
	if manual_camera or phase=="playing": place_point_labels(delta); space.request_render()
