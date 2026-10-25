extends Node2D
# Decorations sit behind the same native selectable RichTextLabel. No
# duplicate text, BBCode, input surface, or additional playback is introduced.
const UI = preload("res://ui_style.gd")
var overlay
var rows: Array[Rect2] = []
var style: StyleBoxFlat

func _ready() -> void:
	show_behind_parent=true
	style=UI.card("94b2ca","688fa8",4,1)
	style.border_width_left=2
	style.border_color=Color("688fa8")

func _draw() -> void:
	rows.clear()
	if not overlay or not overlay.demo.active: return
	var copy: RichTextLabel = overlay.label
	for condition in overlay.conditions:
		var first: int = copy.text.find(condition)
		if first<0 or (copy.visible_characters>=0 and copy.visible_characters<=first): continue
		var line: int = copy.get_character_line(first)
		if line<0 or line>=copy.get_line_count(): continue
		var rect := Rect2(Vector2(0,copy.get_line_offset(line)+1),Vector2(copy.size.x,copy.get_line_height(line)-3))
		rows.append(rect)
		draw_style_box(style,rect)
