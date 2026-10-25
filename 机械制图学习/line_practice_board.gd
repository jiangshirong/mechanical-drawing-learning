extends "res://practice_board.gd"
var task: Dictionary = {}
var helper
var dashed_mode := false
var styles: CheckBox
var memory: Dictionary = {}
var qa_save := false

func create_view(): return preload("res://line_practice_view.gd").new()
func create_canvas(): return preload("res://line_practice_canvas.gd").new()

func _ready() -> void:
	super._ready()
	if readonly: return
	styles=CheckBox.new(); styles.text="辅助线"
	styles.toggled.connect(func(value): dashed_mode=value)
	toolbar.add_child(styles)
	helper=preload("res://line_practice_helper.gd").new(); helper.board=self
	add_child(helper)
	visibility_changed.connect(func(): if not is_visible_in_tree(): helper.cancel())

func load_draft() -> void:
	# Exercise switching explicitly loads its own file after stable layout.
	loading=false

func activate(value: Dictionary) -> void:
	if not task.is_empty():
		cancel_pending(); view.cancel_drag(); save_draft()
		memory[task.id]=snapshot(); memory[task.id]["undo"]=undo_stack.duplicate(true)
		memory[task.id]["blocked"]=blocked_save;memory[task.id]["error"]=error_text
	task=value; question_id=task.id
	save_path=("user://qa-line-task-" if qa_save else "user://line-practice-v1-")+task.id+".json"
	blocked_save=false; error_text=""; initial_fit_pending=false
	document={"lines":[],"points":{}}; selection.clear(); selected={"kind":"","id":"","end":""}; undo_stack.clear()
	if memory.has(task.id):
		restore_snapshot(memory[task.id]); undo_stack=memory[task.id].undo.duplicate(true)
		blocked_save=memory[task.id].blocked;error_text=memory[task.id].error
	else:
		loading=true; initial_fit_pending=true; super.load_draft(); fit_task() if initial_fit_pending else view.apply_transform()
		initial_fit_pending=false
	update_tools(); canvas.queue_redraw()

func fit_task() -> void:
	if task.is_empty() or view.size.y<1: return
	var b: Array = task.bounds
	view.zoom=clampf(minf((view.size.x-40)/((b[2]-b[0])*10),(view.size.y-40)/((b[3]-b[1])*10)),view.minimum_zoom,view.maximum_zoom)
	view.pan=view.size*.5-Canvas.at([(b[0]+b[2])*.5,(b[1]+b[3])*.5])*view.zoom
	view.needs_fit=false; view.previous_size=view.size; view.apply_transform()

func visible_segments() -> Array:
	var result: Array = []
	for line in document.lines: result.append([Vector2(line.a[0],line.a[1]),Vector2(line.b[0],line.b[1])])
	for id in task.get("known_lines",[]):
		var bits: PackedStringArray=id.split("_"); var ends: Array=task.lines[bits[0]]
		var a: Array=task.refs[ends[0]+"_"+bits[1]]; var b: Array=task.refs[ends[1]+"_"+bits[1]]
		if a!=b: result.append([Vector2(a[0],a[1]),Vector2(b[0],b[1])])
	var lo:Vector2=Canvas.mm(-view.pan/view.zoom)
	var hi:Vector2=Canvas.mm((view.size-view.pan)/view.zoom)
	result.append([Vector2(lo.x,0),Vector2(hi.x,0)])
	if task.get("views",[]).has("left"):
		result.append([Vector2(0,hi.y),Vector2(0,lo.y)]);var reach:=maxf(hi.x,-hi.y);result.append([Vector2.ZERO,Vector2(reach,-reach)])
	return result

func exact_snap(p: Vector2) -> Array:
	var mm := Canvas.mm(p); var tolerance:float = 9/(view.zoom*10)
	var candidates: Array = []
	for v in document.points.values(): candidates.append(Vector2(v[0],v[1]))
	for id in task.get("known_points",[]):
		var v: Array=task.refs[id]; candidates.append(Vector2(v[0],v[1]))
	var segments := visible_segments()
	for segment in segments: candidates.append_array(segment)
	for i in range(segments.size()):
		for j in range(i):
			var cross=Geometry2D.segment_intersects_segment(segments[i][0],segments[i][1],segments[j][0],segments[j][1])
			if cross!=null: candidates.append(cross)
	var best:float = tolerance; var target:Vector2=mm; var found := false
	for v in candidates:
		var distance: float=mm.distance_to(v)
		if distance<=best: target=v;best=distance;found=true
	if not found:
		for s in segments:
			var q: Vector2=Geometry2D.get_closest_point_to_segment(mm,s[0],s[1])
			var distance := mm.distance_to(q)
			if distance<best: target=q;best=distance;found=true
	if not found: target=mm.snapped(Vector2(.1,.1))
	return [target.x,target.y]

func snap(p: Vector2,directional := false) -> Array:
	var result := exact_snap(p)
	if directional and pending!=null:
		var d := Vector2(result[0]-pending[0],result[1]-pending[1]); var limit := tan(deg_to_rad(5))
		if absf(d.y)<=absf(d.x)*limit: result[1]=pending[1]
		elif absf(d.x)<=absf(d.y)*limit: result[0]=pending[0]
	return result

func click_content(p: Vector2) -> void:
	if tool=="point" and hit_point(p).is_empty():
		for id in task.get("known_points",[]):
			if p.distance_to(Canvas.at(task.refs[id]))<=9/view.zoom:
				clear_selection();update_tools();return
	var count: int=document.lines.size()
	super.click_content(p)
	if document.lines.size()>count:
		document.lines[-1]["dashed"]=dashed_mode; autosave()

func command(key: String) -> void:
	if helper!=null: helper.cancel()
	super.command(key)

func cancel_pending() -> void:
	if helper!=null: helper.cancel()
	super.cancel_pending()

func valid_save(value) -> bool:
	if not super.valid_save(value): return false
	for line in value.lines:
		if line.has("dashed") and not line.dashed is bool: return false
	return true

func add_result(a: Array,b: Array,is_point := false) -> void:
	var before := document.duplicate(true)
	if is_point:
		var id := "point-"+str(Time.get_ticks_usec()); document.points[id]=a.duplicate()
		if not document.has("point_labels"): document.point_labels={}
		document.point_labels[id]=""; choose_hit({"kind":"point","id":id,"end":""})
	elif a!=b: document.lines.append({"id":"line-"+str(Time.get_ticks_usec()),"a":a.duplicate(),"b":b.duplicate(),"dashed":dashed_mode})
	commit_drag(before)

func save_draft() -> void:
	if task.is_empty() or readonly or loading or initial_fit_pending or blocked_save:return
	if "--qa" in OS.get_cmdline_user_args() and not save_path.begins_with("user://qa-line-task-"):
		push_error("直线练习专项禁止写入正式草稿");return
	var state:Dictionary=view.get_view_state();var center:=Canvas.mm(state.center)
	var saved:Dictionary={"schema_version":1,"question_id":question_id,"lines":document.lines,"points":document.points,"view":{"zoom":state.zoom,"center_mm":[center.x,center.y]}}
	if document.has("point_labels"):saved.point_labels=document.point_labels
	var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved,"\t"));file.close()
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))==OK:return
	error_text="草稿保存失败，请检查本机存储。";update_tools()
