extends Control
const UI = preload("res://ui_style.gd")
var demo
var button: Button
var panel: PanelContainer
var label: RichTextLabel
var pinned := false
var pointer := Vector2(-10000,-10000)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.name = "Question"
	button.text = "题"
	button.custom_minimum_size = Vector2(40,40)
	button.focus_mode = Control.FOCUS_NONE
	UI.teaching_navigation(button)
	add_child(button)
	button.mouse_entered.connect(func(): panel.show())
	button.mouse_exited.connect(func(): call_deferred("close_hover"))
	button.pressed.connect(func():
		pinned = not pinned
		panel.visible = pinned)
	panel = PanelContainer.new()
	panel.name = "QuestionText"
	var style := UI.card("f5f7f9","d4dde2",6,1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	panel.mouse_exited.connect(func(): call_deferred("close_hover"))
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
	label.text = str(demo.config.statement)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size",UI.BODY)
	label.add_theme_color_override("default_color",Color("263747"))
	panel.add_child(label)
	reset()

func reset() -> void:
	pinned = false
	pointer = Vector2(-10000,-10000)
	panel.hide()

func _process(_delta: float) -> void:
	if not demo.active or not visible: return
	var area: Rect2 = demo.stage.get_global_rect()
	button.position = Vector2(area.end.x-52,area.position.y+12)-global_position
	var width := clampf(area.size.x*.42,320,540)
	var measure := label.get_theme_font("normal_font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,UI.BODY).x
	label.custom_minimum_size.x = width-28
	panel.size = Vector2(width,ceili(measure/(width-28))*27+24)
	panel.position = Vector2(area.end.x-width-12,area.position.y+62)-global_position
	close_hover()

func close_hover() -> void:
	if pinned or not panel.visible: return
	var region := button.get_global_rect().merge(panel.get_global_rect()).grow(5)
	if not region.has_point(pointer): panel.hide()

func _input(event: InputEvent) -> void:
	if not demo.active or not visible: return
	if event is InputEventMouseMotion:
		pointer = event.position
		if button.get_global_rect().has_point(pointer): panel.show()
		close_hover()
	if event is InputEventMouseButton and event.pressed and pinned:
		if not button.get_global_rect().has_point(event.position) and not panel.get_global_rect().has_point(event.position): reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pointer = Vector2(-10000,-10000)
		if panel: close_hover()

