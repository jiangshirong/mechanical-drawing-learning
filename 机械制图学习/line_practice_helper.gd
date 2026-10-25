extends Control
const UI=preload("res://ui_style.gd")
var board
var panel: PanelContainer
var mode := ""
var picks: Array = []
var direction := Vector2.ZERO
var reference_segment:Array=[]
var endpoint: Array = []
var preview_ready := false
var hint: Label
var fields: Dictionary = {}
var confirm: Button
var result: Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var entry := Button.new(); entry.text="辅助"; entry.focus_mode=Control.FOCUS_NONE
	board.toolbar.add_child(entry)
	entry.pressed.connect(func():
		if panel.visible: cancel()
		else: panel.show())
	panel=PanelContainer.new(); panel.set_as_top_level(true)
	panel.add_theme_stylebox_override("panel",UI.card("e3ebf1","7d9bad",6,1)); panel.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	var tabs := HBoxContainer.new(); column.add_child(tabs)
	for pair in [["量取","measure"],["定长定角","fixed"],["平行线","parallel"],["比例点","ratio"]]:
		var button := Button.new(); button.text=pair[0];button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(func(): start(pair[1]));tabs.add_child(button)
	hint=Label.new(); hint.text="选择辅助操作"; hint.add_theme_color_override("font_color",Color("263747"));column.add_child(hint)
	var grid := GridContainer.new(); grid.columns=4;column.add_child(grid)
	for spec in [["length","长度(mm)",30.0,.01,10000.0],["angle","夹角(°)",30.0,0.0,90.0],["ratio_a","AC",2.0,.01,10000.0],["ratio_b","CB",3.0,.01,10000.0]]:
		var caption := Label.new(); caption.text=spec[1];caption.add_theme_color_override("font_color",Color("263747"));grid.add_child(caption)
		var spin := SpinBox.new();spin.min_value=spec[3];spin.max_value=spec[4];spin.step=.01;spin.value=spec[2];spin.custom_minimum_size.x=95
		spin.value_changed.connect(func(_v): preview_ready=false; update_preview())
		grid.add_child(spin);fields[spec[0]]=[caption,spin]
	result=Label.new(); result.add_theme_color_override("font_color",Color("263747"));column.add_child(result)
	var row := HBoxContainer.new();column.add_child(row)
	confirm=Button.new();confirm.text="确认";confirm.focus_mode=Control.FOCUS_NONE;confirm.pressed.connect(commit);row.add_child(confirm)
	var leave := Button.new();leave.text="取消";leave.focus_mode=Control.FOCUS_NONE;leave.pressed.connect(cancel);row.add_child(leave)
	panel.hide();update_fields()

func _process(_delta: float) -> void:
	if panel.visible:
		panel.position=board.view.global_position+Vector2(maxf(8,board.view.size.x-panel.size.x-12),12)
		confirm.disabled=not preview_ready or mode=="measure"

func cancel() -> void:
	mode="";picks.clear();endpoint.clear();direction=Vector2.ZERO;reference_segment.clear();preview_ready=false
	if panel: panel.hide()
	if board.canvas: board.canvas.queue_redraw()

func start(value: String) -> void:
	board.cancel_pending()
	mode=value;panel.show();picks.clear();endpoint.clear();direction=Vector2.ZERO;reference_segment.clear();preview_ready=false;result.text=""
	update_fields()
	hint.text={"measure":"依次选两个位置","fixed":"选起点，再点击方向象限","parallel":"选参考线，再选通过点和终点","ratio":"依次选线段起点A、终点B"}[mode]

func update_fields() -> void:
	for key in fields:
		var show_field: bool=(mode=="fixed" and key in ["length","angle"]) or (mode=="ratio" and key in ["ratio_a","ratio_b"])
		for node in fields[key]: node.visible=show_field
	confirm.visible=mode!="measure"

func vector(p: Array) -> Vector2: return Vector2(p[0],p[1])

func handle_canvas(event: InputEvent) -> bool:
	if mode.is_empty(): return false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: return false
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: cancel();return true
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: choose((event.position-board.view.pan)/board.view.zoom)
			return true
	if event is InputEventMouseMotion:
		if not preview_ready: update_preview(board.exact_snap((event.position-board.view.pan)/board.view.zoom))
		return true
	return false

func choose(p: Vector2) -> void:
	var mm: Array=board.exact_snap(p)
	if preview_ready:
		preview_ready=false;picks.clear();endpoint.clear()
	if mode=="parallel" and direction==Vector2.ZERO:
		var raw: Vector2=board.canvas.mm(p);var best: float=9/(board.view.zoom*10)
		for s in board.visible_segments():
			var distance: float=raw.distance_to(Geometry2D.get_closest_point_to_segment(raw,s[0],s[1]))
			if distance<best: best=distance;direction=(s[1]-s[0]).normalized();reference_segment=s.duplicate()
		if direction!=Vector2.ZERO: hint.text="选通过点，再点击终点"
		return
	if picks.is_empty(): picks.append(mm); update_preview();return
	if mode in ["measure","ratio"]:
		if mm==picks[0]: hint.text="请选择不同的第二个位置";return
		picks.append(mm);preview_ready=true;update_preview()
	else:
		update_preview(mm)
		if not endpoint.is_empty() and endpoint!=picks[0]: preview_ready=true;hint.text="检查预览后确认"
	board.canvas.queue_redraw()

func update_preview(cursor: Array=[]) -> void:
	if picks.is_empty(): return
	var a: Vector2=vector(picks[0]);var b:=a
	if mode=="fixed" and not cursor.is_empty():
		var d := vector(cursor)-a;var angle := deg_to_rad(fields.angle[1].value)
		b=a+Vector2(cos(angle)*(-1 if d.x<0 else 1),sin(angle)*(-1 if d.y<0 else 1))*fields.length[1].value
	elif mode=="parallel" and not cursor.is_empty(): b=a+direction*(vector(cursor)-a).dot(direction)
	elif mode in ["ratio","measure"] and picks.size()==2:
		b=vector(picks[1])
		if mode=="ratio": b=a.lerp(b,fields.ratio_a[1].value/(fields.ratio_a[1].value+fields.ratio_b[1].value));preview_ready=true
		else:
			var d:=b-a;result.text="%.2f mm · 与水平轴夹角 %.2f°" % [d.length(),rad_to_deg(atan2(absf(d.y),absf(d.x)))];preview_ready=true
	else: return
	endpoint=[b.x,b.y];board.canvas.queue_redraw()

func commit() -> void:
	if not preview_ready or mode=="measure" or endpoint.is_empty(): return
	board.add_result(endpoint,[],true) if mode=="ratio" else board.add_result(picks[0],endpoint)
	cancel()

func draw_preview(canvas) -> void:
	if mode.is_empty():return
	if not reference_segment.is_empty():canvas.segment(canvas.at([reference_segment[0].x,reference_segment[0].y]),canvas.at([reference_segment[1].x,reference_segment[1].y]),Color("d06d35"),2)
	if picks.is_empty(): return
	var a: Vector2=canvas.at(picks[0]);canvas.draw_circle(a,5/canvas.scale_factor(),Color("d06d35"),false,1.5/canvas.scale_factor(),true)
	if endpoint.is_empty(): return
	var b: Vector2=canvas.at(endpoint)
	if mode=="ratio": canvas.draw_circle(b,5/canvas.scale_factor(),Color("d06d35"),true,-1,true)
	else: canvas.dashed(a,b,Color("d06d35"),1.8)
	if mode=="measure": canvas.text_at(result.text,(a+b)*.5,Color("a64e20"),Vector2(8,-12),16)
