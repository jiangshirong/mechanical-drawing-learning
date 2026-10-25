extends VBoxContainer
const Canvas = preload("res://practice_canvas.gd")
const View = preload("res://practice_view.gd")
var document: Dictionary = {"lines":[],"points":{}}
var selected: Dictionary = {"kind":"","id":"","end":""}
var selection: Array = []
var tool := "line"
var point_name := ""
var measuring := false
var cursor = null
var marquee = null
var pending = null
var hover = null
var measure = null
var undo_stack: Array = []
var readonly := false
var view
var canvas
var toolbar: HBoxContainer
var naming_dialog: ConfirmationDialog
var naming_id := ""
var name_field: LineEdit
var name_error: Label
var tools: Dictionary = {}
var error_label: Label
var error_text := ""
var blocked_save := false
var loading := true
var initial_fit_pending := true
var save_path := "user://practice-v1.json"
var question_id := "t01-q01"
var timer: Timer

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar = HBoxContainer.new()
	add_child(toolbar)
	for pair in [["画线 (L)","line"],["标点 (P)","point"],["撤销 (Ctrl+Z)","undo"],["删除 (D)","delete"]]:
		var key: String = pair[1]
		var b := Button.new()
		b.name = "Tool_"+key
		b.text = pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): command(key))
		b.toggle_mode = key in ["line","point"]
		tools[key] = b
		toolbar.add_child(b)
		if b.toggle_mode: preload("res://ui_style.gd").mark_current(b)
	naming_dialog = ConfirmationDialog.new()
	naming_dialog.title = "点名"
	naming_dialog.exclusive = true
	naming_dialog.dialog_hide_on_ok = false
	naming_dialog.ok_button_text = "确定"
	naming_dialog.cancel_button_text = "取消"
	add_child(naming_dialog)
	var form := VBoxContainer.new()
	naming_dialog.add_child(form)
	name_field = LineEdit.new()
	name_field.name = "PointName"
	name_field.placeholder_text = "输入点名"
	name_field.custom_minimum_size.x = 280
	name_field.text_changed.connect(func(_value: String): name_error.hide())
	name_field.text_submitted.connect(rename_selected_point)
	form.add_child(name_field)
	name_error = Label.new()
	name_error.text = "点名已存在"
	form.add_child(name_error)
	name_error.hide()
	naming_dialog.confirmed.connect(func(): rename_selected_point(name_field.text))
	naming_dialog.canceled.connect(close_naming)
	naming_dialog.close_requested.connect(close_naming)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(error_label)
	view = create_view()
	view.name = "PracticeView"
	view.board = self
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(300,300)
	view.minimum_zoom = 0.15
	view.maximum_zoom = 6
	add_child(view)
	canvas = create_canvas()
	canvas.name = "CoordinatePaper"
	canvas.board = self
	canvas.teacher = readonly
	view.attach(canvas,Vector2(600,600))
	view.content_clicked.connect(click_content)
	view.pointer_updated.connect(update_pointer)
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.25
	timer.timeout.connect(save_draft)
	add_child(timer)
	if readonly:
		name_field.editable = false
		toolbar.hide()

		loading = false
	else: call_deferred("load_draft")
	visibility_changed.connect(func():
		if not is_visible_in_tree(): set_measuring(false))
	update_tools()

func create_view():
	return View.new()

func create_canvas():
	return Canvas.new()

func set_measuring(value: bool) -> void:
	measuring = value
	if view: view.update_pointer()
	if canvas: canvas.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_measuring(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	# A release always clears temporary measuring, even after leaving this page.
	if key == KEY_M and not event.pressed:
		set_measuring(false)
		return
	if readonly or not is_visible_in_tree() or naming_dialog.visible: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed and key == KEY_Z:
		if event.pressed and not event.echo: command("undo")
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	if key == KEY_M:
		if event.pressed: set_measuring(true)
		get_viewport().set_input_as_handled()
	elif event.pressed and not event.echo and key == KEY_D:
		command("delete")
		get_viewport().set_input_as_handled()
	elif event.pressed and not event.echo and key in [KEY_L,KEY_P]:
		command("line" if key == KEY_L else "point")
		view.update_pointer()
		get_viewport().set_input_as_handled()

func update_tools() -> void:
	if not tools.has("line"): return
	for key in ["line","point"]: tools[key].set_pressed_no_signal(tool == key)
	tools.undo.disabled = undo_stack.is_empty()
	tools.delete.disabled = selection.is_empty() and selected.kind.is_empty()
	error_label.text = error_text
	error_label.visible = not error_text.is_empty()
	if canvas: canvas.queue_redraw()

func command(key: String) -> void:
	if readonly: return
	if key not in ["line","point","undo","delete"]: return
	cancel_pending()
	view.cancel_drag()
	if key in ["line","point"]:
		tool = key
		measure = null
	elif key == "undo":
		if not undo_stack.is_empty():
			document = undo_stack.pop_back()
			clear_selection()
			measure = null
			autosave()
	elif key == "delete":
		var before := document.duplicate(true)
		for item in current_selection():
			if item.kind == "point":
				document.points.erase(item.id)
				if document.has("point_labels"): document.point_labels.erase(item.id)
			elif item.kind == "line":
				for i in range(document.lines.size()-1,-1,-1):
					if document.lines[i].id == item.id: document.lines.remove_at(i)
		clear_selection()
		measure = null
		commit_drag(before)
	update_tools()

func snap(content_position: Vector2, directional := false) -> Array:
	var p := Canvas.mm(content_position)
	if directional and pending != null:
		var d := p-Vector2(pending[0],pending[1])
		var limit := tan(deg_to_rad(5))
		if absf(d.y) <= absf(d.x)*limit: p.y = pending[1]
		elif absf(d.x) <= absf(d.y)*limit: p.x = pending[0]
	return [roundf(p.x),roundf(p.y)]

func click_content(p: Vector2) -> void:
	if readonly: return
	if tool == "line":
		if pending == null:
			var existing := hit(p,false)
			if not existing.is_empty() and existing.kind == "line":
				var line := find_line(existing.id)
				# Body clicks select; endpoint clicks can start a new line.
				if p.distance_to(Canvas.at(line[existing.end])) > 9.0/view.zoom:
					choose_hit(existing)
					return
		clear_selection()
		var q := snap(p,true)
		if pending == null:
			pending = q
			hover = q
			measure = q
		else:
			if q != pending:
				var before := document.duplicate(true)
				document.lines.append({"id":str(Time.get_ticks_usec())+"-"+str(document.lines.size()),"a":pending.duplicate(),"b":q})
				commit_drag(before)
			cancel_pending()
	elif tool == "point":
		var found := hit_point(p)
		if not found.is_empty():
			choose_hit(found)
		else:
			var before := document.duplicate(true)
			var id := "point-"+str(Time.get_ticks_usec())
			while document.points.has(id): id += "-new"
			document.points[id] = snap(p)
			if not document.has("point_labels"): document.point_labels = {}
			document.point_labels[id] = ""
			choose_hit({"kind":"point","id":id,"end":""})
			commit_drag(before)
	else:
		choose_hit(hit(p,false))
	update_tools()

func update_pointer(p: Vector2,_pressed: bool,_dragging: bool) -> void:
	cursor = snap(p,true) if p.is_finite() and marquee == null else null
	if pending != null and p.is_finite():
		hover = snap(p,true)
		measure = hover
	canvas.queue_redraw()

func cancel_pending() -> void:
	close_naming()
	var had_preview: bool = pending != null
	pending = null
	hover = null
	cursor = null
	marquee = null
	if had_preview: measure = null
	if canvas: canvas.queue_redraw()

func find_line(id: String) -> Dictionary:
	for line in document.lines:
		if line.id == id: return line
	return {}

func hit(p: Vector2,handles_only := false) -> Dictionary:
	var threshold: float = 9.0/view.zoom
	# Selected handles retain precedence when geometry overlaps.
	for item in current_selection():
		if item.kind != "line": continue
		var current := find_line(item.id)
		if not current.is_empty():
			for key in ["a","b"]:
				if p.distance_to(Canvas.at(current[key])) <= threshold: return {"kind":"line","id":current.id,"end":key}
	for key in document.points:
		if p.distance_to(Canvas.at(document.points[key])) <= threshold: return {"kind":"point","id":key,"end":""}
	# Endpoints are editable directly in both remaining tools.
	for line in document.lines:
		for key in ["a","b"]:
			if p.distance_to(Canvas.at(line[key])) <= threshold:
				return {"kind":"line","id":line.id,"end":key}
	if handles_only: return {}
	var nearest := threshold
	var found: Dictionary = {}
	for line in document.lines:
		var a := Canvas.at(line.a)
		var b := Canvas.at(line.b)
		var distance := p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
		if distance <= nearest:
			nearest = distance
			found = {"kind":"line","id":line.id,"end":"a" if p.distance_to(a) <= p.distance_to(b) else "b"}
	return found

func choose_hit(found: Dictionary) -> void:
	selected = found.duplicate() if not found.is_empty() else {"kind":"","id":"","end":""}
	selection = [selected.duplicate()] if not selected.kind.is_empty() else []
	measure = null
	if selected.kind == "line": measure = find_line(selected.id)[selected.end]
	elif selected.kind == "point":
		measure = document.points[selected.id]
	update_tools()

func move_hit(found: Dictionary,p: Vector2) -> void:
	var q := snap(p)
	if found.kind == "line": find_line(found.id)[found.end] = q
	else: document.points[found.id] = q
	measure = q
	canvas.queue_redraw()

func commit_drag(before: Dictionary) -> void:
	if before == document: return
	undo_stack.append(before.duplicate(true))
	update_tools()
	autosave()

func view_changed() -> void:
	if not loading and not readonly: autosave()

func autosave() -> void:
	if not readonly and not loading and not initial_fit_pending and not blocked_save and timer: timer.start()

func snapshot() -> Dictionary:
	return {"document":document.duplicate(true),"selected":selected.duplicate(true),"selection":selection.duplicate(true),"view":view.get_view_state(),"tool":tool,"point_name":point_name,"measure":measure}

func restore_snapshot(state: Dictionary) -> void:
	document = state.document.duplicate(true)
	selected = state.selected.duplicate(true)
	selection = state.get("selection",[]).duplicate(true)
	tool = state.tool
	point_name = state.point_name
	name_field.text = point_name
	measure = state.measure
	view.restore_view_state(state.view)
	update_tools()

func valid_pair(p) -> bool:
	return p is Array and p.size() == 2 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int) and is_finite(p[0]) and is_finite(p[1]) and absf(p[0]) < 100000 and absf(p[1]) < 100000

func valid_save(saved) -> bool:
	if not saved is Dictionary or saved.get("schema_version") != 1 or saved.get("question_id") != question_id: return false
	if not saved.get("lines") is Array or not saved.get("points") is Dictionary or not saved.get("view") is Dictionary: return false
	var ids: Dictionary = {}
	for line in saved.lines:
		if not line is Dictionary or not line.get("id") is String or ids.has(line.id) or not valid_pair(line.get("a")) or not valid_pair(line.get("b")) or line.a == line.b: return false
		ids[line.id] = true
	for key in saved.points:
		if not valid_name(key) or not valid_pair(saved.points[key]): return false
	var labels = saved.get("point_labels",{})
	if not labels is Dictionary: return false
	var used_names: Dictionary = {}
	for id in labels:
		if not saved.points.has(id) or not labels[id] is String or (not labels[id].is_empty() and not valid_name(labels[id])): return false
	for id in saved.points:
		var label: String = labels.get(id,id)
		if not label.is_empty():
			if used_names.has(label): return false
			used_names[label] = true
	return valid_pair(saved.view.get("center_mm")) and (saved.view.get("zoom") is float or saved.view.get("zoom") is int) and is_finite(saved.view.zoom) and saved.view.zoom > 0

func load_draft() -> void:
	view.fit_content()
	if FileAccess.file_exists(save_path):
		var parser := JSON.new()
		var parse_error := parser.parse(FileAccess.get_file_as_string(save_path))
		var saved = parser.data if parse_error == OK else null
		if not valid_save(saved):
			blocked_save = true
			error_text = "草稿无法读取，原文件已保留；本次修改暂不写入存档。"
		else:
			document = {"lines":saved.lines,"points":saved.points}
			if saved.has("point_labels"): document.point_labels = saved.point_labels
			view.restore_view_state({"zoom":saved.view.zoom,"center":Canvas.at(saved.view.center_mm)})
			initial_fit_pending = false
	loading = false
	update_tools()

func valid_name(value) -> bool:
	if not value is String or value.is_empty() or value != value.strip_edges(): return false
	for i in range(value.length()):
		if value.unicode_at(i) < 32 or value.unicode_at(i) == 127: return false
	return true

# IDs remain stable across naming, dragging, undo and persistence. Older saves
# without point_labels retain their original dictionary keys as display names.
func point_label(id: String) -> String:
	return document.get("point_labels",{}).get(id,id)

func hit_point(p: Vector2) -> Dictionary:
	for id in document.points:
		if p.distance_to(Canvas.at(document.points[id])) <= 9.0/view.zoom:
			return {"kind":"point","id":id,"end":""}
	return {}

func open_naming(p: Vector2) -> void:
	if readonly or tool != "point": return
	var found := hit_point(p)
	if found.is_empty(): return
	view.cancel_drag()
	choose_hit(found)
	set_measuring(false)
	naming_id = found.id
	name_field.text = point_label(naming_id)
	name_error.hide()
	cursor = null
	naming_dialog.popup_centered(Vector2i(320,130))
	name_field.grab_focus()
	name_field.select_all()

func close_naming() -> void:
	naming_id = ""
	if naming_dialog: naming_dialog.hide()

func deselect() -> void:
	cancel_pending()
	clear_selection()
	measure = null
	update_tools()

func rename_selected_point(value: String) -> void:
	if readonly or naming_id.is_empty() or not document.points.has(naming_id): return
	var new_name := value.strip_edges()
	if not new_name.is_empty() and not valid_name(new_name):
		name_error.text = "点名不能包含控制字符"
		name_error.show()
		return
	for id in document.points:
		if id != naming_id and not new_name.is_empty() and point_label(id) == new_name:
			name_error.text = "点名已存在"
			name_error.show()
			return
	var before := document.duplicate(true)
	if point_label(naming_id) != new_name:
		if not document.has("point_labels"): document.point_labels = {}
		document.point_labels[naming_id] = new_name
	close_naming()
	commit_drag(before)
	canvas.queue_redraw()

func current_selection() -> Array:
	if not selection.is_empty(): return selection
	return [selected] if not selected.kind.is_empty() else []

func clear_selection() -> void:
	selected = {"kind":"","id":"","end":""}
	selection.clear()

func box_select(a: Vector2,b: Vector2) -> void:
	var rect := Rect2(a,b-a).abs()
	clear_selection()
	for key in document.points:
		var p := Canvas.at(document.points[key])
		if in_box(rect,p): selection.append({"kind":"point","id":key,"end":""})
	var corners: Array = [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for line in document.lines:
		var start := Canvas.at(line.a)
		var end := Canvas.at(line.b)
		var intersects := in_box(rect,start) or in_box(rect,end)
		if not intersects:
			for i in range(4):
				if Geometry2D.segment_intersects_segment(start,end,corners[i],corners[(i+1)%4]) != null: intersects = true; break
		if intersects: selection.append({"kind":"line","id":line.id,"end":"a"})
	if selection.size() == 1:
		selected = selection[0].duplicate()
	measure = null
	cursor = null
	marquee = null
	update_tools()

func in_box(rect: Rect2,p: Vector2) -> bool:
	return p.x >= rect.position.x and p.x <= rect.end.x and p.y >= rect.position.y and p.y <= rect.end.y

func save_draft() -> void:
	if "--qa-line-learning" in OS.get_cmdline_user_args() or "--qa-line-reopen" in OS.get_cmdline_user_args():
		if not readonly and save_path!="user://qa-line-practice.json":
			push_error("直线专项禁止写入非独立练习存档"); return
	if "--qa-points-beats" in OS.get_cmdline_user_args() or "--qa-points-beats-reopen" in OS.get_cmdline_user_args():
		if not readonly and save_path != "user://qa-points-beats-practice.json":
			push_error("点章节专项禁止写入非独立练习存档")
			return
	if readonly or loading or initial_fit_pending or blocked_save: return
	var state: Dictionary = view.get_view_state()
	var center := Canvas.mm(state.center)
	var saved := {"schema_version":1,"question_id":question_id,"lines":document.lines,"points":document.points,"view":{"zoom":state.zoom,"center_mm":[center.x,center.y]}}
	if document.has("point_labels"): saved.point_labels = document.point_labels
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved,"\t"))
		file.close()
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path)) == OK: return
	error_text = "草稿保存失败，请检查本机存储；已完成的作图仍在当前界面。"
	update_tools()
