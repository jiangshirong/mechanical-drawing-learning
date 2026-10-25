extends Control
# Screen-space teaching layer. All endpoints come from the lesson's geometry resolver.
const UI = preload("res://ui_style.gd")
var demo
var panel: PanelContainer
var label: RichTextLabel
var cue_points: Array[Vector2] = []
var protected: Array[Rect2] = []
var protected_segments: Array = []
var focus_rects: Array[Rect2] = []
var content_rect := Rect2()
var box_rect := Rect2()
var label_rects: Array[Rect2] = []
var cue_kind := "highlight"
var focus_strength := 0.0
var mm_label := ""
var brace_labels: Array[Rect2] = []
var geometry_key: Array = []
var selecting := false
var copy_hovered := false
var mask: ColorRect
var mask_material: ShaderMaterial
var point_problem:=false
var point_problem_title:Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask = ColorRect.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.show_behind_parent = true
	mask_material = ShaderMaterial.new()
	mask_material.shader = preload("res://points_focus.gdshader")
	mask.material = mask_material
	add_child(mask)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UI.card("f5f7f9","d4dde2",6,1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	label = RichTextLabel.new()
	label.selection_enabled = true
	label.drag_and_drop_selection_enabled = false
	label.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	label.add_theme_color_override("selection_color",Color("c4dce8"))
	label.add_theme_color_override("font_selected_color",Color("203747"))
	label.fit_content = true
	label.scroll_active = false
	label.context_menu_enabled = true
	label.focus_mode = Control.FOCUS_ALL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size",UI.CONCLUSION)
	label.add_theme_color_override("default_color",Color("263747"))
	panel.add_child(label)
	label.mouse_entered.connect(func(): copy_hovered = true)
	label.mouse_exited.connect(func(): copy_hovered = false)
	label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: selecting=event.pressed)
	point_problem_title=Label.new();point_problem_title.text="问题";point_problem_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;point_problem_title.add_theme_font_size_override("font_size",16);point_problem_title.add_theme_color_override("font_color",Color("203f54"));add_child(point_problem_title);point_problem_title.hide()
	resized.connect(func(): geometry_key.clear(); refresh())

func set_copy(value: String) -> void:
	if get_script().resource_path=="res://points_callout.gd":
		point_problem=demo.beats[demo.current_beat].get("callout_kind","")=="problem"
		point_problem_title.visible=point_problem
		var style:=UI.card("a9bdcd" if point_problem else "f5f7f9","688fa8" if point_problem else "d4dde2",6,1)
		style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=34 if point_problem else 10;style.content_margin_bottom=10
		if point_problem:style.border_width_left=3
		panel.add_theme_stylebox_override("panel",style)
	selecting = false
	copy_hovered = false
	label.deselect()
	label.text = value
	label.visible_characters = 0
	geometry_key.clear()
	refresh()

func refresh() -> void:
	if not demo or not demo.active: return
	var b: Dictionary = demo.beats[demo.current_beat]
	var paper: bool = demo.sheet.visible and (demo.kind == "solution" or b.get("show_sheet",false))
	var area: Control = demo.sheet.view if paper else demo.space
	content_rect = Rect2(area.global_position-global_position,area.size)
	cue_points.clear()
	for ref in b.anchor: cue_points.append(demo.screen_anchor(str(ref),paper)-global_position)
	protected = demo.protected_rects(paper,global_position)
	if demo.question.visible:
		var question_rect: Rect2 = demo.question.button.get_global_rect()
		question_rect.position -= global_position
		protected.append(question_rect.grow(4))
	if paper and b.action.type == "line":
		var start: Vector2 = demo.screen_anchor(str(b.action.a),true)-global_position
		var end: Vector2 = demo.screen_anchor(str(b.action.b),true)-global_position
		protected.append(Rect2(start,end-start).abs().grow(9))
		if b.action.has("measure_from"):
			var origin: Vector2 = demo.screen_anchor(b.action.measure_from,true)-global_position
			var target: Vector2 = demo.screen_anchor(b.action.measure_to,true)-global_position
			protected.append(Rect2(origin,target-origin).abs().grow(12))
	cue_kind = str(b.indicators[0])
	if cue_kind == "arc":
		var arc: PackedVector2Array = demo.unfold_arc(str(b.action.plane),global_position)
		for p in arc: protected.append(Rect2(p-Vector2(14,14),Vector2(28,28)))
	focus_strength = demo.hint_progress
	mm_label = demo.distance_caption(b.anchor,paper)
	var key: Array = [content_rect,cue_points.duplicate(),label.text,focus_strength,protected.duplicate()]
	if key == geometry_key: return
	geometry_key = key
	place_copy()
	focus_rects.clear()
	if paper and b.action.type == "line":
		var start: Vector2 = demo.screen_anchor(str(b.action.a),true)-global_position
		var end: Vector2 = demo.screen_anchor(str(b.action.b),true)-global_position
		focus_rects.append(Rect2(start,end-start).abs().grow(25))
	for i in range(cue_points.size()):
		if i+1 < cue_points.size() and cue_kind in ["brace","arrow","equal"]:
			focus_rects.append(Rect2(cue_points[i],cue_points[i+1]-cue_points[i]).abs().grow(35))
		else: focus_rects.append(Rect2(cue_points[i]-Vector2(34,34),Vector2(68,68)))
	if not paper:
		for item in demo.concept.label_bases:
			if item.key not in b.get("label_focus",[]) or not item.label.is_visible_in_tree(): continue
			var pixel: Vector2 = demo.space.camera.unproject_position(item.label.global_position)
			var p: Vector2 = demo.space.global_position+pixel*demo.space.size/Vector2(demo.space.viewport.size)-global_position
			var measure: Vector2 = item.label.font.get_string_size(item.label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.label.font_size)*item.label.pixel_size*demo.space.size.y/demo.space.camera.size
			focus_rects.append(Rect2(p-measure*.5,measure).grow(15))
		for ref in b.focus:
			if ref in ["V","H","W"]:
				var corners: Array[Vector2] = demo.screen_plane(str(ref))
				if not corners.is_empty():
					var rect := Rect2(corners[0]-global_position,Vector2.ZERO)
					for p in corners: rect = rect.expand(p-global_position)
					focus_rects.append(rect.grow(12))
	mask.position = content_rect.position
	mask.size = content_rect.size
	var regions := PackedVector4Array()
	for rect in focus_rects.slice(0,16):
		regions.append(Vector4(rect.position.x-content_rect.position.x,rect.position.y-content_rect.position.y,rect.size.x,rect.size.y))
	while regions.size()<16: regions.append(Vector4.ZERO)
	mask_material.set_shader_parameter("logical_size",content_rect.size)
	mask_material.set_shader_parameter("focus_count",mini(16,focus_rects.size()))
	mask_material.set_shader_parameter("focus_regions",regions)
	queue_redraw()

func copy_size() -> Vector2:
	# Default geometry stays identical for the existing point presentations.
	var font := label.get_theme_font("normal_font")
	var line_size := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,UI.CONCLUSION).x
	var width := clampf(minf(content_rect.size.x*0.34,line_size+28),160,390)
	var rows := maxi(1,ceili(line_size/(width-28)))
	return Vector2(width,float(rows*30+20+(24 if point_problem else 0)))

func place_copy() -> void:
	# Keep the text hit area stable while a learner starts or extends a selection.
	if selecting or copy_hovered: return
	if cue_points.is_empty(): return
	var anchor := Vector2.ZERO
	for p in cue_points: anchor += p
	anchor /= cue_points.size()
	var measured := copy_size()
	var width: float = measured.x
	var height: float = measured.y
	var bounds := content_rect.grow(-18)
	var candidates: Array[Vector2] = [
		anchor+Vector2(42,-height-38),anchor+Vector2(42,38),
		anchor+Vector2(-width-42,-height-38),anchor+Vector2(-width-42,38),
		Vector2(bounds.position.x+12,anchor.y-height/2),Vector2(bounds.end.x-width-12,anchor.y-height/2),
		Vector2(anchor.x-width/2,bounds.position.y+12),Vector2(anchor.x-width/2,bounds.end.y-height-12)]
	# Search the remaining stage when local placements conflict with axis or point labels.
	for x in range(int(bounds.position.x),int(bounds.end.x-width)+1,56):
		for y in range(int(bounds.position.y),int(bounds.end.y-height)+1,40):
			candidates.append(Vector2(x,y))
	var best := Rect2()
	var cost := INF
	for pos in candidates:
		pos = pos.clamp(bounds.position,bounds.end-Vector2(width,height))
		var rect := Rect2(pos,Vector2(width,height))
		var score := rect.get_center().distance_to(anchor)*0.05
		for avoid in protected:
			if rect.grow(10).intersects(avoid): score += 1000000+rect.intersection(avoid).get_area()
		for segment in protected_segments:
			if segment_hits(rect.grow(8),segment[0],segment[1]): score+=1000000
		for p in cue_points:
			if rect.grow(28).has_point(p): score += 20000
		for i in range(cue_points.size()-1):
			if segment_hits(rect.grow(16),cue_points[i],cue_points[i+1]): score += 12000
		if score < cost:
			cost = score
			best = rect
	box_rect = best
	panel.position = best.position
	panel.size = best.size
	point_problem_title.position=best.position+Vector2(14,7)
	label.custom_minimum_size.x = width-28

func segment_hits(rect: Rect2,a: Vector2,b: Vector2) -> bool:
	if rect.has_point(a) or rect.has_point(b): return true
	var c: Array[Vector2] = [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a,b,c[i],c[(i+1)%4]) != null: return true
	return false

func _draw() -> void:
	if cue_points.is_empty() or not demo or not demo.active: return
	brace_labels.clear()
	var color := Color("d06d35") if demo.sheet.visible and demo.kind == "solution" else UI.EMPHASIS
	if demo.sheet.visible and demo.beats[demo.current_beat].get("show_sheet",false): color = Color("d06d35")
	if cue_kind == "brace" or cue_kind == "equal":
		for i in range(0,cue_points.size()-1,2): brace(cue_points[i],cue_points[i+1],color)
	elif cue_kind == "arrow" and cue_points.size() >= 2:
		arrow(cue_points[0],cue_points[1],color)
	elif cue_kind == "arc":
		var points: PackedVector2Array = demo.unfold_arc(str(demo.beats[demo.current_beat].action.plane),global_position)
		draw_polyline(points,color,2,true)
		arrow(points[22],points[24],color)
	else:
		if demo.beats[demo.current_beat].action.type!="line":
			var b: Dictionary = demo.beats[demo.current_beat]
			for i in range(cue_points.size()):
				if str(b.anchor[i]) not in b.get("label_focus",[]): draw_circle(cue_points[i],13,color,false,2,true)
	var action: Dictionary = demo.beats[demo.current_beat].action
	if demo.kind=="solution" and action.has("measure_from") and demo.hint_progress>0:
		var a: Vector2 = demo.screen_anchor(action.measure_from,true)-global_position
		var b: Vector2 = demo.screen_anchor(action.measure_to,true)-global_position
		var end := a.lerp(b,clampf(demo.hint_progress/.4,0,1))
		var length := a.distance_to(end)
		var direction := a.direction_to(end)
		for i in range(ceili(length/8)):
			var start := float(i)*8
			draw_line(a+direction*start,a+direction*minf(start+5,length),Color("263747"),1.1,true)

func arrow(a: Vector2,b: Vector2,color: Color) -> void:
	var d := (b-a).normalized()
	if a.distance_to(b)<2: return
	var offset := Vector2(-d.y,d.x)*10
	a += offset; b += offset
	draw_line(a,b,color,2,true)
	var wing := Vector2(-d.y,d.x)*5
	draw_line(b,b-d*11+wing,color,2,true)
	draw_line(b,b-d*11-wing,color,2,true)

func brace(a: Vector2,b: Vector2,color: Color) -> void:
	var delta := b-a
	if delta.length()<2: return
	var out := Vector2(-delta.y,delta.x).normalized()
	# Prefer the side away from the explanation box.
	if ((a+b)*0.5+out*30).distance_to(box_rect.get_center()) < ((a+b)*0.5-out*30).distance_to(box_rect.get_center()): out = -out
	a += out*19; b += out*19
	var middle := (a+b)*0.5+out*10
	var stops: Array[Vector2] = [a,a+delta*.4+out*5,middle,a+delta*.6+out*5,b]
	var controls: Array = [[a+out*5,a+delta*.25+out*5],[a+delta*.48+out*5,middle],[middle,a+delta*.52+out*5],[a+delta*.75+out*5,b+out*5]]
	for j in range(4):
		var poly := PackedVector2Array()
		for k in range(13):
			var t := float(k)/12.0
			var u := 1-t
			poly.append(stops[j]*u*u*u+controls[j][0]*3*u*u*t+controls[j][1]*3*u*t*t+stops[j+1]*t*t*t)
		draw_polyline(poly,color,1.8,true)
	var caption := mm_label
	if cue_kind == "equal": caption = demo.distance_caption(demo.beats[demo.current_beat].anchor.slice(0,2),demo.kind == "solution" or demo.beats[demo.current_beat].get("show_sheet",false))
	var p := middle+out*20
	var font := get_theme_default_font()
	var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var rect := Rect2(p-Vector2(width/2+5,13),Vector2(width+10,26))
	brace_labels.append(rect)
	draw_style_box(UI.card("f5f7f9","f5f7f9",4,0),rect)
	draw_string(font,p+Vector2(-width/2,6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a35126"))
