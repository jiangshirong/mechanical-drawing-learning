extends "res://points_callout.gd"
var title: Label
var normal_style: StyleBoxFlat
var problem_style: StyleBoxFlat
var placed := -1

func _ready() -> void:
	super._ready(); normal_style=panel.get_theme_stylebox("panel").duplicate()
	problem_style=UI.card("a9bdcd","688fa8",6,1);problem_style.border_width_left=3
	problem_style.content_margin_left=14;problem_style.content_margin_right=14;problem_style.content_margin_top=10;problem_style.content_margin_bottom=10
	panel.remove_child(label);var column := VBoxContainer.new();panel.add_child(column)
	title=Label.new();title.text="问题";title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color",Color("203f54"));title.add_theme_font_size_override("font_size",UI.CAPTION);column.add_child(title);column.add_child(label);title.hide()

func set_copy(value: String) -> void:
	placed=-1;title.visible=demo.beats[demo.current_beat].callout_kind=="problem"
	panel.add_theme_stylebox_override("panel",problem_style if title.visible else normal_style)
	super.set_copy(value)

func copy_size() -> Vector2:
	var width := minf(390,maxf(240,content_rect.size.x*.32))
	var font := label.get_theme_font("normal_font")
	var measured := font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,width-28,UI.CONCLUSION)
	return Vector2(width,ceilf(measured.y)+24+(28 if title.visible else 0))

func refresh() -> void:
	if not demo or not demo.active: return
	var b: Dictionary=demo.beats[demo.current_beat]
	content_rect=Rect2(demo.sheet.view.global_position-global_position,demo.sheet.view.size)
	cue_points.clear()
	for ref in b.anchor: cue_points.append(demo.screen_anchor(ref,true)-global_position)
	protected=demo.protected_rects(true,global_position);protected_segments=demo.protected_lines(global_position)
	if b.action.type=="line": protected_segments.append([demo.screen_anchor(b.action.a,true)-global_position,demo.screen_anchor(b.action.b,true)-global_position])
	cue_kind=b.indicator;mm_label=b.value
	if placed!=demo.current_beat: place_copy();placed=demo.current_beat
	mask.position=content_rect.position;mask.size=content_rect.size
	var regions:=PackedVector4Array();var rect:=Rect2(cue_points[0],Vector2.ZERO)
	for p in cue_points: rect=rect.expand(p)
	rect=rect.grow(32)
	regions.append(Vector4(rect.position.x-content_rect.position.x,rect.position.y-content_rect.position.y,rect.size.x,rect.size.y))
	while regions.size()<16:regions.append(Vector4.ZERO)
	mask_material.set_shader_parameter("logical_size",content_rect.size)
	mask_material.set_shader_parameter("focus_count",1)
	mask_material.set_shader_parameter("focus_regions",regions)
	queue_redraw()

func _draw() -> void:
	if not demo or not demo.active or cue_points.size()<2:return
	brace_labels.clear()
	if cue_kind=="brace":brace(cue_points[0],cue_points[1],Color("d06d35"))
	elif cue_kind=="angle":
		var a:Vector2=cue_points[0];var angle:float=(cue_points[1]-a).angle()
		draw_arc(a,34,PI,angle,32,Color("d06d35"),2,true)
		draw_string(get_theme_default_font(),a+Vector2(-65,25),mm_label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a64e20"))
