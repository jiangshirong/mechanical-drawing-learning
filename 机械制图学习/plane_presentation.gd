extends MarginContainer
const UI=preload("res://ui_style.gd")
var r
var active := false
var kind := "solution"
var task: Dictionary
var config: Dictionary
var sheet
var stage
var overlay
var question
var progress
var previous: Button
var next: Button
var heading: Label
var beats: Array = []
var before_states: Array = []
var after_states: Array = []
var tick_items: Array = []
var current_beat := 0
var phase := "idle"
var typing_schedule: Array[float] = []
var typing_clock := 0.0
var hint_progress := 0.0
var epoch := 0
var tween: Tween
var preparing := false
var space
var spatial
var lesson:Dictionary={}
var scenes:Dictionary={}
var scene_id:=""
var groups:Array=[]
var compiled:Dictionary={}
var scene_starts:Dictionary={}
var source_scene:Dictionary={}
var return_list:=false
var held: Dictionary = {}
var window_state: Dictionary

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new();add_child(column)
	stage=HBoxContainer.new();stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stage)
	space=preload("res://observer.gd").new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;space.size_flags_vertical=Control.SIZE_EXPAND_FILL;space.rotation_only=true;space.picking_enabled=false;stage.add_child(space)
	spatial=preload("res://plane_space.gd").new();space.add_child(spatial);spatial.setup(self)
	sheet=preload("res://plane_board.gd").new();sheet.readonly=true;sheet.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.add_child(sheet)
	heading=Label.new();heading.add_theme_font_size_override("font_size",UI.CAPTION);column.add_child(heading)
	var row:=HBoxContainer.new();column.add_child(row)
	row.add_child(r.btn("退出",exit))
	progress=preload("res://points_progress.gd").new();progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress.chapter_chosen.connect(jump);row.add_child(progress)
	previous=r.btn("上一步",retreat);next=r.btn("下一步",advance)
	for pair in [[previous,"A"],[next,"D"]]:
		UI.teaching_navigation(pair[0]);pair[0].focus_mode=Control.FOCUS_NONE;row.add_child(pair[0]);var key:=Label.new();key.text=pair[1];key.add_theme_font_size_override("font_size",UI.CAPTION);row.add_child(key)
	overlay=preload("res://plane_callout.gd").new();overlay.demo=self;add_child(overlay)
	# The question widget reads the current task at entry, never a different exercise.
	config={"statement":""};question=preload("res://points_question.gd").new();question.demo=self;add_child(question)
	resized.connect(func():if active:call_deferred("fit_sheet"))
	hide()

func enter(value:Dictionary={}) -> void:
	if active or r.presentation_active() or r.map_active:return
	r.hide_source();return_list=r.plane_questions.visible;r.plane_questions.hide();r.free_shell.hide()
	r.observer.interaction_enabled=false;r.paper.picking_enabled=false
	if kind=="concept":
		lesson=r.plane_config;groups=lesson.concept;scenes=lesson.scenes
	else:
		lesson=value;groups=value.groups;scenes={value.id:value}
	config={"statement":value.get("statement","")};question.label.text=config.statement;question.reset();question.visible=kind=="solution"
	space.visible=kind=="concept"
	window_state={"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	if not "--qa" in OS.get_cmdline_user_args():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	beats.clear();before_states.clear();after_states.clear();compiled.clear();scene_starts.clear()
	var count:=0.0;var last_scene:="";var last_final:Dictionary={}
	for i in range(groups.size()):
		for raw in groups[i].beats:
			var beat:Dictionary=raw.duplicate(true);beat.group=i;beat.scene=raw.get("scene",value.get("id",""))
			if beat.scene!=last_scene:
				count=0;compiled[beat.scene]=[];scene_starts[beat.scene]=last_final.duplicate(true);last_scene=beat.scene
			beats.append(beat);before_states.append(count)
			count=compile_action(beat.action,compiled[beat.scene],count)
			after_states.append(count);last_final=scenes[beat.scene]
	active=true;show();progress.configure(groups);current_beat=0
	if kind=="concept":
		var target:String=lesson.get("knowledge_resume_aliases",{}).get(r.plane_step_id,r.plane_step_id)
		for i in range(beats.size()):
			if beats[i].id==target:current_beat=i;break
	prepare()

func compile_action(action:Dictionary,items:Array,count:float)->float:
	if action.type=="space_project":
		for i in range(action.vertices.size()):
			var vertex:String=action.vertices[i]
			items.append({"kind":"space_point","ref":vertex+"_"+action.view,"vertex":vertex,"view":action.view,"name":vertex.to_lower()+{"front":"′","top":"","left":"″"}[action.view],"order":count+i,"ray_end_order":count+action.vertices.size()})
		return count+action.vertices.size()
	if action.type=="sequence":
		for part in action.actions:count=compile_action(part,items,count)
		return count
	if action.type=="line":items.append({"kind":"line","ar":action.a,"br":action.b,"id":action.id,"dashed":action.get("dashed",false),"order":count})
	elif action.type=="outline":
		for path in action.paths:items.append({"kind":"line","ar":path[0],"br":path[1],"order":count})
		for point in action.get("points",[]):items.append({"kind":"point","ref":point.ref,"name":point.name,"order":count,"threshold":.64})
	elif action.type=="point":items.append({"kind":"point","ref":action.p,"name":action.name,"order":count})
	elif action.type=="points":
		for point in action.points:items.append({"kind":"point","ref":point.ref,"name":point.name,"order":count})
	elif action.type=="project_points":
		for target in action.targets:items.append({"kind":"transfer","path_refs":target.paths,"ref":target.ref,"name":target.name,"order":count})
	elif action.type=="erase":
		for item in items:
			if item.get("id","") in action.targets or item.get("ref","") in action.get("points",[]):item.erase_order=count;item.erase_index=0;item.erase_count=1
	return count+1 if action.type!="none" else count

func fit_sheet() -> void:
	var captured:=epoch;await get_tree().process_frame
	if not active or captured!=epoch:return
	sheet.fit_task()
	# Leave comfortable whitespace around actual drawing for screen-sized copy.
	sheet.view.zoom*=.78;sheet.view.pan=sheet.view.size*.5-sheet.canvas.at([(task.bounds[0]+task.bounds[2])*.5,(task.bounds[1]+task.bounds[3])*.5])*sheet.view.zoom;sheet.view.apply_transform()
	overlay.placed=-1;overlay.refresh()

func prepare() -> void:
	epoch+=1
	if tween and tween.is_valid():tween.kill()
	preparing=false;question.reset();hint_progress=0
	scene_id=beats[current_beat].scene;task=scenes[scene_id].duplicate(true);sheet.task=task;sheet.canvas.primitives=compiled[scene_id];source_scene=scene_starts[scene_id]
	if kind=="concept":
		r.plane_step_id=beats[current_beat].id;r.schedule_save();space.yaw=-.48;space.pitch=.38;space.target=Vector3(-.022,.020,.014);space.zoom=.12;space.update_camera();spatial.offsets.clear()
	apply_state(before_states[current_beat])
	var b:Dictionary=beats[current_beat]
	heading.text="%d / %d · %s" % [b.group+1,groups.size(),groups[b.group].title];progress.set_current(b.group)
	overlay.set_copy(b.text);typing_schedule.clear();typing_clock=0
	var clock:=0.0
	for ch in b.text:
		clock+=1.0/16;typing_schedule.append(clock)
		if ch in "，。；：！？":clock+=.18
	phase="typing";update_controls();call_deferred("fit_sheet")
	if b.action.type=="prepare" and b.callout_kind=="problem":play(true)

func _process(delta: float) -> void:
	if not active:return
	if kind=="concept":spatial.update_geometry()
	if phase=="typing":
		typing_clock+=delta
		while overlay.label.visible_characters<typing_schedule.size() and typing_clock>=typing_schedule[overlay.label.visible_characters]:overlay.label.visible_characters+=1
		if overlay.label.visible_characters==typing_schedule.size() and typing_clock>=typing_schedule[-1]+.18:
			phase="playing" if preparing else ("ready" if has_action() and sheet.canvas.progress<after_states[current_beat] else "complete" if current_beat==beats.size()-1 else "settled")
			update_controls()

func has_action() -> bool:return before_states[current_beat]!=after_states[current_beat]

func apply_state(value:float)->void:
	sheet.canvas.progress=value;sheet.canvas.known_progress=1 if kind=="concept" and beats[current_beat].action.type=="prepare" and beats[current_beat].callout_kind!="problem" else clampf(value,0,1)
	var target:Dictionary=scenes[scene_id]
	task.points=preload("res://plane_space.gd").morph(source_scene,target,clampf(value,0,1)) if kind=="concept" else target.points
	for n in task.points:
		var p:Array=task.points[n]
		task.refs[n+"_front"]=[p[0],p[2]];task.refs[n+"_top"]=[p[0],p[1]];task.refs[n+"_left"]=[-p[1],p[2]]
		if task.refs.has(n+"45"):task.refs[n+"45"]=[-p[1],p[1]]
	for item in sheet.canvas.primitives:
		if item.kind=="line":item.a=task.refs[item.ar];item.b=task.refs[item.br]
		elif item.kind=="transfer":
			item.paths=[]
			for path in item.path_refs:item.paths.append([task.refs[path[0]],task.refs[path[1]]])
	sheet.canvas.queue_redraw()

func play(alongside := false) -> void:
	preparing=alongside
	if not alongside:phase="playing"
	update_controls();var captured:=epoch
	tween=create_tween();tween.tween_method(func(amount:float):
		if active and captured==epoch:hint_progress=amount;apply_state(lerpf(before_states[current_beat],after_states[current_beat],amount))
	,0.0,1.0,float(beats[current_beat].action.get("duration",1.1))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():if active and captured==epoch:finish())

func finish() -> void:
	if tween and tween.is_valid():tween.kill()
	epoch+=1;apply_state(after_states[current_beat]);hint_progress=1
	var writing:=preparing and phase=="typing"
	preparing=false
	if not writing:phase="complete" if current_beat==beats.size()-1 else "settled"
	update_controls()

func complete_busy() -> bool:
	if phase=="typing":
		overlay.label.visible_characters=-1
		phase="playing" if preparing else ("ready" if has_action() and sheet.canvas.progress<after_states[current_beat] else "complete" if current_beat==beats.size()-1 else "settled")
		if preparing:finish()
		update_controls();return true
	if phase=="playing":finish();return true
	return false

func reset_camera()->void:
	if kind=="concept":space.yaw=-.48;space.pitch=.38;space.update_camera()

func advance() -> void:
	if not active:return
	reset_camera()
	if complete_busy():return
	if phase=="ready":play();return
	if current_beat<beats.size()-1:current_beat+=1;prepare()

func retreat() -> void:
	if not active:return
	reset_camera()
	if complete_busy():return
	if current_beat>0:current_beat-=1;prepare()

func jump(index: int) -> void:
	for i in range(beats.size()):
		if beats[i].group==index:current_beat=i;prepare();return

func update_controls() -> void:
	previous.disabled=current_beat==0 and phase not in ["typing","playing"]
	next.disabled=phase=="complete"

func handle_key(event: InputEventKey) -> void:
	var code:int=event.physical_keycode if event.physical_keycode else event.keycode
	if not event.pressed:held.erase(code);return
	if event.echo or held.has(code) or event.ctrl_pressed or event.shift_pressed or event.alt_pressed or event.meta_pressed:return
	held[code]=true
	if code==KEY_A:retreat()
	elif code==KEY_D:advance()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:held.clear()

func screen_anchor(ref: String,_paper:bool) -> Vector2:return sheet.canvas.get_global_transform_with_canvas()*sheet.canvas.at(task.refs.get(ref,[0,0]))

func protected_rects(_paper:bool,offset:Vector2) -> Array[Rect2]:
	var result:Array[Rect2]=[];var tr:Transform2D=sheet.canvas.get_global_transform_with_canvas()
	for rect in sheet.canvas.student_label_rects:result.append(Rect2(tr*rect.position-offset,rect.size*sheet.view.zoom))
	if kind=="concept" and beats[current_beat].action.type=="prepare" and not source_scene.is_empty():
		var sweep:=Rect2();var started:=false
		for amount in [0.0,.25,.5,.75,1.0]:
			var pts:Dictionary=preload("res://plane_space.gd").morph(source_scene,scenes[scene_id],amount)
			for n in task.vertices:
				var p:Array=pts[n]
				for v in task.views:
					var ref:Array=[p[0],p[2]] if v=="front" else [p[0],p[1]] if v=="top" else [-p[1],p[2]]
					var pos:Vector2=tr*sheet.canvas.at(ref)-offset
					if not started:sweep=Rect2(pos,Vector2.ZERO);started=true
					else:sweep=sweep.expand(pos)
		if started:result.append(sweep.grow(30))
	for item in sheet.canvas.primitives:
		if item.kind in ["point","transfer","space_point"] and item.order<after_states[current_beat] and sheet.canvas.erased_fraction(item)<1:
			result.append(Rect2(screen_anchor(item.ref,true)-offset-Vector2(80,80),Vector2(160,160)))
	for ref in task.known_points:result.append(Rect2(screen_anchor(ref,true)-offset-Vector2(30,35),Vector2(65,65)))
	result.append(Rect2(screen_anchor("O",true)-offset-Vector2(24,25),Vector2(52,52)))
	result.append(Rect2(question.button.global_position-offset,question.button.size).grow(8))
	var area:=Rect2(sheet.view.global_position-offset,sheet.view.size);var origin:=screen_anchor("O",true)-offset
	result.append(Rect2(Vector2(area.position.x+15,origin.y-35),Vector2(48,38)))
	if task.views.has("left"):
		result.append(Rect2(Vector2(area.end.x-70,origin.y-35),Vector2(70,38)))
		result.append(Rect2(Vector2(origin.x+3,area.position.y+8),Vector2(45,40)))
		result.append(Rect2(Vector2(origin.x+3,area.end.y-42),Vector2(68,42)))
	if beats[current_beat].action.type in ["point","side_point"]:
		var ref:String=beats[current_beat].action.get("p",beats[current_beat].action.get("side","O"))
		result.append(Rect2(screen_anchor(ref,true)-offset-Vector2(48,42),Vector2(96,84)))
	return result

func protected_lines(offset:Vector2) -> Array:
	var result:Array=[];var tr:Transform2D=sheet.canvas.get_global_transform_with_canvas()
	var origin:=screen_anchor("O",true)-offset;var area:=Rect2(sheet.view.global_position-offset,sheet.view.size)
	result.append([Vector2(area.position.x,origin.y),Vector2(area.end.x,origin.y)])
	if task.views.has("left"):
		result.append([Vector2(origin.x,area.position.y),Vector2(origin.x,area.end.y)])
		result.append([origin,origin+Vector2.ONE*maxf(area.size.x,area.size.y)])
	for id in task.known_lines:
		var bits:PackedStringArray=id.split("_");var ends:Array=task.lines[bits[0]]
		result.append([screen_anchor(ends[0]+"_"+bits[1],true)-offset,screen_anchor(ends[1]+"_"+bits[1],true)-offset])
	for guide in task.get("known_guides",[]):result.append([screen_anchor(guide[0],true)-offset,screen_anchor(guide[1],true)-offset])
	for item in sheet.canvas.primitives:
		if item.kind=="line" and item.order<after_states[current_beat] and sheet.canvas.erased_fraction(item)<1:result.append([tr*sheet.canvas.at(item.a)-offset,tr*sheet.canvas.at(item.b)-offset])
		elif item.kind=="transfer" and item.order==before_states[current_beat]:
			for path in item.paths:result.append([tr*sheet.canvas.at(path[0])-offset,tr*sheet.canvas.at(path[1])-offset])
	return result

func exit()->void:
	if not active:return
	epoch+=1
	if tween and tween.is_valid():tween.kill()
	active=false;phase="idle";preparing=false;held.clear();question.reset();hide();overlay.title.hide()
	spatial.offsets.clear();space.dragging=false
	spatial.projection_rays.clear();spatial.projection_strokes.mesh=null
	if not "--qa" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(window_state.mode)
		if window_state.mode==DisplayServer.WINDOW_MODE_WINDOWED:DisplayServer.window_set_size(window_state.size);DisplayServer.window_set_position(window_state.position)
	if kind=="solution" or return_list:r.plane_questions.show()
	else:r.plane_questions.observe()
