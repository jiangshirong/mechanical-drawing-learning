extends "res://pan_zoom.gd"
var board
var edit_hit: Dictionary = {}
var edit_start := Vector2.ZERO
var edit_snapshot: Dictionary = {}
var edit_dragged := false
var right_holding := false
var right_dragged := false
var right_press := Vector2.ZERO
var right_start := Vector2.ZERO
var right_finish := Vector2.ZERO

func update_pointer() -> void:
	if right_holding: return
	super.update_pointer()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f5f7f9"))

func apply_transform() -> void:
	super.apply_transform()
	if content: content.queue_redraw()
	if board: board.view_changed()

func cancel_drag() -> void:
	if board and not edit_hit.is_empty():
		if edit_dragged: board.commit_drag(edit_snapshot)
		edit_hit = {}
	right_holding = false
	right_dragged = false
	if board: board.marquee = null
	super.cancel_drag()

func _gui_input(event: InputEvent) -> void:
	if board.readonly:
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click and board.tool == "point" and not right_holding:
				board.open_naming((event.position-pan)/zoom)
				accept_event()
				return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and edit_hit.is_empty() and not holding:
				right_holding = true
				right_dragged = false
				right_press = event.position
				right_start = (event.position-pan)/zoom
				right_finish = right_start
			elif not event.pressed and right_holding:
				right_holding = false
				if right_dragged: board.box_select(right_start,right_finish)
				else: board.deselect()
				board.marquee = null
				board.canvas.queue_redraw()
			accept_event()
			return
		if right_holding:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				zoom_at(zoom*(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),event.position)
				right_finish = (event.position-pan)/zoom
				if right_dragged: board.marquee = Rect2(right_start,right_finish-right_start).abs()
				board.canvas.queue_redraw()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and board.pending == null:
			edit_hit = board.hit((event.position-pan)/zoom,true)
			if not edit_hit.is_empty():
				board.choose_hit(edit_hit)
				edit_start = event.position
				edit_snapshot = board.document.duplicate(true)
				edit_dragged = false
				accept_event()
				return
		if not edit_hit.is_empty():
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				if edit_dragged: board.commit_drag(edit_snapshot)
				else: board.click_content((event.position-pan)/zoom)
				edit_hit = {}
				accept_event()
				return
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				zoom_at(zoom*(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),event.position)
				accept_event()
				return
	elif event is InputEventMouseMotion:
		if right_holding:
			right_dragged = right_dragged or event.position.distance_to(right_press) >= 6
			right_finish = (event.position-pan)/zoom
			if right_dragged:
				board.cancel_pending()
				board.marquee = Rect2(right_start,right_finish-right_start).abs()
				board.canvas.queue_redraw()
			accept_event()
			return
		if not edit_hit.is_empty():
			last_position = event.position
			pointer_inside = Rect2(Vector2.ZERO,size).has_point(event.position)
			update_pointer()
			edit_dragged = edit_dragged or event.position.distance_to(edit_start) >= 6
			if edit_dragged: board.move_hit(edit_hit,(event.position-pan)/zoom)
			accept_event()
			return
	super._gui_input(event)
