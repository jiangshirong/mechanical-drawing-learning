extends "res://points_learning_check.gd"

func double_mm(p: Array) -> void:
	await click_mm(p)
	for pressed in [true,false]:
		var e = InputEventMouseButton.new()
		e.position = b.view.get_global_transform_with_canvas()*local_mm(p)
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.double_click = pressed
		r.get_viewport().push_input(e,true)
		await h.wait_frames(2)

func input_name(value: String) -> void:
	# Input remains inside the embedded Godot dialog viewport.
	var pos = b.name_field.get_global_transform_with_canvas()*(b.name_field.size*0.5)
	var motion = InputEventMouseMotion.new()
	motion.position = pos
	b.naming_dialog.push_input(motion,true)
	for pressed in [true,false]:
		var mouse = InputEventMouseButton.new()
		mouse.position = pos
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		b.naming_dialog.push_input(mouse,true)
		await h.wait_frames(2)
	b.name_field.grab_focus()
	await h.wait_frames(3)
	for pressed in [true,false]:
		var e = InputEventKey.new()
		e.keycode = KEY_A
		e.ctrl_pressed = true
		e.pressed = pressed
		b.naming_dialog.push_input(e,true)
	for i in range(value.length()):
		for pressed in [true,false]:
			var e = InputEventKey.new()
			e.unicode = value.unicode_at(i)
			e.pressed = pressed
			b.naming_dialog.push_input(e,true)
	await h.wait_frames(2)
	for pressed in [true,false]:
		var e = InputEventKey.new()
		e.keycode = KEY_ENTER
		e.pressed = pressed
		b.naming_dialog.push_input(e,true)
	await h.wait_frames(3)

func right_click(p: Array) -> void:
	for pressed in [true,false]: c.mouse_button(b.view,local_mm(p),MOUSE_BUTTON_RIGHT,pressed)
	await h.wait_frames(3)

func hold_key(key: int,pressed: bool,ctrl := false) -> void:
	var e = InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = pressed
	e.ctrl_pressed = ctrl
	r.get_viewport().push_input(e,true)
	await h.wait_frames(2)

func hover_mm(p: Array) -> void:
	var e = InputEventMouseMotion.new()
	e.position = b.view.get_global_transform_with_canvas()*local_mm(p)
	r.get_viewport().push_input(e,true)
	await h.wait_frames(3)
	b.canvas.queue_redraw()
	await RenderingServer.frame_post_draw

func run(root,flag: String) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	c = load("res://canvas_check.gd").new()
	c.r = r
	c.h = h
	b = r.practice
	await h.wait_frames(18)
	check("startup_map",r.map_active)
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	await h.choose(0)
	await button(r.free_shell.find_child("Mode_practice",true,false))
	check("no_permanent_name_field",not b.toolbar.is_ancestor_of(b.name_field) and not b.naming_dialog.visible, b.name_field.text)
	if flag.ends_with("reopen"):
		var expected = JSON.parse_string(FileAccess.get_file_as_string("res://qa/point-naming-expected.json"))
		check("names_and_unnamed_restored",b.document == expected)
		check("popup_not_restored",not b.naming_dialog.visible and b.naming_id.is_empty())
		check("undo_not_saved",b.undo_stack.is_empty())
		finish("point-naming-reopen.json")
		return
	b.command("point")
	await click_mm([-10,12])
	var first: String = b.selected.id
	check("single_click_places_unnamed",b.document.points.size()==1 and b.point_label(first)=="" and not b.naming_dialog.visible, b.name_field.text)
	await click_mm([8,5])
	var second: String = b.selected.id
	check("multiple_unnamed_points",first!=second and b.point_label(second)=="")
	var height: float = b.view.size.y
	await double_mm([-10,12])
	check("double_click_opens_popup_without_extra_point",b.naming_dialog.visible and b.naming_id==first and b.document.points.size()==2)
	check("name_field_focused",b.name_field.has_focus())
	check("popup_does_not_resize_paper",b.view.size.y==height)
	await input_name("a''")
	check("keyboard_names_point",b.point_label(first)=="a''" and not b.naming_dialog.visible,b.name_field.text)
	check("position_and_id_preserved",b.document.points[first]==[-10.0,12.0] and b.selected.id==first)
	b.command("undo")
	check("undo_name_only",b.point_label(first)=="" and b.document.points.size()==2)
	await double_mm([-10,12])
	await input_name("a''")
	check("rename_after_undo",b.point_label(first)=="a''")
	await double_mm([8,5])
	await input_name("a''")
	check("duplicate_rejected",b.naming_dialog.visible and b.name_error.visible and b.point_label(second)=="")
	await input_name("测试点")
	check("unicode_name",b.point_label(second)=="测试点" and not b.naming_dialog.visible, b.name_field.text)
	await double_mm([-10,12])
	await input_name("A")
	check("rename_existing",b.point_label(first)=="A" and b.document.points.size()==2)
	await double_mm([-10,12])
	var before = b.document.duplicate(true)
	b.naming_dialog.canceled.emit()
	check("cancel_popup_preserves_document",before==b.document and not b.naming_dialog.visible, b.name_field.text)
	var count: int = b.undo_stack.size()
	await right_click([0,0])
	check("right_click_clears_selection",b.selection.is_empty() and b.selected.kind.is_empty() and b.measure==null)
	check("deselect_no_document_or_undo_change",before==b.document and count==b.undo_stack.size())
	b.command("line")
	await click_mm([0,0])
	await right_click([0,0])
	check("right_click_cancels_preview",b.pending==null)
	await click_mm([-15,-10])
	await click_mm([15,-10])
	b.command("line")
	await click_mm([0,-10])
	check("line_selected",b.selected.kind=="line")
	await right_click([0,-10])
	check("right_click_clears_line_selection",b.current_selection().is_empty() and b.document.lines.size()==1)
	# Marquee remains right-drag, with matched events and no desktop pointer.
	var start = local_mm([-20,20])
	var end = local_mm([20,-20])
	c.mouse_button(b.view,start,MOUSE_BUTTON_RIGHT,true)
	var motion = InputEventMouseMotion.new()
	motion.position = b.view.get_global_transform_with_canvas()*end
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	r.get_viewport().push_input(motion,true)
	await h.wait_frames(2)
	c.mouse_button(b.view,end,MOUSE_BUTTON_RIGHT,false)
	await h.wait_frames(2)
	check("right_drag_marquee_retained",b.selection.size()==3)
	before = b.document.duplicate(true)
	b.command("delete")
	check("batch_delete",b.document.points.is_empty() and b.document.lines.is_empty())
	b.command("undo")
	check("undo_restores_names",b.document==before)
	b.command("point")
	await click_mm([2,-3])
	check("new_point_not_previous_name",b.document.points.size()==3 and b.point_label(b.selected.id)=="")
	await double_mm([2,-3])
	b.cancel_pending()
	check("mode_transition_closes_popup",not b.naming_dialog.visible)
	before = b.document.duplicate(true)
	await button(r.practice_shell.find_child("Teaching",true,false))
	await wait_demo()
	check("teaching_no_naming_popup",r.points_demo.active and not b.naming_dialog.visible and not b.name_field.editable)
	await button(r.points_demo.leave)
	check("teaching_returns_unchanged",not r.points_demo.active and b.document==before and b.name_field.editable)
	# Old version-1 documents still have valid, visible names without migration.
	var legacy = {"schema_version":1,"question_id":b.question_id,"lines":[],"points":{"a'":[-10,12]},"view":{"zoom":1,"center_mm":[0,0]}}
	check("legacy_save_accepted",b.valid_save(legacy))
	var old = b.document
	b.document = {"lines":[],"points":legacy.points}
	check("legacy_label_preserved",b.point_label("a'")=="a'")
	b.document = old
	b.save_draft()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(b.save_path))
	check("extended_save_valid",b.valid_save(saved))
	saved.point_labels["missing"]="错误"
	check("bad_metadata_rejected",not b.valid_save(saved))
	FileAccess.open("res://qa/point-naming-expected.json",FileAccess.WRITE).store_string(JSON.stringify(b.document,"\t"))
	await double_mm([-10,12])
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/point-naming-dialog.png")
	b.close_naming()
	check("select_mode_removed",not b.tools.has("select") and b.toolbar.find_child("Tool_select",true,false)==null)
	await hold_key(KEY_L,true)
	await hold_key(KEY_L,false)
	check("line_shortcut",b.tool=="line" and b.tools.line.button_pressed)
	await hover_mm([-9,14])
	check("no_automatic_dimensions_line",b.canvas.last_measure_geometry.is_empty())
	await hold_key(KEY_M,true)
	await hover_mm([-9,14])
	check("held_m_measures",b.measuring and b.canvas.last_measure_geometry.get("x_mm")==9.0 and b.canvas.last_measure_geometry.get("y_mm")==14.0)
	check("no_coordinate_caption",not b.canvas.last_measure_geometry.get("coordinate_visible",true))
	await hold_key(KEY_M,false)
	await hover_mm([-9,14])
	check("m_release_hides",not b.measuring and b.canvas.last_measure_geometry.is_empty())
	await hold_key(KEY_P,true)
	await hold_key(KEY_P,false)
	check("point_shortcut",b.tool=="point" and b.tools.point.button_pressed)
	await hover_mm([8,5])
	check("no_automatic_dimensions_point",b.canvas.last_measure_geometry.is_empty())
	await hold_key(KEY_M,true)
	await hover_mm([0,0])
	check("origin_zero_dimensions",b.canvas.last_measure_geometry.get("x_mm")==0.0 and b.canvas.last_measure_geometry.get("y_mm")==0.0)
	await hold_key(KEY_M,false)
	# No select mode is needed for direct point and line endpoint edits.
	var id = b.hit_point(Canvas.at([2,-3])).id
	var prior = b.document.duplicate(true)
	await c.drag(b.view,local_mm([2,-3]),local_mm([4,-5]))
	check("point_drag_without_select",b.document.points[id]==[4.0,-5.0] and b.document.points.size()==3)
	b.command("undo")
	check("point_drag_single_undo",b.document==prior)
	await hold_key(KEY_L,true)
	await hold_key(KEY_L,false)
	await c.drag(b.view,local_mm([-15,-10]),local_mm([-14,-12]))
	check("endpoint_drag_without_select",b.document.lines[0].a==[-14.0,-12.0] and b.document.lines.size()==1)
	b.command("undo")
	check("endpoint_drag_undo",b.document==prior)
	await click_mm([-15,-10])
	check("endpoint_can_start_new_line",b.pending==[-15.0,-10.0])
	await click_mm([-20,-15])
	check("endpoint_new_line_complete",b.document.lines.size()==2 and b.document.lines[1].a==[-15.0,-10.0])
	b.command("undo")
	check("connected_line_undo",b.document==prior)
	await hold_key(KEY_M,true)
	await hover_mm([-8,-6])
	await c.wheel(b.view,local_mm([-8,-6]),true)
	await hover_mm([-8,-6])
	check("held_m_scale_independent",b.canvas.last_measure_geometry.get("x_mm")==8.0 and b.canvas.last_measure_geometry.get("y_mm")==6.0)
	await hold_key(KEY_M,false)
	b.command("point")
	await double_mm([-10,12])
	await input_name("DMLP")
	check("naming_letters_do_not_trigger_shortcuts",b.point_label(first)=="DMLP" and b.tool=="point" and not b.measuring)
	await hold_key(KEY_L,true,true)
	await hold_key(KEY_L,false,true)
	check("modified_key_not_tool_shortcut",b.tool=="point")
	await hold_key(KEY_M,true)
	await hover_mm([5,7])
	await button(r.practice_shell.find_child("Teaching",true,false))
	await wait_demo()
	await hold_key(KEY_L,true)
	await hold_key(KEY_L,false)
	check("teaching_blocks_shortcuts_and_measure",r.points_demo.active and b.tool=="point" and not b.measuring)
	await button(r.points_demo.leave)
	await hold_key(KEY_M,false)
	check("guide_exit_moes_not_restore_hold",not b.measuring)
	check("redo_button_removed",not b.tools.has("redo") and b.toolbar.find_child("Tool_redo",true,false)==null)
	var properties = b.get_property_list().map(func(prop): return prop.name)
	check("redo_history_removed",not properties.has("redo_stack"))
	var intact = b.document.duplicate(true)
	b.command("point")
	await click_mm([8,5])
	await hold_key(KEY_D,true)
	await hold_key(KEY_D,false)
	check("d_deletes_selected_point",b.document.points.size()==2 and not b.document.points.has(second) and not b.measuring)
	await hold_key(KEY_Z,true,true)
	await hold_key(KEY_Z,false,true)
	check("ctrl_z_restores_deleted_point",b.document==intact)
	b.command("line")
	await click_mm([0,-10])
	await hold_key(KEY_D,true)
	await hold_key(KEY_D,false)
	check("d_deletes_selected_line",b.document.lines.is_empty() and b.document.points.size()==3)
	await hold_key(KEY_Z,true,true)
	await hold_key(KEY_Z,false,true)
	check("ctrl_z_restores_deleted_line",b.document==intact)
	await right_click([0,0])
	var undo_count = b.undo_stack.size()
	await hold_key(KEY_D,true)
	await hold_key(KEY_D,false)
	check("d_with_no_selection_no_change",b.document==intact and b.undo_stack.size()==undo_count)
	# Existing marquee path is exercised earlier; use its selection to check one undo.
	b.box_select(Canvas.at([-25,25]),Canvas.at([25,-25]))
	await hold_key(KEY_D,true)
	await hold_key(KEY_D,false)
	check("d_deletes_mixed_group",b.document.points.is_empty() and b.document.lines.is_empty())
	await hold_key(KEY_Z,true,true)
	await hold_key(KEY_Z,false,true)
	check("ctrl_z_group_one_transaction",b.document==intact)
	b.command("point")
	await double_mm([-10,12])
	await hold_key(KEY_D,true)
	await hold_key(KEY_D,false)
	await hold_key(KEY_Z,true,true)
	await hold_key(KEY_Z,false,true)
	check("dialog_blocks_delete_and_draft_undo",b.naming_dialog.visible and b.document==intact)
	b.close_naming()
	check("removed_redo_command_no_op",b.document==intact)
	b.save_draft()
	FileAccess.open("res://qa/point-naming-expected.json",FileAccess.WRITE).store_string(JSON.stringify(b.document,"\t"))
	await hold_key(KEY_M,true)
	await hover_mm([-9,14])
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/practice-held-m.png")
	await hold_key(KEY_M,false)
	finish("point-naming-check.json")



