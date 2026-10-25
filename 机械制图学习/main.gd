extends Control
const Observer = preload("res://observer.gd")
const Paper = preload("res://paper.gd")
const Guide = preload("res://section_guide.gd")
const KnowledgeMap = preload("res://knowledge_map.gd")
const PanZoom = preload("res://pan_zoom.gd")
const UI = preload("res://ui_style.gd")
const Practice = preload("res://practice_board.gd")
const PointsPresentation = preload("res://points_presentation.gd")
const LinePresentation = preload("res://line_presentation.gd")

var catalog: Array = []
var data: Dictionary = {}
var index := 0
var step := 0
var selected := ""
var states: Dictionary = {}
var colors := true
var projections := true
var save_path := "user://observation-v1.json"
var observer
var paper
var feature_text: Label
var section_toggle: CheckBox
var section_enabled := true
var source_window: Window
var source_image: TextureRect
var source_view
var source_note: Label
var save_timer: Timer
var source_mode := "question"
var source_key := ""
var source_views: Dictionary = {}
var persistence_error := ""
var guide
var guide_step_id := ""
var guide_button: Button
var guide_panel: VBoxContainer
var guide_heading: Label
var guide_copy: RichTextLabel
var guide_reason: RichTextLabel
var guide_detail: RichTextLabel
var guide_prev: Button
var guide_next: Button
var free_shell: MarginContainer
var guide_shell: MarginContainer
var guide_stage: HBoxContainer
var guide_space: VBoxContainer
var guide_paper: VBoxContainer
var knowledge_map
var map_active := false
var map_locked_controls: Array = []
var points_config: Dictionary = {}
var points_mode := "observe"
var points_step_id := ""
var points_tabs: HBoxContainer
var practice_shell: MarginContainer
var practice
var points_demo
var line_demo
var line_config: Dictionary = {}
var line_step_id := ""
var line_tabs: HBoxContainer
var line_qa
var line_workspace
var chapter_lessons
var line_solution
var plane_tabs:HBoxContainer
var plane_demo
var plane_solution
var plane_questions
var plane_config:Dictionary={}
var plane_step_id:=""
var developer_mode:=false
var developer_sequence:=""
var developer_buttons:Array[Button]=[]
var course_workspace
var course_host
var save_blocked:=false

func _ready() -> void:
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 8000
	if "--qa" in OS.get_cmdline_user_args():
		save_path = "user://qa-observation-v1.json"
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_position(Vector2i(-6000,-6000))
	if "--qa-map-check" in OS.get_cmdline_user_args() or "--qa-map-reopen" in OS.get_cmdline_user_args():
		save_path = "user://qa-knowledge-map.json"
	if "--qa-canvas-check" in OS.get_cmdline_user_args(): save_path = "user://qa-canvas-interaction.json"
	if "--qa-point-quality-check" in OS.get_cmdline_user_args(): save_path = "user://qa-point-quality.json"
	if "--qa-ui-refine-check" in OS.get_cmdline_user_args(): save_path = "user://qa-ui-refine.json"
	DisplayServer.window_set_title("机械制图学习 · 投影与补视图")
	get_viewport().gui_embed_subwindows = true
	theme = UI.make_theme()
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
	points_config = JSON.parse_string(FileAccess.get_file_as_string("res://模型/points_learning.json"))
	if "--qa-chapter-lessons" in OS.get_cmdline_user_args():save_path="user://qa-chapter-lessons-observation.json"
	line_config = JSON.parse_string(FileAccess.get_file_as_string("res://模型/line_learning.json"))
	if "--qa-line-practice" in OS.get_cmdline_user_args() or "--qa-line-practice-reopen" in OS.get_cmdline_user_args():save_path="user://qa-line-practice-observation.json"
	if "--qa-line-learning" in OS.get_cmdline_user_args() or "--qa-line-reopen" in OS.get_cmdline_user_args(): save_path="user://qa-line-observation.json"
	if "--qa-points-beats" in OS.get_cmdline_user_args() or "--qa-points-beats-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-points-beats-observation.json"
	if "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-point-naming-observation.json"
	if "--qa-points-check" in OS.get_cmdline_user_args() or "--qa-points-reopen" in OS.get_cmdline_user_args() or "--qa-points-corrupt" in OS.get_cmdline_user_args(): save_path = "user://qa-points-observation.json"
	if "--qa-points-fresh-guide" in OS.get_cmdline_user_args(): save_path = "user://qa-points-fresh-guide.json"
	if "--qa-practice-tools" in OS.get_cmdline_user_args() or "--qa-practice-tools-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-practice-tools-observation.json"
	if "--qa-plane-lessons" in OS.get_cmdline_user_args() or "--qa-plane-reopen" in OS.get_cmdline_user_args():save_path="user://qa-plane-observation.json"
	if "--qa-course" in OS.get_cmdline_user_args():save_path="user://qa-course-observation.json"
	if "--qa-extra" in OS.get_cmdline_user_args():save_path="user://qa-course-visual.json"
	if "--qa-beginner" in OS.get_cmdline_user_args():save_path="user://qa-course-beginner.json"
	if "--qa-surface-lighting" in OS.get_cmdline_user_args():save_path="user://qa-surface-lighting.json"
	load_states()
	build_ui()
	guide = Guide.new(self)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.3
	save_timer.timeout.connect(save_states)
	add_child(save_timer)
	index = clampi(index, 0, catalog.size()-1)
	load_example(index, false)
	show_knowledge_map()
	# Existing QA scenarios explicitly enter their observation scene. Normal startup
	# and map acceptance checks follow the new knowledge-map entry path.
	var starts_at_map := ["--qa-map-check","--qa-map-reopen","--qa-canvas-check","--qa-points-check","--qa-points-reopen","--qa-points-corrupt","--qa-points-fresh-guide","--qa-practice-tools","--qa-practice-tools-reopen","--qa-point-naming","--qa-point-naming-reopen"]
	if "--qa" in OS.get_cmdline_user_args() and not starts_at_map.any(func(flag): return flag in OS.get_cmdline_user_args()) and not "--qa-points-beats" in OS.get_cmdline_user_args() and not "--qa-points-beats-reopen" in OS.get_cmdline_user_args() and not "--qa-line-learning" in OS.get_cmdline_user_args() and not "--qa-line-reopen" in OS.get_cmdline_user_args():
		open_map_example(str(data.id))
	print("LEARNING_READY examples=", catalog.size(), " state=", save_path)
	if "--qa-surface-lighting" in OS.get_cmdline_user_args():
		await load("res://qa/surface_lighting_check.gd").new().run(self)
		get_tree().quit();return
	if "--qa-beginner" in OS.get_cmdline_user_args():
		await load("res://qa/course_beginner_runner.gd").new().run(self)
		get_tree().quit();return
	if "--qa-extra" in OS.get_cmdline_user_args():
		await load("res://qa/course_visual_runner.gd").new().run(self)
		get_tree().quit();return
	if "--qa-course" in OS.get_cmdline_user_args():
		if "--state-write" in OS.get_cmdline_user_args() or "--state-reopen" in OS.get_cmdline_user_args():await load("res://course_state_check.gd").new().run(self)
		else:await load("res://course_check.gd").new().run(self)
		get_tree().quit();return
	for flag in ["--qa-plane-lessons","--qa-plane-reopen"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://plane_lessons_check.gd").new().run(self,flag)
			get_tree().quit();return
	if "--qa-chapter-lessons" in OS.get_cmdline_user_args():
		await load("res://chapter_lessons_check.gd").new().run(self)
		get_tree().quit();return
	for flag in ["--qa-line-practice","--qa-line-practice-reopen"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://line_practice_check.gd").new().run(self,flag)
			get_tree().quit();return
	for flag in ["--qa-line-learning","--qa-line-reopen"]:
		if flag in OS.get_cmdline_user_args():
			line_qa=load("res://line_learning_check.gd").new()
			await line_qa.run(self,flag)
			get_tree().quit()
			return
	if "--qa-observation-point-drag" in OS.get_cmdline_user_args():
		await load("res://observation_point_drag_check.gd").new().run(self)
		get_tree().quit()
		return
	for flag in ["--qa-points-beats","--qa-points-beats-reopen"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://points_beats_check.gd").new().run(self,flag)
			get_tree().quit()
			return
	for flag in ["--qa-point-naming","--qa-point-naming-reopen"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://point_naming_check.gd").new().run(self,flag)
			practice.save_draft()
			save_states()
			get_tree().quit()
			return
	for flag in ["--qa-practice-tools","--qa-practice-tools-reopen"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://practice_tools_check.gd").new().run(self,flag)
			practice.save_draft()
			save_states()
			get_tree().quit()
			return
	for flag in ["--qa-points-check","--qa-points-reopen","--qa-points-corrupt","--qa-points-fresh-guide"]:
		if flag in OS.get_cmdline_user_args():
			await load("res://points_learning_check.gd").new().run(self,flag)
			practice.save_draft()
			save_states()
			get_tree().quit()
			return
	if "--qa-ui-refine-check" in OS.get_cmdline_user_args():
		await load("res://ui_refine_check.gd").new().run(self)
		get_tree().quit()
		return
	if "--qa-point-quality-check" in OS.get_cmdline_user_args():
		var stage := "before" if "--before" in OS.get_cmdline_user_args() else "after"
		await load("res://point_quality_check.gd").new().run(self, stage)
		get_tree().quit()
		return
	if "--qa-canvas-check" in OS.get_cmdline_user_args():
		await load("res://canvas_check.gd").new().run(self)
		get_tree().quit()
		return
	if "--qa-map-check" in OS.get_cmdline_user_args():
		await load("res://knowledge_map_check.gd").new().run(self)
		get_tree().quit()
		return
	if "--qa-map-reopen" in OS.get_cmdline_user_args():
		await load("res://knowledge_map_check.gd").new().reopen(self)
		get_tree().quit()
		return
	if "--qa-render-bench" in OS.get_cmdline_user_args():
		var stage := "after" if "--after" in OS.get_cmdline_user_args() else "before"
		await load("res://render_bench.gd").new().run(self,stage)
		get_tree().quit()
		return
	if "--qa-guide-check" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		var tester = load("res://guide_check.gd").new()
		await tester.run(self)
		get_tree().quit()
	elif "--qa-guide-reopen" in OS.get_cmdline_user_args():
		for frame in range(40): await get_tree().process_frame
		var report := {"free_mode":not guide.active,"guide_hidden":not guide_panel.visible,"id":data.id,"guide_step":guide_step_id,"camera":observer.get_state(),"section":section_enabled,"qa_window_offscreen":DisplayServer.window_get_position().x<0,"qa_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)}
		FileAccess.open("res://qa/guide-reopen.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		get_tree().quit()
	if "--qa-reopen-check" in OS.get_cmdline_user_args():
		for frame in range(60): await get_tree().process_frame
		var report := {"examples":catalog.size(),"id":data.id,"step":step,"camera":observer.get_state(),"colors":colors,"projections":projections,"section":section_enabled,"save_path":save_path,"source_size":load("res://"+data.source.image).get_size()}
		FileAccess.open("res://qa/reopen-check.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		observer.request_render()
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://qa/launcher-reopen.png")
		get_tree().quit()

func label(text: String, fs := UI.BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	return l

func selectable_copy(value: String, fs: int) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.text = value
	node.selection_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.context_menu_enabled = true
	node.add_theme_font_size_override("normal_font_size",fs)
	return node

func _process(_delta: float) -> void:
	if guide and guide.active: guide.sync_label_size()
	if observer:
		var idle: bool = Time.get_ticks_msec() >= observer.active_until_msec
		if OS.low_processor_usage_mode != idle: OS.low_processor_usage_mode = idle

func btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b

func build_ui() -> void:
	var margin := MarginContainer.new()
	free_shell = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 22)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var map_button := btn("知识图谱", show_knowledge_map)
	map_button.name = "MapEntry"
	UI.navigation_icon(map_button,"map")
	header.add_child(map_button)
	points_tabs = make_points_tabs("observe")
	header.add_child(points_tabs)
	line_tabs = HBoxContainer.new()
	header.add_child(line_tabs)
	var line_observe := btn("观察",func(): line_tabs.get_child(0).set_pressed_no_signal(true))
	line_observe.name="LineMode_observe"
	UI.navigation_icon(line_observe,"observe")
	line_observe.toggle_mode=true
	line_observe.focus_mode=Control.FOCUS_NONE
	line_observe.set_pressed_no_signal(true)
	UI.mark_current(line_observe)
	line_tabs.add_child(line_observe)
	var line_knowledge := btn("讲解",func(): course_host.enter("line"))
	UI.navigation_icon(line_knowledge,"concept")
	line_knowledge.name="LineMode_concept"
	line_knowledge.focus_mode=Control.FOCUS_NONE
	line_tabs.add_child(line_knowledge)
	var line_practice := btn("题目",func():line_workspace.enter())
	UI.navigation_icon(line_practice,"lessons")
	line_practice.name="LineMode_lessons";line_practice.focus_mode=Control.FOCUS_NONE
	line_tabs.add_child(line_practice)
	line_tabs.move_child(line_practice,1)
	plane_tabs=HBoxContainer.new();header.add_child(plane_tabs)
	for pair in [["观察","observe",func():plane_tabs.get_child(0).set_pressed_no_signal(true)],["题目","lessons",func():plane_questions.enter()],["讲解","concept",func():course_host.enter("plane")]]:
		var button:Button=btn(pair[0],pair[2]);button.name="PlaneMode_"+pair[1];button.focus_mode=Control.FOCUS_NONE;UI.navigation_icon(button,pair[1]);plane_tabs.add_child(button)
		if pair[1]=="observe":button.toggle_mode=true;UI.mark_current(button);button.set_pressed_no_signal(true)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	guide_button = btn("题目", func(): chapter_lessons.enter())
	UI.navigation_icon(guide_button,"lessons")
	guide_button.name = "GuideEntry"
	header.add_child(guide_button)
	var source_button := btn("原题", func(): show_source("question"))
	source_button.name = "SourceButton"
	register_developer_button(source_button)
	header.add_child(source_button)
	var answer_button := btn("参考依据", func(): show_source("answer"))
	answer_button.name = "AnswerButton"
	register_developer_button(answer_button)
	header.add_child(answer_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.95
	body.add_child(left)
	observer = Observer.new()
	observer.name = "Observer"
	observer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	observer.custom_minimum_size = Vector2(370, 240)
	left.add_child(observer)
	observer.feature_selected.connect(select_feature)
	observer.observation_changed.connect(schedule_save)
	var cameras := HBoxContainer.new()
	left.add_child(cameras)
	for pair in [["主视", "front"], ["俯视", "top"], ["左视", "left"], ["复位", "reset"]]:
		var key: String = pair[1]
		var b := btn(pair[0], func(): if not guide or not guide.active: observer.standard_view(key))
		b.name = "Camera_"+key
		cameras.add_child(b)
	section_toggle = CheckBox.new()
	section_toggle.name = "SectionToggle"
	section_toggle.text = "全剖"
	section_toggle.toggled.connect(set_section)
	left.add_child(section_toggle)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.05
	body.add_child(right)
	paper = Paper.new()
	paper.name = "Paper"
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.custom_minimum_size = Vector2(400, 260)
	right.add_child(paper)
	paper.feature_selected.connect(select_feature)
	paper.observation_point_moved.connect(move_observation_point)
	feature_text = label("", 16)
	feature_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(feature_text)
	guide_shell = MarginContainer.new()
	guide_shell.name = "GuideShell"
	guide_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: guide_shell.add_theme_constant_override("margin_"+side,22)
	add_child(guide_shell)
	guide_shell.hide()
	var lesson := VBoxContainer.new()
	guide_shell.add_child(lesson)
	guide_stage = HBoxContainer.new()
	guide_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lesson.add_child(guide_stage)
	guide_space = VBoxContainer.new()
	guide_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_space.size_flags_stretch_ratio = 1.0
	guide_stage.add_child(guide_space)
	guide_paper = VBoxContainer.new()
	guide_paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_paper.size_flags_stretch_ratio = 1.0
	guide_stage.add_child(guide_paper)
	guide_panel = VBoxContainer.new()
	guide_panel.name = "GuidePanel"
	guide_panel.visible = false
	lesson.add_child(guide_panel)
	guide_panel.add_theme_constant_override("separation", 7)
	guide_heading = label("", UI.CAPTION)
	guide_heading.add_theme_color_override("font_color", UI.MUTED)
	guide_panel.add_child(guide_heading)
	guide_copy = selectable_copy("", UI.CONCLUSION)
	guide_reason = selectable_copy("", UI.BODY)
	guide_reason.add_theme_color_override("default_color", UI.EMPHASIS)
	guide_detail = selectable_copy("", UI.CAPTION)
	guide_detail.add_theme_color_override("default_color", UI.MUTED)
	for line in [guide_copy, guide_reason, guide_detail]:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide_panel.add_child(line)
	var navigation := HBoxContainer.new()
	guide_panel.add_child(navigation)
	var leave := btn("退出",func(): guide.exit())
	leave.name = "GuideExit"
	navigation.add_child(leave)
	var navigation_space := Control.new()
	navigation_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(navigation_space)
	guide_prev = btn("上一步",func(): guide.go_to(guide.current_step-1))
	guide_prev.name = "GuidePrevious"
	navigation.add_child(guide_prev)
	guide_next = btn("下一步",func(): guide.go_to(guide.current_step+1))
	guide_next.name = "GuideNext"
	navigation.add_child(guide_next)
	for control in [leave,guide_prev,guide_next]: control.focus_mode = Control.FOCUS_NONE
	build_source_window()
	knowledge_map = KnowledgeMap.new()
	add_child(knowledge_map)
	knowledge_map.example_requested.connect(open_map_example)
	knowledge_map.hide()
	build_points_workspace()

func make_points_tabs(current: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	for pair in [["观察","observe"],["题目","lessons"],["讲解","concept"]]:
		var key: String = pair[1]
		var b := btn(pair[0],func(): change_points_mode(key))
		b.name = "Mode_"+key
		UI.navigation_icon(b,key)
		b.toggle_mode = true
		UI.mark_current(b)
		b.set_pressed_no_signal(current == key)
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
	return row

func lesson_navigation(observe_action:Callable,concept_action:Callable=Callable()) -> HBoxContainer:
	var row:=HBoxContainer.new()
	for pair in [["知识图谱","map",show_knowledge_map],["观察","observe",observe_action],["题目","lessons",func():pass]]:
		var button:Button=btn(pair[0],pair[2]);button.name="Nav_"+pair[1];button.focus_mode=Control.FOCUS_NONE
		UI.navigation_icon(button,pair[1]);row.add_child(button)
		if pair[1]=="lessons":
			button.toggle_mode=true;UI.mark_current(button);button.set_pressed_no_signal(true)
			button.pressed.connect(func():button.set_pressed_no_signal(true))
	if concept_action.is_valid():
		var button:Button=btn("讲解",concept_action);button.name="Nav_concept";button.focus_mode=Control.FOCUS_NONE;UI.navigation_icon(button,"concept");row.add_child(button)
	return row

func register_developer_button(button:Button) -> void:
	developer_buttons.append(button);button.visible=developer_mode

func build_points_workspace() -> void:
	practice_shell = MarginContainer.new()
	practice_shell.name = "PracticeShell"
	practice_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: practice_shell.add_theme_constant_override("margin_"+side,22)
	add_child(practice_shell)
	var column := VBoxContainer.new()
	practice_shell.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_child(btn("知识图谱",show_knowledge_map))
	row.add_child(make_points_tabs("practice"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var teaching := btn("题目",func(): points_demo.enter("solution"))
	teaching.name = "Teaching"
	row.add_child(teaching)
	var statement := label(points_config.statement)
	statement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(statement)
	practice = Practice.new()
	if "--qa" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-practice-v1.json"
	if "--qa-plane-lessons" in OS.get_cmdline_user_args() or "--qa-plane-reopen" in OS.get_cmdline_user_args():practice.save_path="user://qa-plane-practice.json"
	if "--qa-chapter-lessons" in OS.get_cmdline_user_args():practice.save_path="user://qa-chapter-lessons-practice.json"
	if "--qa-points-beats" in OS.get_cmdline_user_args() or "--qa-points-beats-reopen" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-points-beats-practice.json"
	if "--qa-line-learning" in OS.get_cmdline_user_args() or "--qa-line-reopen" in OS.get_cmdline_user_args(): practice.save_path="user://qa-line-practice.json"
	if "--qa-points-corrupt" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-practice-corrupt.json"
	if "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-point-naming.json"
	if "--qa-practice-tools" in OS.get_cmdline_user_args() or "--qa-practice-tools-reopen" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-practice-tools.json"
	column.add_child(practice)
	practice_shell.hide()
	points_demo = PointsPresentation.new()
	points_demo.r = self
	points_demo.config = points_config
	add_child(points_demo)
	line_demo=LinePresentation.new()
	line_demo.r=self
	line_demo.config=line_config
	add_child(line_demo)
	line_workspace=preload("res://line_workspace.gd").new();line_workspace.r=self
	line_workspace.config=JSON.parse_string(FileAccess.get_file_as_string("res://模型/line_practice.json"));add_child(line_workspace)
	line_solution=preload("res://line_solution.gd").new();line_solution.r=self;add_child(line_solution)
	chapter_lessons=preload("res://chapter_lessons.gd").new();chapter_lessons.r=self;add_child(chapter_lessons)
	plane_config=JSON.parse_string(FileAccess.get_file_as_string("res://模型/plane_learning.json"))
	plane_questions=preload("res://plane_questions.gd").new();plane_questions.r=self;plane_questions.config=JSON.parse_string(FileAccess.get_file_as_string("res://模型/plane_questions.json"));add_child(plane_questions)
	plane_demo=preload("res://plane_presentation.gd").new();plane_demo.r=self;plane_demo.kind="concept";add_child(plane_demo)
	plane_solution=preload("res://plane_presentation.gd").new();plane_solution.r=self;add_child(plane_solution)
	course_workspace=preload("res://course_workspace.gd").new();course_workspace.r=self;add_child(course_workspace)
	course_host=preload("res://course_host.gd").new(self)

func presentation_active() -> bool:
	return (course_workspace!=null and course_workspace.active) or (guide != null and guide.active) or (points_demo != null and points_demo.active) or (line_demo != null and line_demo.active) or (line_solution!=null and line_solution.active) or (plane_demo!=null and plane_demo.active) or (plane_solution!=null and plane_solution.active)

func change_points_mode(mode: String) -> void:
	if presentation_active() or map_active or data.get("id","") != points_config.chapter_id: return
	if mode=="lessons":chapter_lessons.enter();return
	practice.cancel_pending()
	practice.view.cancel_drag()
	practice.save_draft()
	if mode == "concept":
		course_host.enter("points")
		return
	points_mode = mode
	apply_points_mode()
	if mode == "practice" and practice.initial_fit_pending:
		practice.view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		await get_tree().process_frame
		await get_tree().process_frame
		if points_mode == "practice" and not presentation_active():
			practice.view.fit_content()
			practice.initial_fit_pending = false
			practice.autosave()
		practice.view.mouse_filter = Control.MOUSE_FILTER_STOP

func apply_points_mode() -> void:
	for shell in [free_shell,practice_shell]:
		for control in shell.find_children("Mode_*","Button",true,false):
			control.set_pressed_no_signal(control.name == "Mode_"+points_mode)
	var working: bool = data.get("id","") == points_config.chapter_id and points_mode == "practice" and not map_active
	free_shell.visible = not working and not map_active
	practice_shell.visible = working
	observer.interaction_enabled = not working and not map_active
	observer.picking_enabled = not working and not map_active
	paper.picking_enabled = not working and not map_active

func lock_map_controls(node: Node) -> void:
	if node is BaseButton:
		map_locked_controls.append([node, node.disabled])
		node.disabled = true
	for child in node.get_children(): lock_map_controls(child)

func show_knowledge_map() -> void:
	if map_active or presentation_active(): return
	if course_workspace and course_workspace.visible:
		course_workspace.remember_observe();course_workspace.hide()
	if chapter_lessons:chapter_lessons.clear()
	if plane_questions:plane_questions.hide()
	if line_workspace:
		line_workspace.board.cancel_pending();line_workspace.board.save_draft();line_workspace.hide()
	practice.cancel_pending()
	practice.view.cancel_drag()
	practice.save_draft()
	practice_shell.hide()
	map_active = true
	remember_current()
	if not data.is_empty(): knowledge_map.mark_current(str(data.id))
	hide_source()
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	map_locked_controls.clear()
	lock_map_controls(free_shell)
	observer.dragging = false
	observer.interaction_enabled = false
	observer.picking_enabled = false
	paper.dragging_point = false
	paper.picking_enabled = false
	free_shell.hide()
	knowledge_map.show()
	schedule_save()

func open_map_example(example_id: String) -> void:
	if presentation_active(): return
	developer_sequence=""
	if course_workspace and course_workspace.has_chapter(example_id):
		for entry in map_locked_controls:entry[0].disabled=entry[1]
		map_locked_controls.clear();course_workspace.open(example_id);return
	if course_workspace and course_workspace.visible:
		course_workspace.remember_observe();course_workspace.hide()
	var target := -1
	for i in range(catalog.size()):
		if catalog[i].id == example_id: target = i
	if target < 0: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	knowledge_map.hide()
	for entry in map_locked_controls: entry[0].disabled = entry[1]
	map_locked_controls.clear()
	map_active = false
	points_mode = "observe"
	practice_shell.hide()
	free_shell.show()
	observer.interaction_enabled = true
	observer.picking_enabled = true
	paper.picking_enabled = true
	if data.get("id", "") != example_id: load_example(target)
	apply_points_mode()
	observer.request_render()

func build_source_window() -> void:
	source_window = Window.new()
	source_window.name = "SourceWindow"
	source_window.title = "原题与参考依据"
	source_window.size = Vector2i(1000, 740)
	source_window.min_size = Vector2i(640, 480)
	source_window.close_requested.connect(hide_source)
	add_child(source_window)
	source_window.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 18)
	source_window.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	source_note = label("", 16)
	source_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(source_note)
	source_view = PanZoom.new()
	source_view.name = "SourceView"
	source_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(source_view)
	source_image = TextureRect.new()
	source_image.name = "SourceImage"
	source_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	source_image.stretch_mode = TextureRect.STRETCH_SCALE
	source_view.attach(source_image, Vector2.ONE)

func show_source(mode: String) -> void:
	if presentation_active(): return
	source_mode = mode
	var path: String = "res://"+data.source.image
	if mode == "answer":
		if data.has("answer_image"): path = "res://"+str(data.answer_image)
		elif data.id == "points": path = "res://assets/source/answer1-07.png"
		elif data.id in ["line", "plane"]: path = "res://assets/source/answer2-06.png"
		elif data.id in ["slope", "base"]: path = "res://assets/source/answer2-07.png"
		elif data.id == "bracket" and ResourceLoader.exists("res://assets/source/answer7.png"): path = "res://assets/source/answer7.png"
		source_note.text = ""
	else: source_note.text = "第%d套 · PDF第%d页" % [int(data.source.paper), int(data.source.pdf_page)]
	source_note.visible = not source_note.text.is_empty()
	source_note.get_parent().visible = source_note.visible
	remember_source_view()
	source_key = str(data.id) + ":" + mode + ":" + path
	source_image.texture = load(path) if ResourceLoader.exists(path) else null
	source_window.popup_centered()
	if source_image.texture == null:
		source_note.text = "图片无法打开"
		source_note.show()
		source_note.get_parent().show()
		source_view.cancel_drag()
		return
	source_view.reset_content(source_image.texture.get_size())
	if source_views.has(source_key): source_view.restore_view_state(source_views[source_key])

func remember_source_view() -> void:
	if not source_key.is_empty() and source_image.texture != null and not source_view.needs_fit:
		source_views[source_key] = source_view.get_view_state()

func hide_source() -> void:
	remember_source_view()
	source_window.hide()

func load_example(i: int, store := true) -> void:
	if presentation_active(): return
	if chapter_lessons:chapter_lessons.clear()
	if plane_questions:plane_questions.hide()
	if line_workspace:
		line_workspace.board.cancel_pending();line_workspace.board.save_draft();line_workspace.hide()
	if store and not data.is_empty(): remember_current()
	index = i
	data = JSON.parse_string(FileAccess.get_file_as_string("res://"+catalog[i].data))
	var saved: Dictionary = states.get(data.id, {})
	guide_step_id = str(saved.get("guide_step_id",""))
	points_step_id = str(saved.get("concept_step_id","")) if data.id == "points" else ""
	line_step_id = str(saved.get("concept_step_id","")) if data.id == "line" else ""
	points_tabs.visible = data.id == points_config.chapter_id
	line_tabs.visible = data.id=="line"
	plane_tabs.visible=data.id=="plane"
	plane_step_id=str(saved.get("concept_step_id","")) if data.id=="plane" else ""
	if data.id=="plane":
		plane_questions.current_task=0
		for task_index in range(plane_questions.config.tasks.size()):
			if plane_questions.config.tasks[task_index].id==saved.get("question_task_id",""):plane_questions.current_task=task_index
	points_mode = "observe"
	practice.cancel_pending()
	practice_shell.hide()
	step = 0
	selected = str(saved.get("selected", ""))
	colors = true
	projections = true
	section_enabled = bool(saved.get("section", true))
	observer.install(display_data(), model_path())
	observer.restore_state(saved.get("camera", {}))
	observer.unfold = 0
	paper.setup(display_data())
	section_toggle.visible = data.has("section")
	section_toggle.set_pressed_no_signal(section_enabled)
	guide_button.visible = data.has("guide")
	refresh()
	if store: schedule_save()

func display_data() -> Dictionary:
	var shown := data.duplicate(data.id == "points")
	shown["section_active"] = data.has("section") and section_enabled
	if shown.section_active:
		shown.views = data.section.views
		shown.curves = data.section.curves
	return shown

func model_path() -> String:
	return "res://"+str(data.section.model if data.has("section") and section_enabled else catalog[index].model)

func set_section(enabled: bool) -> void:
	if guide and guide.active: return
	if not data.has("section"): return
	var camera_state: Dictionary = observer.get_state()
	section_enabled = enabled
	section_toggle.set_pressed_no_signal(enabled)
	selected = ""
	observer.install(display_data(), model_path())
	observer.restore_state(camera_state)
	paper.setup(display_data())
	refresh()
	schedule_save()

func select_feature(id: String, world_point: Array = []) -> void:
	if presentation_active(): return
	selected = id
	observer.picked_world = world_point
	paper.picked_world = world_point
	refresh()
	schedule_save()

func move_observation_point(id: String, world_point: Array) -> void:
	if presentation_active() or points_mode != "observe" or data.id != "points": return
	for shown in [paper.data, observer.data]:
		for feature in shown.features:
			if feature.id == id: feature.points[0] = world_point.duplicate()
		for key in ["front", "top", "left"]:
			for point in shown.views[key].points:
				if point.feature != id: continue
				point.world = world_point.duplicate()
				var projected: Vector2 = paper.uv(world_point, key)
				point.uv = [projected.x, projected.y]
	var sphere := observer.model.find_child(id, true, false) as Node3D
	if is_instance_valid(sphere): sphere.position = observer.g(world_point)
	observer.helper_key.clear()
	select_feature(id, world_point)

func refresh() -> void:
	feature_text.text = persistence_error
	feature_text.visible = not feature_text.text.is_empty()
	if guide and guide.active:
		paper.queue_redraw()
		return
	observer.selected = selected
	observer.auxiliary = colors
	observer.projections = projections
	observer.unfold_target = 0
	observer.refresh_helpers()
	paper.selected = selected
	paper.auxiliary = colors
	paper.projection = projections
	paper.step = step
	paper.queue_redraw()

func remember_current() -> void:
	if data.is_empty(): return
	if guide and guide.active:
		states[data.id] = guide.free_snapshot.duplicate(true)
		states[data.id]["guide_step_id"] = guide_step_id
		return
	states[data.id] = {"step": step, "selected": selected, "camera": observer.get_state(), "colors": colors, "projections": projections}
	if data.has("section"): states[data.id]["section"] = section_enabled
	if data.has("guide"): states[data.id]["guide_step_id"] = guide_step_id
	if data.id == "points": states[data.id]["concept_step_id"] = points_step_id
	if data.id == "line": states[data.id]["concept_step_id"] = line_step_id
	if data.id=="plane":
		states[data.id]["concept_step_id"]=plane_step_id
		if plane_questions:states[data.id]["question_task_id"]=plane_questions.config.tasks[plane_questions.current_task].id
	if data.id=="line" and line_workspace:states[data.id]["practice_task_id"]=line_workspace.config.tasks[line_workspace.current_task].id

func schedule_save() -> void:
	if is_instance_valid(save_timer): save_timer.start()

func save_states() -> void:
	if save_blocked:return
	if "--qa-line-learning" in OS.get_cmdline_user_args() or "--qa-line-reopen" in OS.get_cmdline_user_args():
		if save_path!="user://qa-line-observation.json":
			push_error("直线专项禁止写入非独立观察存档"); return
	if "--qa-points-beats" in OS.get_cmdline_user_args() or "--qa-points-beats-reopen" in OS.get_cmdline_user_args():
		if save_path != "user://qa-points-beats-observation.json":
			push_error("点章节专项禁止写入非独立观察存档")
			return
	remember_current()
	var temp := save_path+".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		persistence_error = "观察状态保存失败，请检查本机存储。"
		refresh()
		return
	file.store_string(JSON.stringify({"schema_version": 1, "last_example": data.id, "states": states}))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(save_path))
	if error != OK:
		persistence_error = "观察状态保存失败，临时存档已保留。"
		refresh()

func load_states() -> void:
	if not FileAccess.file_exists(save_path): return
	var parser:=JSON.new()
	var parsed:bool=parser.parse(FileAccess.get_file_as_string(save_path))==OK
	var saved = parser.data if parsed else null
	if not valid_observation_save(saved):
		save_blocked=true
		persistence_error = "原观察存档无法读取；已保留原文件。"
		if not FileAccess.file_exists(save_path+".damaged"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path+".damaged"))
		return
	states = saved.get("states", {})
	for i in range(catalog.size()):
		if catalog[i].id == saved.get("last_example", ""): index = i

func valid_save_number(value)->bool:
	return (value is int or value is float) and is_finite(float(value))
func valid_save_vector(value,count:int,allow_empty:=false)->bool:
	if not value is Array:return false
	if allow_empty and value.is_empty():return true
	return value.size()==count and value.all(valid_save_number)
func valid_saved_view(value)->bool:
	if not value is Dictionary:return false
	for key in ["yaw","pitch","zoom"]:
		if value.has(key) and not valid_save_number(value[key]):return false
	if value.has("zoom") and value.zoom<=0:return false
	for key in ["pan","target","marker"]:
		if value.has(key) and not valid_save_vector(value[key],2 if key=="pan" else 3,key=="marker"):return false
	return true
func valid_observation_save(value)->bool:
	if not value is Dictionary or value.get("schema_version",0)!=1 or not value.get("states",{}) is Dictionary:return false
	for state in value.get("states",{}).values():
		if not state is Dictionary:return false
		for key in ["concept_step_id","guide_step_id","question_task_id","practice_task_id","observation_id","selected"]:
			if state.has(key) and not state[key] is String:return false
		for key in ["camera","observation"]:
			if state.has(key) and not valid_saved_view(state[key]):return false
		if state.has("observations"):
			if not state.observations is Dictionary:return false
			for view in state.observations.values():
				if not valid_saved_view(view):return false
	return true

func _input(event: InputEvent) -> void:
	if map_active and event is InputEventKey and event.pressed:
		if not event.echo:
			if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:developer_sequence=""
			else:
				var code:int=event.physical_keycode if event.physical_keycode else event.keycode
				var expected:Array=[KEY_Q,KEY_W,KEY_E,KEY_R]
				if code==expected[developer_sequence.length()]:developer_sequence+="qwer"[developer_sequence.length()]
				else:developer_sequence="q" if code==KEY_Q else ""
				if developer_sequence=="qwer":
					developer_sequence="";developer_mode=true
					for button in developer_buttons:button.show()
	if presentation_active() and event is InputEventKey:
		# Leave native text copying to the focused selectable explanation.
		if event.ctrl_pressed and event.keycode == KEY_C: return
		if points_demo.active: points_demo.handle_key(event)
		elif line_demo.active: line_demo.handle_key(event)
		elif line_solution.active:line_solution.handle_key(event)
		elif plane_demo.active:plane_demo.handle_key(event)
		elif plane_solution.active:plane_solution.handle_key(event)
		elif course_workspace.active:course_workspace.handle_key(event)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:developer_sequence=""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if practice: practice.save_draft()
		if line_workspace:line_workspace.board.save_draft()
		save_states()
		get_tree().quit()
