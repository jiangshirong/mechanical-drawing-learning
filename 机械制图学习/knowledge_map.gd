extends MarginContainer
signal example_requested(id: String)
const UI = preload("res://ui_style.gd")
const Canvas = preload("res://knowledge_map_canvas.gd")
const PanZoom = preload("res://pan_zoom.gd")
var graph: Dictionary = {}
var canvas
var view
var buttons: Dictionary = {}
var nodes_by_id: Dictionary = {}
var current_labels: Dictionary = {}
var current_example := ""
var hovered_id := ""
var pressed_id := ""
var styles: Dictionary = {}

func _ready() -> void:
	name = "KnowledgeMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: add_theme_constant_override("margin_" + side, 22)
	graph = JSON.parse_string(FileAccess.get_file_as_string("res://assets/knowledge_map.json"))
	styles = {"normal":UI.card("20455b", "568cab"), "hover":UI.card("2c5b74", "a0d4eb",8,2), "pressed":UI.card("183f57", "b4e2f3",8,2), "current":UI.card("28556e", "d0ecfa",8,2)}
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "知识图谱"
	title.add_theme_font_size_override("font_size", UI.TITLE)
	header.add_child(title)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(space)
	var legend := Label.new()
	legend.text = "实线：前置知识　虚线：推荐顺序　蓝色：可进入"
	legend.add_theme_font_size_override("font_size", UI.CAPTION)
	legend.add_theme_color_override("font_color", UI.MUTED)
	header.add_child(legend)
	view = PanZoom.new()
	view.name = "MapView"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(view)
	canvas = Canvas.new()
	view.attach(canvas, Vector2(graph.extent[0],graph.extent[1]), "width")
	view.content_clicked.connect(on_content_click)
	view.pointer_updated.connect(on_pointer)
	for item in graph.nodes:
		nodes_by_id[item.id] = item
		var entry: Control
		if item.get("kind", "topic") == "group":
			var heading := Label.new()
			heading.text = item.title
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading.add_theme_font_size_override("font_size", UI.BODY)
			heading.add_theme_color_override("font_color", UI.MUTED)
			entry = heading
		else:
			if item.has("example"):
				var button := Button.new()
				button.name = "Map_" + str(item.id)
				button.focus_mode = Control.FOCUS_NONE
				button.add_theme_stylebox_override("normal", styles.normal)
				entry = button
				buttons[item.id] = button
			else:
				var panel := Panel.new()
				panel.add_theme_stylebox_override("panel", UI.card("172733", "354b5a"))
				entry = panel
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(entry)
		canvas.cards[item.id] = entry
		if item.get("kind", "topic") == "group": continue
		var contents := VBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 10
		contents.offset_right = -10
		contents.offset_top = 8
		contents.offset_bottom = -6
		contents.add_theme_constant_override("separation", 2)
		var caption := Label.new()
		caption.text = item.title
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", UI.BODY)
		caption.add_theme_color_override("font_color", Color("eff8ff") if item.has("example") else Color("b7c5ce"))
		contents.add_child(caption)
		var status := Label.new()
		status.text = "" if item.has("example") else item.get("status", "未制作")
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status.custom_minimum_size.y = 20
		status.add_theme_font_size_override("font_size", UI.CAPTION)
		status.add_theme_color_override("font_color", UI.MUTED)
		contents.add_child(status)
		if item.has("example"): current_labels[item.id] = status
	canvas.graph = graph
	canvas.resized.connect(canvas.layout_cards)
	canvas.layout_cards()

func hit_node(point: Vector2) -> String:
	for id in buttons:
		if canvas.cards[id].get_rect().has_point(point): return str(id)
	return ""

func on_content_click(point: Vector2) -> void:
	var id := hit_node(point)
	if not id.is_empty(): example_requested.emit(str(nodes_by_id[id].example))

func on_pointer(point: Vector2, pressed: bool, dragging: bool) -> void:
	var over := "" if dragging else hit_node(point)
	var down := over if pressed else ""
	if over != hovered_id or down != pressed_id:
		hovered_id = over
		pressed_id = down
		refresh_feedback()
	view.mouse_default_cursor_shape = Control.CURSOR_DRAG if dragging else (Control.CURSOR_POINTING_HAND if not over.is_empty() else Control.CURSOR_ARROW)

func refresh_feedback() -> void:
	for id in buttons:
		var role := "current" if str(nodes_by_id[id].example) == current_example else "normal"
		if id == hovered_id: role = "hover"
		if id == pressed_id: role = "pressed"
		buttons[id].set_meta("visual_state", role)
		buttons[id].add_theme_stylebox_override("normal", styles[role])
		current_labels[id].text = "当前" if str(nodes_by_id[id].example) == current_example else ""

func mark_current(example_id: String) -> void:
	current_example = example_id
	refresh_feedback()
