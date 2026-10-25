extends HBoxContainer
const UI = preload("res://ui_style.gd")
signal chapter_chosen(index: int)
var nodes: Array[Button] = []
var current := -1

func configure(groups: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	nodes.clear()
	add_theme_constant_override("separation",6)
	for i in range(groups.size()):
		if i > 0:
			var slot := Control.new()
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.custom_minimum_size.x = 6
			add_child(slot)
		var button := Button.new()
		button.name = "Chapter_"+str(groups[i].id)
		button.text = str(i+1)
		button.tooltip_text = str(groups[i].title)
		button.custom_minimum_size = Vector2(32,32)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",UI.CAPTION)
		button.pressed.connect(func(): chapter_chosen.emit(i))
		button.item_rect_changed.connect(queue_redraw)
		add_child(button)
		nodes.append(button)
	set_current(-1)

func set_current(index: int) -> void:
	current = index
	for i in range(nodes.size()):
		var selected := i == index
		for role in ["normal","hover","pressed"]:
			var background := "536b7a" if selected else "253846"
			if role == "hover": background = "647c8b" if selected else "3b5363"
			if role == "pressed": background = "3a5261"
			var style := UI.card(background,"aab9c5" if selected else "536674",16,1)
			style.content_margin_left = 4
			style.content_margin_right = 4
			nodes[i].add_theme_stylebox_override(role,style)
		for role in ["font_color","font_hover_color","font_pressed_color"]:
			nodes[i].add_theme_color_override(role,UI.TEXT if i <= index else UI.MUTED)
	queue_redraw()

func _draw() -> void:
	# Native buttons own hover/press events; the track spans the space between their centers.
	for i in range(nodes.size()-1):
		var left := nodes[i].position+nodes[i].size*0.5
		var right := nodes[i+1].position+nodes[i+1].size*0.5
		draw_line(left,right,Color("8b9ca7") if i < current else Color("3d505e"),2,true)

func _ready() -> void:
	resized.connect(queue_redraw)

