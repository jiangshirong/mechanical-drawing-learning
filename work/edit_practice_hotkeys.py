from pathlib import Path
p=Path('机械制图学习/practice_board.gd');s=p.read_text(encoding='utf-8');s=s.replace('var point_name := ""','var point_name := ""\nvar measuring := false')
s=s.replace('[["选择","select"],["画线","line"],["标点","point"]','[["画线 (L)","line"],["标点 (P)","point"]')
s=s.replace('["select","line","point"]','["line","point"]')
s=s.replace('\t\tif key != "select": clear_selection()','\t\tview.cancel_drag()')
s=s.replace('\tupdate_tools()\n\nfunc update_tools()', '\tvisibility_changed.connect(func():\n\t\tif not is_visible_in_tree(): set_measuring(false))\n\tupdate_tools()\n\nfunc update_tools()',1)
a=s.index('func update_tools()');s=s[:a]+'''func set_measuring(value: bool) -> void:
\tmeasuring = value
\tif view: view.update_pointer()
\tif canvas: canvas.queue_redraw()

func _notification(what: int) -> void:
\tif what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_measuring(false)

func _input(event: InputEvent) -> void:
\tif not event is InputEventKey: return
\tvar key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
\t# A release always clears temporary measuring, even after leaving this page.
\tif key == KEY_D and not event.pressed:
\t\tset_measuring(false)
\t\treturn
\tif readonly or not is_visible_in_tree() or naming_dialog.visible: return
\tif get_viewport().gui_get_focus_owner() is LineEdit: return
\tif event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
\tif key == KEY_D:
\t\tif event.pressed: set_measuring(true)
\t\tget_viewport().set_input_as_handled()
\telif event.pressed and not event.echo and key in [KEY_L,KEY_P]:
\t\tcommand("line" if key == KEY_L else "point")
\t\tview.update_pointer()
\t\tget_viewport().set_input_as_handled()

'''+s[a:]
s=s.replace('\t\tclear_selection()\n\t\tvar q := snap(p,true)','\t\tif pending == null:\n\t\t\tvar existing := hit(p,false)\n\t\t\tif not existing.is_empty() and existing.kind == "line":\n\t\t\t\tchoose_hit(existing)\n\t\t\t\treturn\n\t\tclear_selection()\n\t\tvar q := snap(p,true)',1)
s=s.replace('and tool in ["line","point"] and marquee == null','and marquee == null')
s=s.replace('\tnaming_id = found.id','\tset_measuring(false)\n\tnaming_id = found.id')
p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/practice_canvas.gd');s=p.read_text(encoding='utf-8');a=s.index('\telif board.cursor != null:');z=s.index('func draw_measure',a);s=s[:a]+'''\telif board.measuring and not board.naming_dialog.visible:
\t\tif board.cursor != null: draw_measure(board.cursor)

'''+s[z:];s=s.replace('func draw_measure(p: Array,show_coordinate: bool)','func draw_measure(p: Array)');s=s.replace('"coordinate_visible":show_coordinate','"coordinate_visible":false');a=s.index('\tif not show_coordinate: return');z=s.index('func dashed',a);s=s[:a]+s[z:];p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/practice_view.gd');s=p.read_text(encoding='utf-8');s=s.replace('and board.tool == "select":','and board.pending == null:');s=s.replace('\t\t\t\tif edit_dragged: board.commit_drag(edit_snapshot)\n\t\t\t\tedit_hit = {}','\t\t\t\tif edit_dragged: board.commit_drag(edit_snapshot)\n\t\t\t\telif edit_hit.kind == "point": board.click_content((event.position-pan)/zoom)\n\t\t\t\tedit_hit = {}',1)
s=s.replace('\t\tif not edit_hit.is_empty():\n\t\t\tedit_dragged =','\t\tif not edit_hit.is_empty():\n\t\t\tlast_position = event.position\n\t\t\tpointer_inside = Rect2(Vector2.ZERO,size).has_point(event.position)\n\t\t\tupdate_pointer()\n\t\t\tedit_dragged =')
p.write_text(s,encoding='utf-8')
# Keep the latest naming checks aligned with the two remaining tools.
p=Path('机械制图学习/point_naming_check.gd');s=p.read_text(encoding='utf-8').replace('b.command("select")','b.command("line")');p.write_text(s,encoding='utf-8')
