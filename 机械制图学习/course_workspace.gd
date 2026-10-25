extends Control
const UI=preload("res://ui_style.gd")
var r
var registry:Dictionary={}
var chapter:Dictionary={}
var course:Dictionary={}
var scenes:Dictionary={}
var player
var space
var paper
var column:VBoxContainer
var nav:HBoxContainer
var stage:HBoxContainer
var model_column:VBoxContainer
var paper_column:VBoxContainer
var caption:PanelContainer
var copy:RichTextLabel
var problem_title:Label
var footer:HBoxContainer
var progress
var previous:Button
var next:Button
var tasks:ScrollContainer
var task_grid:GridContainer
var question
var mode:="observe"
var active:=false
var scene_id:=""
var current_task:Dictionary={}
var current_beat:Dictionary={}
var observation:Dictionary={}
var lesson_return:="observe"
var held:Dictionary={}
var window_mode:=0
var entered_from_legacy:=false
var source_overlay:PanelContainer
var source_texture:TextureRect
var source_view
var current_source:=""
var config:Dictionary={"statement":""}
var scene_tabs:HFlowContainer
var observation_id:=""
var observations:Dictionary={}

func _ready()->void:
	name="CourseWorkspace";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	registry=JSON.parse_string(FileAccess.get_file_as_string("res://模型/course_registry.json"))
	var background:=ColorRect.new();background.color=Color("101f2b");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin);column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	nav=HBoxContainer.new();column.add_child(nav)
	for item in [["知识图谱","map",leave_to_map],["观察","observe",observe],["题目","lessons",show_tasks],["讲解","concept",start_concept]]:
		var b:Button=r.btn(item[0],item[2]);b.name="CourseNav_"+item[1];b.focus_mode=Control.FOCUS_NONE;UI.navigation_icon(b,item[1]);nav.add_child(b)
	var gap:=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nav.add_child(gap)
	for item in [["原题","question"],["参考依据","answer"]]:
		var b:Button=r.btn(item[0],show_source.bind(item[1]));b.focus_mode=Control.FOCUS_NONE;r.register_developer_button(b);nav.add_child(b)
	scene_tabs=HFlowContainer.new();column.add_child(scene_tabs)
	caption=PanelContainer.new();caption.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;column.add_child(caption)
	var texts:=VBoxContainer.new();texts.add_theme_constant_override("separation",5);caption.add_child(texts)
	problem_title=Label.new();problem_title.text="问题";problem_title.add_theme_color_override("font_color",Color("203f54"));problem_title.add_theme_font_size_override("font_size",16);texts.add_child(problem_title)
	copy=RichTextLabel.new();copy.selection_enabled=true;copy.context_menu_enabled=true;copy.fit_content=true;copy.scroll_active=false;copy.focus_mode=Control.FOCUS_CLICK;copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.add_theme_color_override("default_color",Color("263747"));copy.add_theme_font_size_override("normal_font_size",20);copy.add_theme_font_size_override("bold_font_size",20);texts.add_child(copy)
	copy.drag_and_drop_selection_enabled=false;copy.mouse_default_cursor_shape=Control.CURSOR_IBEAM;copy.add_theme_color_override("selection_color",Color("779bb5"));copy.add_theme_color_override("font_selected_color",Color("102e44"))
	stage=HBoxContainer.new();stage.add_theme_constant_override("separation",14);stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stage)
	model_column=VBoxContainer.new();model_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;model_column.size_flags_stretch_ratio=.9;model_column.add_theme_constant_override("separation",10);stage.add_child(model_column)
	paper_column=VBoxContainer.new();paper_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;paper_column.size_flags_stretch_ratio=1.1;paper_column.add_theme_constant_override("separation",10);stage.add_child(paper_column)
	space=preload("res://course_space.gd").new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;space.size_flags_vertical=Control.SIZE_EXPAND_FILL;model_column.add_child(space)
	paper=preload("res://course_canvas.gd").new();paper.size_flags_horizontal=Control.SIZE_EXPAND_FILL;paper.size_flags_vertical=Control.SIZE_EXPAND_FILL;paper_column.add_child(paper)
	paper.point_selected.connect(func(point):space.set_marker(point);remember_observe())
	space.point_selected.connect(func(point):paper.marker=point;paper.queue_redraw();space.set_marker(point);remember_observe())
	caption.reparent(model_column);model_column.move_child(caption,0)
	tasks=ScrollContainer.new();tasks.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tasks)
	task_grid=GridContainer.new();task_grid.columns=2;task_grid.add_theme_constant_override("h_separation",14);task_grid.add_theme_constant_override("v_separation",12);task_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tasks.add_child(task_grid)
	footer=HBoxContainer.new();footer.add_theme_constant_override("separation",10);column.add_child(footer)
	var exit_button:Button=r.btn("退出",exit_lesson);exit_button.name="CourseExit";exit_button.focus_mode=Control.FOCUS_NONE;footer.add_child(exit_button)
	progress=preload("res://points_progress.gd").new();progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(progress);progress.chapter_chosen.connect(func(i):player.jump(i))
	previous=r.btn("上一步",func():player.retreat());previous.name="CoursePrevious";previous.focus_mode=Control.FOCUS_NONE;footer.add_child(previous)
	footer.add_child(r.label("A",16));next=r.btn("下一步",func():player.advance());next.name="CourseNext";next.focus_mode=Control.FOCUS_NONE;footer.add_child(next);footer.add_child(r.label("D",16))
	for b in [previous,next]:
		b.custom_minimum_size=Vector2(92,42)
		for key in ["normal","hover","pressed","disabled"]:
			b.add_theme_stylebox_override(key,UI.card("c5cdd0" if key=="normal" else ("dbe1e3" if key=="hover" else "aebbc2"),"82949f",5,1))
		for key in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(key,Color("34434d"))
		b.add_theme_color_override("font_disabled_color",Color("78868e"))
	player=preload("res://course_player.gd").new();add_child(player)
	player.prepared.connect(on_prepared);player.characters.connect(func(n):copy.visible_characters=n)
	player.state_changed.connect(on_state);player.phase_changed.connect(on_phase);player.navigation_requested.connect(reset_lesson_camera)
	question=preload("res://points_question.gd").new();question.demo=self;add_child(question)
	source_overlay=PanelContainer.new();source_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);source_overlay.offset_left=24;source_overlay.offset_right=-24;source_overlay.offset_top=24;source_overlay.offset_bottom=-24;add_child(source_overlay)
	var source_column:=VBoxContainer.new();source_overlay.add_child(source_column)
	var close:Button=r.btn("✕",func():source_overlay.hide());close.size_flags_horizontal=Control.SIZE_SHRINK_END;source_column.add_child(close)
	source_view=preload("res://pan_zoom.gd").new();source_view.size_flags_vertical=Control.SIZE_EXPAND_FILL;source_column.add_child(source_view)
	source_texture=TextureRect.new();source_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;source_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;source_view.attach(source_texture,Vector2(800,600),"contain");source_overlay.hide()
	resized.connect(layout_copy);hide()

func has_chapter(id:String)->bool:
	var target:String=registry.get("aliases",{}).get(id,{}).get("chapter",id)
	return registry.get("chapters",{}).has(target) and not registry.chapters[target].get("legacy",false)
func open(id:String)->void:
	var target:String=registry.get("aliases",{}).get(id,{}).get("chapter",id)
	chapter=registry.chapters[target];course=JSON.parse_string(FileAccess.get_file_as_string("res://"+chapter.course))
	for key in course.scenes:
		if not scenes.has(key):scenes[key]=JSON.parse_string(FileAccess.get_file_as_string("res://"+course.scenes[key]))
	var state:Dictionary=r.states.get("course:"+target,{})
	observations=state.get("observations",{}).duplicate(true)
	observation_id=registry.get("aliases",{}).get(id,{}).get("group",state.get("observation_id",course.observations[0].id))
	observation=observations.get(observation_id,state.get("observation",{})).duplicate(true)
	current_task={}
	for task in course.tasks:
		if task.id==state.get("question_task_id",""):current_task=task;break
	r.remember_current();r.knowledge_map.hide();r.free_shell.hide();r.practice_shell.hide();r.plane_questions.hide();r.chapter_lessons.clear();r.line_workspace.hide();r.hide_source();r.map_active=false
	r.observer.interaction_enabled=false;r.paper.picking_enabled=false
	show();mode="observe";active=false
	for child in task_grid.get_children():task_grid.remove_child(child);child.queue_free()
	for child in scene_tabs.get_children():scene_tabs.remove_child(child);child.queue_free()
	for item in course.observations:
		var b:Button=r.btn(item.title,choose_observation.bind(item.id));b.focus_mode=Control.FOCUS_NONE;b.toggle_mode=true;UI.mark_current(b);b.name="Scene_"+item.id;scene_tabs.add_child(b)
	for task in course.tasks:
		var b:Button=r.btn(task.title,start_task.bind(task.id));b.custom_minimum_size=Vector2(0,72);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.focus_mode=Control.FOCUS_NONE;b.name="CourseTask_"+task.id;task_grid.add_child(b)
	observe()
func choose_observation(id:String)->void:
	if active:return
	remember_observe();observation_id=id;observation=observations.get(id,{}).duplicate(true);observe();save_progress()
func layout_copy()->void:
	if not copy:return
	var dual:bool=model_column.visible
	var share:float=.45 if caption.get_parent()==model_column else .55
	var available:float=(size.x-58)*share-36 if dual else size.x-80
	if mode=="question" and caption.get_parent()==paper_column:available-=36
	copy.custom_minimum_size.x=minf(760,maxf(240,available))
	caption.custom_minimum_size.y=0
func save_progress()->void:
	var key:String="course:"+chapter.id
	var saved:Dictionary=r.states.get(key,{})
	if mode=="concept" and active:saved["concept_step_id"]=player.beats[player.current].id
	if not current_task.is_empty():saved["question_task_id"]=current_task.id
	saved["observation_id"]=observation_id
	saved["observation"]=observation.duplicate(true);saved["observations"]=observations.duplicate(true);r.states[key]=saved;r.schedule_save()
func remember_observe()->void:
	if mode=="observe" and visible:
		observation={"yaw":space.yaw,"pitch":space.pitch,"zoom":paper.zoom,"pan":[paper.pan.x,paper.pan.y],"marker":paper.marker.duplicate()};observations[observation_id]=observation.duplicate(true);save_progress()
func observe()->void:
	if active:return
	mode="observe";nav.show();scene_tabs.show();caption.hide();tasks.hide();stage.show();footer.hide();question.hide()
	var initial:Dictionary=course.observe
	for item in course.observations:
		if item.id==observation_id:initial=item.state;break
	for child in scene_tabs.get_children():child.set_pressed_no_signal(child.name=="Scene_"+observation_id)
	current_beat={"focus":[]};on_state(initial)
	space.yaw=observation.get("yaw",.65);space.pitch=observation.get("pitch",.42);space.update_camera()
	paper.zoom=observation.get("zoom",1);var p:Array=observation.get("pan",[0,0]);paper.pan=Vector2(p[0],p[1]);paper.exploring=true;paper.marker=observation.get("marker",[]).duplicate();space.picking_enabled=true;space.set_marker(paper.marker);paper.queue_redraw()
	mark_nav("observe")
func mark_nav(current:String)->void:
	for child in nav.get_children():
		if child is Button and child.name.begins_with("CourseNav_"):
			child.toggle_mode=true;UI.mark_current(child);child.set_pressed_no_signal(child.name=="CourseNav_"+current)
func show_tasks()->void:
	if active:return
	remember_observe();mode="lessons";nav.show();scene_tabs.hide();caption.hide();stage.hide();footer.hide();tasks.show();question.hide();mark_nav("lessons")
func start_concept()->void:
	if active:return
	remember_observe();lesson_return=mode;mode="concept";current_task={}
	var resume:String=r.states.get("course:"+chapter.id,{}).get("concept_step_id","")
	if resume.is_empty() and chapter.id=="section":resume=r.states.get("section",{}).get("guide_step_id","")
	begin(course.concept,resume)
func start_task(id:String)->void:
	if active:return
	for task in course.tasks:
		if task.id==id:
			current_task=task;lesson_return="lessons";mode="question";save_progress();begin(task.lesson);return
func begin(lesson:Dictionary,resume:="")->void:
	active=true;nav.hide();scene_tabs.hide();tasks.hide();stage.show();caption.show();footer.show();paper.exploring=false;space.picking_enabled=false;space.set_marker([])
	paper.zoom=1;paper.pan=Vector2.ZERO;space.reset_camera()
	window_mode=DisplayServer.window_get_mode()
	if not "--qa" in OS.get_cmdline_user_args():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	progress.configure(lesson.groups);player.open(lesson,resume)
	if mode=="question":question.label.text=current_task.statement;question.reset();question.show()
	else:question.hide()
func on_prepared(beat:Dictionary,_index:int)->void:
	current_beat=beat;copy.text=beat.text;copy.deselect();problem_title.visible=beat.get("kind","")=="problem"
	var style:=UI.card("a9bdcd" if problem_title.visible else "e4e8e7","688fa8" if problem_title.visible else "bcc7cc",6,1)
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10
	if problem_title.visible:style.border_width_left=4
	caption.add_theme_stylebox_override("panel",style);progress.set_current(beat.group);question.reset();on_state(player.state)
	reset_lesson_camera()
	# A sentence stays beside the panel which supplies its visual evidence.
	# Its layout is frozen for this beat; orbiting the camera cannot move the card.
	var target:VBoxContainer=paper_column
	var intended:String=beat.get("scene",scene_id)
	if beat.get("display_layout",scenes.get(intended,{}).get("layout","dual"))=="dual":
		target=model_column
		var spatial:=false
		for id in beat.get("anchor",[]):
			var e:Dictionary=scenes[intended].entities.get(id,{})
			if e.has("triangles") or e.has("model") or not e.get("world",[]).is_empty():spatial=true
		if not beat.get("anchor",[]).is_empty() and not spatial:target=paper_column
	if caption.get_parent()!=target:caption.reparent(target)
	if mode=="question" and target==paper_column:style.content_margin_right=52
	target.move_child(caption,0);model_column.visible=space.visible or target==model_column;layout_copy();save_progress()
func reset_lesson_camera()->void:
	var view:Dictionary=current_beat.get("camera",{})
	space.yaw=float(view.get("yaw",.65));space.pitch=float(view.get("pitch",.42));space.update_camera()
func on_phase(_phase:String)->void:
	if not player:return
	previous.disabled=player.current==0 and player.phase not in ["typing","playing"];next.disabled=player.phase=="complete"
func on_state(value:Dictionary)->void:
	if value.is_empty():return
	var target:String=value.scene
	if scene_id!=target:
		scene_id=target;space.configure(scenes[target]);paper.configure(scenes[target])
	var layout:String=current_beat.get("display_layout",scenes[target].get("layout","dual")) if active else scenes[target].get("layout","dual")
	space.visible=layout=="dual";model_column.visible=space.visible or (active and caption.get_parent()==model_column)
	var focus:Array=current_beat.get("focus",[])
	space.update_state(value,focus);paper.update_state(value,focus)
func handle_key(event:InputEventKey)->void:player.handle_key(event)
func exit_lesson()->void:
	if not active:return
	save_progress();player.close(false);active=false;question.reset();question.hide();source_overlay.hide();copy.deselect()
	if not "--qa" in OS.get_cmdline_user_args():DisplayServer.window_set_mode(window_mode)
	if lesson_return=="lessons":show_tasks()
	else:observe()
func leave_to_map()->void:
	if active:return
	remember_observe();hide();source_overlay.hide();r.map_active=false;r.show_knowledge_map();r.knowledge_map.mark_current(chapter.id)
func show_source(kind:String)->void:
	if not r.developer_mode:return
	var path:String=current_task.get("source_image",course.get("source_image","")) if kind=="question" else current_task.get("answer_image",course.get("answer_image",""))
	if mode=="observe" or path.is_empty():
		for item in course.observations:
			if item.id!=observation_id:continue
			var sources:Array=item.get("source_questions",[])
			if not sources.is_empty():path=course.get("sources",{}).get(sources[0],{}).get("question_image" if kind=="question" else "answer_image","")
	if path.is_empty():return
	var texture=load("res://"+path)
	if texture:
		source_texture.texture=texture;source_view.reset_content(texture.get_size(),"contain");source_overlay.show()
func _process(delta:float)->void:
	if not visible:return
	paper.pulse+=delta
	if active and not current_beat.get("focus",[]).is_empty():paper.queue_redraw()
