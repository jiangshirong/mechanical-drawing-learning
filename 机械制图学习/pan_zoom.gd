extends Control
signal content_clicked(point: Vector2)
signal pointer_updated(point: Vector2, pressed: bool, dragging: bool)

var content: Control
var zoom := 1.0
var pan := Vector2.ZERO
var minimum_zoom := 0.15
var maximum_zoom := 5.0
var fit_mode := "contain"
var holding := false
var dragged := false
var press_position := Vector2.ZERO
var press_pan := Vector2.ZERO
var last_position := Vector2.ZERO
var pointer_inside := false
var previous_size := Vector2.ZERO
var needs_fit := true
var drag_distance := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(on_resized)
	mouse_exited.connect(func():
		pointer_inside = false
		update_pointer()
	)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_drag()
	)

func attach(node: Control, extent: Vector2, mode := "contain") -> void:
	content = node
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.size = extent
	fit_mode = mode
	needs_fit = true
	call_deferred("fit_if_needed")

func fit_if_needed() -> void:
	if needs_fit: fit_content()

func fit_content() -> void:
	if not content or size.x < 1 or size.y < 1: return
	var available := (size - Vector2(32, 32)).max(Vector2.ONE)
	var ratio := available.x / maxf(content.size.x, 1)
	if fit_mode == "contain": ratio = minf(ratio, available.y / maxf(content.size.y, 1))
	zoom = clampf(ratio, minimum_zoom, maximum_zoom)
	pan = (size - content.size * zoom) * 0.5
	if fit_mode == "width": pan.y = 16
	needs_fit = false
	previous_size = size
	apply_transform()

func reset_content(extent: Vector2, mode := "contain") -> void:
	cancel_drag()
	content.size = extent
	fit_mode = mode
	needs_fit = true
	call_deferred("fit_if_needed")

func get_view_state() -> Dictionary:
	return {"zoom":zoom,"center":(size * 0.5 - pan) / zoom}

func restore_view_state(state: Dictionary) -> void:
	cancel_drag()
	zoom = clampf(float(state.zoom), minimum_zoom, maximum_zoom)
	pan = size * 0.5 - Vector2(state.center) * zoom
	needs_fit = false
	previous_size = size
	apply_transform()

func on_resized() -> void:
	if not content: return
	if needs_fit or previous_size == Vector2.ZERO:
		fit_content()
	else:
		pan += (size - previous_size) * 0.5
		previous_size = size
		apply_transform()

func constrain_pan() -> void:
	# Keep a meaningful piece visible without introducing a toolbar.
	var extent := content.size * zoom
	var visible := extent.min(size * 0.5).min(Vector2(96, 96))
	pan.x = clampf(pan.x, visible.x - extent.x, size.x - visible.x)
	pan.y = clampf(pan.y, visible.y - extent.y, size.y - visible.y)

func apply_transform() -> void:
	if not content: return
	constrain_pan()
	content.position = pan
	content.scale = Vector2.ONE * zoom
	update_pointer()

func zoom_at(value: float, point: Vector2) -> void:
	var world := (point - pan) / zoom
	zoom = clampf(value, minimum_zoom, maximum_zoom)
	pan = point - world * zoom
	apply_transform()

func center_on(point: Vector2) -> void:
	pan = size * 0.5 - point * zoom
	apply_transform()

func update_pointer() -> void:
	var point := (last_position - pan) / zoom if pointer_inside else Vector2(-INF, -INF)
	pointer_updated.emit(point, holding, dragged)
	if holding and dragged: mouse_default_cursor_shape = Control.CURSOR_DRAG

func cancel_drag() -> void:
	holding = false
	dragged = false
	pointer_inside = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	update_pointer()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		last_position = event.position
		pointer_inside = Rect2(Vector2.ZERO, size).has_point(event.position)
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				zoom_at(zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), event.position)
				if holding:
					dragged = true
					press_position = event.position
					press_pan = pan
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				holding = true
				dragged = false
				drag_distance = 0.0
				press_position = event.position
				press_pan = pan
			else:
				var clicked := holding and not dragged and pointer_inside
				holding = false
				dragged = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				if clicked: content_clicked.emit((event.position - pan) / zoom)
			accept_event()
	elif event is InputEventMouseMotion and holding:
		drag_distance = maxf(drag_distance, event.position.distance_to(press_position))
		if drag_distance >= 6: dragged = true
		if dragged:
			pan = press_pan + event.position - press_position
			apply_transform()
			# Rebase after clamping: returning responds immediately.
			press_pan = pan
			press_position = event.position
		accept_event()
	update_pointer()
