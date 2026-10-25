extends MarginContainer
var r
var chapter_id:=""
var returning:=false
var column:VBoxContainer
var buttons:Array[Button]=[]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,22)
	column=VBoxContainer.new();add_child(column);hide()

func enter() -> void:
	if r.presentation_active() or r.map_active:return
	if r.data.id!="points" and not r.data.has("guide"):return
	chapter_id=r.data.id;returning=false
	for child in column.get_children():column.remove_child(child);child.queue_free()
	buttons.clear()
	var row:HBoxContainer=r.lesson_navigation(observe,knowledge if chapter_id=="points" else Callable());column.add_child(row)
	var title:=Label.new();title.text="题目";title.add_theme_font_size_override("font_size",preload("res://ui_style.gd").TITLE);column.add_child(title)
	var button:Button=r.btn("作点 A、B 的三面投影" if chapter_id=="points" else "绘制双孔连接件的全剖视图",start)
	button.name="Lesson_"+chapter_id;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size.y=58
	column.add_child(button);buttons.append(button)
	resume()

func resume() -> void:
	if chapter_id!=r.data.id:return
	returning=false;r.hide_source();r.practice.cancel_pending();r.practice.view.cancel_drag();r.practice.save_draft()
	r.practice_shell.hide();r.free_shell.hide()
	r.observer.interaction_enabled=false;r.observer.picking_enabled=false;r.paper.picking_enabled=false
	show()

func start() -> void:
	if r.presentation_active() or not is_visible_in_tree():return
	returning=true;hide()
	if chapter_id=="points":r.points_demo.enter("solution")
	else:r.guide_step_id="";r.guide.enter()

func knowledge() -> void:
	returning=true;hide();r.points_demo.enter("concept")

func observe() -> void:
	clear();r.points_mode="observe";r.apply_points_mode();r.observer.request_render()

func clear() -> void:
	returning=false;hide()
