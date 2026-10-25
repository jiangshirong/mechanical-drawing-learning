extends MarginContainer
var r
var config:Dictionary
var board
var picker:OptionButton
var statement:RichTextLabel
var current_task:=0
var lesson_list:VBoxContainer
var lesson_buttons:Array[Button]=[]
var practice_content:VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new();add_child(column);practice_content=column
	var row:=HBoxContainer.new();column.add_child(row)
	row.add_child(r.btn("知识图谱",r.show_knowledge_map))
	row.add_child(r.btn("观察",observe));var working:Button=r.btn("练习",func():pass);working.toggle_mode=true;preload("res://ui_style.gd").mark_current(working);working.set_pressed_no_signal(true);working.pressed.connect(func():working.set_pressed_no_signal(true));row.add_child(working)
	row.add_child(r.btn("讲解",func():r.line_demo.enter()))
	picker=OptionButton.new();picker.custom_minimum_size.x=250;picker.focus_mode=Control.FOCUS_NONE
	for t in config.tasks:picker.add_item(t.title)
	picker.item_selected.connect(choose);row.add_child(picker)
	var gap:=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(gap)
	var original:Button=r.btn("原题",show_source);r.register_developer_button(original);row.add_child(original);row.add_child(r.btn("题目",func():r.line_solution.enter(config.tasks[current_task])))
	statement=RichTextLabel.new();statement.selection_enabled=true;statement.drag_and_drop_selection_enabled=false;statement.fit_content=true;statement.scroll_active=false
	statement.custom_minimum_size.y=56;statement.add_theme_font_size_override("normal_font_size",20);column.add_child(statement)
	board=preload("res://line_practice_board.gd").new();board.qa_save="--qa" in OS.get_cmdline_user_args();column.add_child(board)
	column.hide()
	lesson_list=VBoxContainer.new();add_child(lesson_list)
	var navigation:HBoxContainer=r.lesson_navigation(observe,func():r.line_demo.enter());lesson_list.add_child(navigation)
	var heading:=Label.new();heading.text="题目";heading.add_theme_font_size_override("font_size",preload("res://ui_style.gd").TITLE);lesson_list.add_child(heading)
	for i in range(config.tasks.size()):
		var button:Button=r.btn(config.tasks[i].title,start_lesson.bind(i))
		button.name="Lesson_"+config.tasks[i].id;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.focus_mode=Control.FOCUS_NONE
		button.custom_minimum_size.y=58;lesson_list.add_child(button);lesson_buttons.append(button)
	hide()

func enter() -> void:
	if r.presentation_active() or r.map_active or r.data.id!="line":return
	r.hide_source();r.free_shell.hide();show();r.observer.interaction_enabled=false;r.paper.picking_enabled=false
	practice_content.hide();lesson_list.show()
	var id:String=r.states.get("line",{}).get("practice_task_id",config.tasks[0].id)
	for i in range(config.tasks.size()):
		if config.tasks[i].id==id:current_task=i

func start_lesson(index:int) -> void:
	if r.presentation_active() or not is_visible_in_tree():return
	current_task=index
	if not r.states.has("line"):r.states.line={}
	r.states.line["practice_task_id"]=config.tasks[index].id;r.schedule_save()
	r.line_solution.enter(config.tasks[index])

func choose(index:int) -> void:
	r.hide_source();current_task=index;picker.select(index);board.activate(config.tasks[index])
	statement.text=config.tasks[index].statement
	if not r.states.has("line"):r.states.line={}
	r.states.line["practice_task_id"]=config.tasks[index].id;r.schedule_save()

func observe() -> void:
	board.cancel_pending();board.view.cancel_drag();board.save_draft();hide();r.free_shell.show()
	r.observer.interaction_enabled=true;r.paper.picking_enabled=true;r.observer.request_render()

func show_source() -> void:
	var t:Dictionary=config.tasks[current_task];var path:String=t.source.image
	r.remember_source_view();r.source_key=t.id+":question:"+path;r.source_mode="question"
	r.source_image.texture=load(path) if ResourceLoader.exists(path) else null
	r.source_note.text="原题 · PDF第%d页" % t.source.page;r.source_note.show();r.source_note.get_parent().show();r.source_window.popup_centered()
	if r.source_image.texture==null:r.source_note.text="图片无法打开";return
	r.source_view.reset_content(r.source_image.texture.get_size())
	if r.source_views.has(r.source_key):r.source_view.restore_view_state(r.source_views[r.source_key])
