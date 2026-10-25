from pathlib import Path
p=Path('机械制图学习/practice_board.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('var names: HBoxContainer','var naming_dialog: ConfirmationDialog\nvar naming_id := ""')
a=s.index('\tnames = HBoxContainer.new()'); z=s.index('\terror_label = Label.new()',a)
s=s[:a]+'''\tnaming_dialog = ConfirmationDialog.new()
\tnaming_dialog.title = "点名"
\tnaming_dialog.exclusive = true
\tnaming_dialog.dialog_hide_on_ok = false
\tnaming_dialog.ok_button_text = "确定"
\tnaming_dialog.cancel_button_text = "取消"
\tadd_child(naming_dialog)
\tvar form := VBoxContainer.new()
\tnaming_dialog.add_child(form)
\tname_field = LineEdit.new()
\tname_field.name = "PointName"
\tname_field.placeholder_text = "输入点名"
\tname_field.custom_minimum_size.x = 280
\tname_field.text_changed.connect(func(_value: String): name_error.hide())
\tname_field.text_submitted.connect(rename_selected_point)
\tform.add_child(name_field)
\tname_error = Label.new()
\tname_error.text = "点名已存在"
\tform.add_child(name_error)
\tname_error.hide()
\tnaming_dialog.confirmed.connect(func(): rename_selected_point(name_field.text))
\tnaming_dialog.canceled.connect(close_naming)
\tnaming_dialog.close_requested.connect(close_naming)
'''+s[z:]
s=s.replace('\t\tnames.hide()','')
s=s.replace('\tnames.visible = not readonly and (tool == "point" or (tool == "select" and selection.size() == 1 and selected.kind == "point"))\n','')
a=s.index('\telif tool == "point":',s.index('func click_content'));z=s.index('\telse:\n\t\tchoose_hit(hit(p,false))',a)
s=s[:a]+'''\telif tool == "point":
\t\tvar found := hit_point(p)
\t\tif not found.is_empty():
\t\t\tchoose_hit(found)
\t\telse:
\t\t\tvar before := document.duplicate(true)
\t\t\tvar id := "point-"+str(Time.get_ticks_usec())
\t\t\twhile document.points.has(id): id += "-new"
\t\t\tdocument.points[id] = snap(p)
\t\t\tif not document.has("point_labels"): document.point_labels = {}
\t\t\tdocument.point_labels[id] = ""
\t\t\tchoose_hit({"kind":"point","id":id,"end":""})
\t\t\tcommit_drag(before)
'''+s[z:]
s=s.replace('if item.kind == "point": document.points.erase(item.id)','if item.kind == "point":\n\t\t\t\tdocument.points.erase(item.id)\n\t\t\t\tif document.has("point_labels"): document.point_labels.erase(item.id)')
s=s.replace('\tvar had_preview: bool = pending != null','\tclose_naming()\n\tvar had_preview: bool = pending != null')
s=s.replace('\t\tif tool == "select":\n\t\t\tpoint_name = selected.id\n\t\t\tname_field.text = point_name\n','')
a=s.index('func rename_selected_point');z=s.index('func current_selection',a)
s=s[:a]+'''# IDs remain stable across naming, dragging, undo and persistence. Older saves
# without point_labels retain their original dictionary keys as display names.
func point_label(id: String) -> String:
\treturn document.get("point_labels",{}).get(id,id)

func hit_point(p: Vector2) -> Dictionary:
\tfor id in document.points:
\t\tif p.distance_to(Canvas.at(document.points[id])) <= 9.0/view.zoom:
\t\t\treturn {"kind":"point","id":id,"end":""}
\treturn {}

func open_naming(p: Vector2) -> void:
\tif readonly or tool != "point": return
\tvar found := hit_point(p)
\tif found.is_empty(): return
\tview.cancel_drag()
\tchoose_hit(found)
\tnaming_id = found.id
\tname_field.text = point_label(naming_id)
\tname_error.hide()
\tcursor = null
\tnaming_dialog.popup_centered(Vector2i(320,130))
\tname_field.grab_focus()
\tname_field.select_all()

func close_naming() -> void:
\tnaming_id = ""
\tif naming_dialog: naming_dialog.hide()

func deselect() -> void:
\tcancel_pending()
\tclear_selection()
\tmeasure = null
\tupdate_tools()

func rename_selected_point(value: String) -> void:
\tif readonly or naming_id.is_empty() or not document.points.has(naming_id): return
\tvar new_name := value.strip_edges()
\tif not new_name.is_empty() and not valid_name(new_name):
\t\tname_error.text = "点名不能包含控制字符"
\t\tname_error.show()
\t\treturn
\tfor id in document.points:
\t\tif id != naming_id and not new_name.is_empty() and point_label(id) == new_name:
\t\t\tname_error.text = "点名已存在"
\t\t\tname_error.show()
\t\t\treturn
\tvar before := document.duplicate(true)
\tif point_label(naming_id) != new_name:
\t\tif not document.has("point_labels"): document.point_labels = {}
\t\tdocument.point_labels[naming_id] = new_name
\tclose_naming()
\tcommit_drag(before)
\tcanvas.queue_redraw()

'''+s[z:]
s=s.replace('\treturn valid_pair(saved.view.get("center_mm"))','\tvar labels = saved.get("point_labels",{})\n\tif not labels is Dictionary: return false\n\tvar used_names: Dictionary = {}\n\tfor id in labels:\n\t\tif not saved.points.has(id) or not labels[id] is String or (not labels[id].is_empty() and not valid_name(labels[id])): return false\n\tfor id in saved.points:\n\t\tvar label: String = labels.get(id,id)\n\t\tif not label.is_empty():\n\t\t\tif used_names.has(label): return false\n\t\t\tused_names[label] = true\n\treturn valid_pair(saved.view.get("center_mm"))')
s=s.replace('\t\t\tdocument = {"lines":saved.lines,"points":saved.points}','\t\t\tdocument = {"lines":saved.lines,"points":saved.points}\n\t\t\tif saved.has("point_labels"): document.point_labels = saved.point_labels')
s=s.replace('\tvar file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)','\tif document.has("point_labels"): saved.point_labels = document.point_labels\n\tvar file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)')
p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/practice_canvas.gd');s=p.read_text(encoding='utf-8').replace('dot(at(board.document.points[key]),key)','dot(at(board.document.points[key]),board.point_label(key))');p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/practice_view.gd');s=p.read_text(encoding='utf-8').replace('var right_holding := false','var naming_release := false\nvar right_holding := false').replace('else: board.cancel_pending()','else: board.deselect()')
s=s.replace('\tif event is InputEventMouseButton:\n','''\tif event is InputEventMouseButton:
\t\tif event.button_index == MOUSE_BUTTON_LEFT:
\t\t\tif naming_release and not event.pressed:
\t\t\t\tnaming_release = false
\t\t\t\taccept_event()
\t\t\t\treturn
\t\t\tif event.pressed and event.double_click and board.tool == "point" and not right_holding:
\t\t\t\tboard.open_naming((event.position-pan)/zoom)
\t\t\t\tnaming_release = true
\t\t\t\taccept_event()
\t\t\t\treturn
''',1);p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/main.gd');s=p.read_text(encoding='utf-8');s=s.replace('"--qa-practice-tools-reopen"','"--qa-practice-tools-reopen","--qa-point-naming","--qa-point-naming-reopen"') if False else s
s=s.replace('\tfor flag in ["--qa-practice-tools",','''\tfor flag in ["--qa-point-naming","--qa-point-naming-reopen"]:
\t\tif flag in OS.get_cmdline_user_args():
\t\t\tawait load("res://point_naming_check.gd").new().run(self,flag)
\t\t\tpractice.save_draft()
\t\t\tsave_states()
\t\t\tget_tree().quit()
\t\t\treturn
\tfor flag in ["--qa-practice-tools",''',1)
s=s.replace('"--qa-practice-tools","--qa-practice-tools-reopen"]','"--qa-practice-tools","--qa-practice-tools-reopen","--qa-point-naming","--qa-point-naming-reopen"]',1)
s=s.replace('\tprint("LEARNING_READY', '\tif "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-point-naming-observation.json"\n\tprint("LEARNING_READY')
s=s.replace('\tif "--qa-practice-tools" in OS.get_cmdline_user_args() or "--qa-practice-tools-reopen" in OS.get_cmdline_user_args(): practice.save_path', '\tif "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): practice.save_path = "user://qa-point-naming.json"\n\tif "--qa-practice-tools" in OS.get_cmdline_user_args() or "--qa-practice-tools-reopen" in OS.get_cmdline_user_args(): practice.save_path')
# Set isolated observation save before any loading, rather than after initialization.
s=s.replace('\tif "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-point-naming-observation.json"\n','')
s=s.replace('\tvar starts_at_map :=', '\tif "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-point-naming-observation.json"\n\tvar starts_at_map :=')
# place before old load path logic at start
line='\tif "--qa-point-naming" in OS.get_cmdline_user_args() or "--qa-point-naming-reopen" in OS.get_cmdline_user_args(): save_path = "user://qa-point-naming-observation.json"\n'
s=s.replace(line,'');s=s.replace('\tif "--qa-points-check"',line+'\tif "--qa-points-check"',1)
p.write_text(s,encoding='utf-8')
