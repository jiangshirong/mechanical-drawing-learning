extends MarginContainer
var r
var config:Dictionary
var current_task:=0
var lesson_buttons:Array[Button]=[]
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new();add_child(column)
	column.add_child(r.lesson_navigation(observe,func():r.plane_demo.enter()))
	var heading:=Label.new();heading.text="题目";heading.add_theme_font_size_override("font_size",preload("res://ui_style.gd").TITLE);column.add_child(heading)
	var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",14);column.add_child(grid)
	for i in range(config.tasks.size()):
		var button:Button=r.btn(config.tasks[i].title,start_lesson.bind(i));button.name="PlaneLesson_"+config.tasks[i].id;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size.y=70;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(button);lesson_buttons.append(button)
	hide()
func enter()->void:
	if r.presentation_active() or r.map_active or r.data.id!="plane":return
	r.hide_source();r.free_shell.hide();show();r.observer.interaction_enabled=false;r.paper.picking_enabled=false
	var saved:String=r.states.get("plane",{}).get("question_task_id",config.tasks[0].id)
	for i in range(config.tasks.size()):
		if config.tasks[i].id==saved:current_task=i
func start_lesson(i:int)->void:
	if r.presentation_active() or not visible:return
	current_task=i;r.schedule_save();r.plane_solution.enter(config.tasks[i])
func observe()->void:
	hide();r.free_shell.show();r.observer.interaction_enabled=true;r.paper.picking_enabled=true;r.observer.request_render()
