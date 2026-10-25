extends RefCounted
# Project-specific desktop roles, shared by navigation and teaching text.
const BODY := 18
const CAPTION := 16
const TITLE := 24
const CONCLUSION := 20
const GAP := 12
const TEXT := Color("dce7ee")
const MUTED := Color("aab9c5")
const EMPHASIS := Color("ffdfa5")
const PAPER := Color("f5f7f9")
const BACKGROUND := Color("101d29")

static func navigation_icon(button:Button,key:String) -> void:
	button.icon=load("res://assets/icons/"+key+".svg")
	button.expand_icon=false
	button.add_theme_constant_override("h_separation",8)

static func mark_current(button: Button) -> void:
	var pressed: StyleBoxFlat = make_theme().get_stylebox("pressed","Button").duplicate()
	pressed.bg_color = Color("d06d35")
	button.add_theme_stylebox_override("pressed",pressed)

static func card(background: String, border: String, radius := 8, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/msyh.ttc")
	t.default_font_size = BODY
	t.set_stylebox("panel", "Panel", card("f5f7f9", "f5f7f9", 12, 0))
	var normal := card("203747", "203747", 7, 0)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	t.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("31576e")
	t.set_stylebox("hover", "Button", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color("183f57")
	t.set_stylebox("pressed", "Button", pressed)
	var off := normal.duplicate()
	off.bg_color = Color("1b2631")
	t.set_stylebox("disabled", "Button", off)
	t.set_color("font_color", "Label", TEXT)
	var input := card("203747","31576e",7,1)
	input.content_margin_left = 10
	input.content_margin_right = 10
	input.content_margin_top = 8
	input.content_margin_bottom = 8
	t.set_stylebox("normal","LineEdit",input)
	t.set_stylebox("read_only","LineEdit",input)
	t.set_stylebox("focus","LineEdit",card("00000000","d06d35",7,2))
	t.set_color("font_color","LineEdit",TEXT)
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_color("caret_color","LineEdit",EMPHASIS)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_constant("separation", "VBoxContainer", GAP)
	t.set_constant("separation", "HBoxContainer", GAP)
	return t

static func teaching_navigation(button: Button) -> void:
	for role in ["normal","hover","pressed","disabled"]:
		var color: String = {"normal":"d4dde2","hover":"e2e8ec","pressed":"bbc9d2","disabled":"87939c"}[role]
		var style := card(color,color,6,0)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(role,style)
	for role in ["font_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(role,Color("344b59"))
	button.add_theme_color_override("font_disabled_color",Color("495d6a"))
