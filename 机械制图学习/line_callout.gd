extends "res://points_callout.gd"
const Geometry = preload("res://line_geometry.gd")
# Reuse the established copy placement and real-endpoint braces; geometry is supplied by the line adapter.
var angle_label := ""
var positioned_copy := ""
var positioned_bounds := Rect2()
var callout_kind := "normal"
var problem_title: Label
var normal_style: StyleBoxFlat
var problem_style: StyleBoxFlat
var problem_sweep_key: Array = []
var problem_sweep: Array[Rect2] = []
var problem_ready_frame := 0
var conditions: Array = []
var condition_layer

func _ready() -> void:
	super._ready()
	normal_style=panel.get_theme_stylebox("panel").duplicate()
	problem_style=UI.card("a9bdcd","688fa8",6,1)
	problem_style.border_width_left=3
	problem_style.border_color=Color("688fa8")
	problem_style.content_margin_left=14; problem_style.content_margin_right=14
	problem_style.content_margin_top=10; problem_style.content_margin_bottom=10
	panel.remove_child(label)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	problem_title=Label.new()
	problem_title.text="问题"
	problem_title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	problem_title.add_theme_font_size_override("font_size",UI.CAPTION)
	problem_title.add_theme_color_override("font_color",Color("203f54"))
	column.add_child(problem_title)
	column.add_child(label)
	label.size_flags_vertical=Control.SIZE_EXPAND_FILL
	problem_title.hide()
	condition_layer=preload("res://line_condition_rows.gd").new()
	condition_layer.overlay=self
	label.add_child(condition_layer)

func set_copy(value: String) -> void:
	callout_kind=str(demo.beats[demo.current_beat].get("callout_kind","normal"))
	conditions=demo.beats[demo.current_beat].get("problem_conditions",[]).duplicate()
	if callout_kind=="problem":
		positioned_copy=""
		# Containers and native text recalculate their minimum sizes on the
		# first layout frames, before the first character is due at 16/s.
		problem_ready_frame=Engine.get_process_frames()+3
	problem_title.visible=callout_kind=="problem"
	panel.add_theme_stylebox_override("panel",problem_style if problem_title.visible else normal_style)
	super.set_copy(value)

func clear_problem() -> void:
	callout_kind="normal"
	conditions.clear()
	condition_layer.rows.clear(); condition_layer.queue_redraw()
	problem_title.hide()
	panel.add_theme_stylebox_override("panel",normal_style)
	protected_segments.clear(); problem_sweep_key.clear(); problem_sweep.clear()
	positioned_copy=""; positioned_bounds=Rect2()
	problem_ready_frame=0
	selecting=false; copy_hovered=false

func copy_size() -> Vector2:
	if callout_kind!="problem": return super.copy_size()
	var font := label.get_theme_font("normal_font")
	var longest := 0.0
	for row in label.text.split("\n"):
		longest=maxf(longest,font.get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,UI.CONCLUSION).x)
	var width := clampf(minf(content_rect.size.x*.34,longest+28),160,390)
	var body: Vector2 = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,width-28,UI.CONCLUSION)
	var title_height: float = problem_title.get_minimum_size().y
	return Vector2(width,ceilf(body.y)+title_height+6+20+4)

func protect_problem() -> void:
	protected_segments.clear()
	if callout_kind!="problem": return
	var paper_delta: Vector2 = demo.paper.global_position-global_position
	for segment in demo.paper.ink_segments:
		protected_segments.append([segment[0]+paper_delta,segment[1]+paper_delta])
	var space_delta: Vector2 = demo.space.global_position-global_position
	for segment in demo.spatial_ink_segments:
		protected_segments.append([segment[0]+space_delta,segment[1]+space_delta])
	var key: Array = [demo.current_beat,demo.paper.zoom,demo.paper.offset,demo.paper.size,demo.paper.global_position]
	if problem_sweep_key!=key:
		problem_sweep_key=key.duplicate(true); problem_sweep.clear()
		for view in ["front","top","left"]:
			var bounds := Rect2()
			var found := false
			for i in range(9):
				var sample: Dictionary = demo.geometry.transition(demo.before_states[demo.current_beat],demo.after_states[demo.current_beat],float(i)/8)
				for name in sample.points:
					if float(sample.points[name][view])<=.001: continue
					var p: Vector2 = demo.paper.at(Geometry.project(demo.geometry.point(sample,name),view))
					if not found: bounds=Rect2(p,Vector2.ZERO); found=true
					else: bounds=bounds.expand(p)
			if found: problem_sweep.append(Rect2(bounds.position+paper_delta,bounds.size).grow(28))
	protected.append_array(problem_sweep)

func refresh() -> void:
	if not demo or not demo.active or demo.state.is_empty(): return
	condition_layer.queue_redraw()
	var b: Dictionary = demo.beats[demo.current_beat]
	content_rect=Rect2(demo.stage.global_position-global_position,demo.stage.size)
	cue_points.clear(); focus_rects.clear()
	for ref in b.anchor:
		for p in demo.anchor_ends(ref): cue_points.append(p-global_position)
	protected=demo.protected_rects()
	protect_problem()
	cue_kind=b.indicators[0]
	mm_label=demo.distance_caption(b.anchor)
	var layout_frame: int = Engine.get_process_frames() if callout_kind=="problem" and Engine.get_process_frames()<problem_ready_frame else -1
	var key: Array = [content_rect,cue_points.duplicate(),label.text,protected.duplicate(),protected_segments.duplicate(),demo.state,callout_kind,layout_frame]
	if key==geometry_key: return
	geometry_key=key.duplicate(true)
	place_copy()
	for ref in b.focus:
		var ends: Array[Vector2] = demo.anchor_ends(ref)
		var rect := Rect2(ends[0]-global_position,Vector2.ZERO)
		for p in ends: rect=rect.expand(p-global_position)
		focus_rects.append(rect.grow(30))
	for rect in protected:
		for p in cue_points:
			if rect.grow(25).has_point(p): focus_rects.append(rect.grow(8))
	mask.position=content_rect.position; mask.size=content_rect.size
	var regions := PackedVector4Array()
	for rect in focus_rects.slice(0,16): regions.append(Vector4(rect.position.x-content_rect.position.x,rect.position.y-content_rect.position.y,rect.size.x,rect.size.y))
	while regions.size()<16: regions.append(Vector4.ZERO)
	mask_material.set_shader_parameter("logical_size",content_rect.size)
	mask_material.set_shader_parameter("focus_count",mini(16,focus_rects.size()))
	mask_material.set_shader_parameter("focus_regions",regions)
	queue_redraw()

func _draw() -> void:
	if not demo or not demo.active or cue_points.is_empty(): return
	brace_labels.clear()
	var color := Color("d06d35")
	if cue_kind=="brace" and cue_points.size()>=2: brace(cue_points[0],cue_points[1],color)
	elif cue_kind=="angle" and cue_points.size()>=3:
		var a: Vector2 = cue_points[0]
		var start: float = (cue_points[2]-a).angle()
		var delta: float = wrapf((cue_points[1]-a).angle()-start,-PI,PI)
		draw_arc(a,35,start,start+delta,32,color,2,true)
		angle_label="%d°" % roundi(absf(rad_to_deg(delta)))
		var at := a+Vector2.from_angle(start+delta*.5)*56
		draw_string(get_theme_default_font(),at+Vector2(-12,5),angle_label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	# Highlight is carried by the actual entities and regional mask, without redundant rings.

func place_copy() -> void:
	var beat: Dictionary = demo.beats[demo.current_beat]
	var beside_space: bool = beat.anchor.any(func(ref): return str(ref).begins_with("space:"))
	# A manually rotated model changes the avoidance score every frame. Keep
	# this beat's existing text position; cues still follow real geometry.
	# A new viewport or new copy gets a fresh layout, as does stepping/reset.
	var transforming: bool = demo.phase=="playing" and beat.action.type=="scene"
	# The complete preparation trajectory has already been reserved. Keep the
	# question at its initial position through the resulting pause as well.
	var layout_stable: bool = callout_kind!="problem" or Engine.get_process_frames()>=problem_ready_frame
	if beside_space and layout_stable and (demo.manual_camera or transforming or callout_kind=="problem") and positioned_copy==label.text and positioned_bounds==content_rect and box_rect.has_area(): return
	super.place_copy()
	positioned_copy=label.text
	positioned_bounds=content_rect
