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
var held: Dictionary = {}
var window_state: Dictionary

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new();add_child(column)
	stage=HBoxContainer.new();stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stage)
	sheet=preload("res://line_practice_board.gd").new();sheet.readonly=true;stage.add_child(sheet)
	heading=Label.new();heading.add_theme_font_size_override("font_size",UI.CAPTION);column.add_child(heading)
	var row:=HBoxContainer.new();column.add_child(row)
	row.add_child(r.btn("退出",exit))
	progress=preload("res://points_progress.gd").new();progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress.chapter_chosen.connect(jump);row.add_child(progress)
	previous=r.btn("上一步",retreat);next=r.btn("下一步",advance)
	for pair in [[previous,"A"],[next,"D"]]:
		UI.teaching_navigation(pair[0]);pair[0].focus_mode=Control.FOCUS_NONE;row.add_child(pair[0]);var key:=Label.new();key.text=pair[1];key.add_theme_font_size_override("font_size",UI.CAPTION);row.add_child(key)
	overlay=preload("res://line_solution_callout.gd").new();overlay.demo=self;add_child(overlay)
	# The question widget reads the current task at entry, never a different exercise.
	config={"statement":""};question=preload("res://points_question.gd").new();question.demo=self;add_child(question)
	resized.connect(func():if active:call_deferred("fit_sheet"))
	hide()

func enter(value: Dictionary) -> void:
	if active or r.presentation_active():return
	r.hide_source()
	task=value;config={"statement":task.statement};question.label.text=task.statement;question.reset()
	r.line_workspace.board.cancel_pending();r.line_workspace.board.save_draft()
	r.line_workspace.hide();r.free_shell.hide()
	window_state={"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	if not "--qa" in OS.get_cmdline_user_args():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	sheet.task=task;beats.clear();before_states.clear();after_states.clear();tick_items.clear();sheet.canvas.primitives.clear()
	var count:=0.0;var guides:Dictionary={}
	for i in range(task.groups.size()):
		for raw in task.groups[i].beats:
			var b:Dictionary=raw.duplicate(true);b.group=i;beats.append(b);before_states.append(count)
			var a:Dictionary=b.action
			if a.type=="prepare" and task.known_lines.is_empty():a.type="none"
			if a.type!="none":
				if a.type=="line":
					var item:Dictionary={"kind":"line","a":task.refs[a.a],"b":task.refs[a.b],"order":count,"step":beats.size()-1,"dashed":a.dashed,"id":a.id}
					sheet.canvas.primitives.append(item);guides[a.id]=item
				elif a.type=="point":sheet.canvas.primitives.append({"kind":"point","p":task.refs[a.p],"name":a.name,"order":count,"step":beats.size()-1})
				elif a.type=="side_point":sheet.canvas.primitives.append({"kind":"transfer","paths":preload("res://line_transfer.gd").path(task.refs,a),"p":task.refs[a.side],"name":a.name,"order":count,"step":beats.size()-1})
				elif a.type=="erase":
					for j in range(a.targets.size()):
						if guides.has(a.targets[j]):
							guides[a.targets[j]].erase_order=count;guides[a.targets[j]].erase_index=j;guides[a.targets[j]].erase_count=a.targets.size()
				elif a.type=="ticks":tick_items.append({"order":count,"action":a})
				count+=1
			after_states.append(count)
	active=true;show();progress.configure(task.groups);current_beat=0;prepare()

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
	apply_state(before_states[current_beat])
	var b:Dictionary=beats[current_beat]
	heading.text="%d / %d · %s" % [b.group+1,task.groups.size(),task.groups[b.group].title];progress.set_current(b.group)
	overlay.set_copy(b.text);typing_schedule.clear();typing_clock=0
	var clock:=0.0
	for ch in b.text:
		clock+=1.0/16;typing_schedule.append(clock)
		if ch in "，。；：！？":clock+=.18
	phase="typing";update_controls();call_deferred("fit_sheet")
	if b.action.type=="prepare":play(true)

func _process(delta: float) -> void:
	if not active:return
	if phase=="typing":
		typing_clock+=delta
		while overlay.label.visible_characters<typing_schedule.size() and typing_clock>=typing_schedule[overlay.label.visible_characters]:overlay.label.visible_characters+=1
		if overlay.label.visible_characters==typing_schedule.size() and typing_clock>=typing_schedule[-1]+.18:
			phase="playing" if preparing else ("settled" if beats[current_beat].action.type=="prepare" else "ready" if has_action() else "complete" if current_beat==beats.size()-1 else "settled")
			update_controls()

func has_action() -> bool:return before_states[current_beat]!=after_states[current_beat]

func apply_state(value: float) -> void:
	sheet.canvas.progress=value
	sheet.canvas.known_progress=clampf(value,0,1) if not task.known_lines.is_empty() else 1
	sheet.canvas.tick_points.clear()
	for item in tick_items:
		var amount:=clampf(value-item.order,0,1);var a:Dictionary=item.action
		sheet.canvas.tick_direction=Vector2(task.refs[a.b][0]-task.refs[a.a][0],task.refs[a.a][1]-task.refs[a.b][1])
		for ref in a.points.slice(0,int(ceil(amount*a.points.size()))):sheet.canvas.tick_points.append(task.refs[ref])
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
		phase="playing" if preparing else ("settled" if beats[current_beat].action.type=="prepare" else "ready" if has_action() else "complete" if current_beat==beats.size()-1 else "settled")
		if preparing:finish()
		update_controls();return true
	if phase=="playing":finish();return true
	return false

func advance() -> void:
	if not active or complete_busy():return
	if phase=="ready":play();return
	if current_beat<beats.size()-1:current_beat+=1;prepare()

func retreat() -> void:
	if not active or complete_busy():return
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
	for segment in sheet.canvas.known_segments:result.append([tr*segment[0]-offset,tr*segment[1]-offset])
	for item in sheet.canvas.primitives:
		if item.kind=="line" and item.order<after_states[current_beat] and sheet.canvas.erased_fraction(item)<1:result.append([tr*sheet.canvas.at(item.a)-offset,tr*sheet.canvas.at(item.b)-offset])
		elif item.kind=="transfer" and item.order==before_states[current_beat]:
			for path in item.paths:result.append([tr*sheet.canvas.at(path[0])-offset,tr*sheet.canvas.at(path[1])-offset])
	return result

func exit() -> void:
	if not active:return
	epoch+=1
	if tween and tween.is_valid():tween.kill()
	active=false;phase="idle";preparing=false;held.clear();question.reset();hide()
	sheet.canvas.primitives.clear();sheet.canvas.tick_points.clear();overlay.title.hide()
	if not "--qa" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(window_state.mode)
		if window_state.mode==DisplayServer.WINDOW_MODE_WINDOWED:DisplayServer.window_set_size(window_state.size);DisplayServer.window_set_position(window_state.position)
	r.line_workspace.show()
