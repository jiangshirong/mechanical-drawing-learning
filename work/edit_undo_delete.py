from pathlib import Path
p=Path('机械制图学习/practice_board.gd');s=p.read_text(encoding='utf-8');s=s.replace('var redo_stack: Array = []\n','').replace('["撤销","undo"],["重做","redo"],["删除","delete"]','["撤销 (Ctrl+Z)","undo"],["删除 (D)","delete"]');s=s.replace('key == KEY_D and not event.pressed','key == KEY_M and not event.pressed');s=s.replace('\tif event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return\n\tif key == KEY_D:', '''\tif event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed and key == KEY_Z:
\t\tif event.pressed and not event.echo: command("undo")
\t\tget_viewport().set_input_as_handled()
\t\treturn
\tif event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
\tif key == KEY_M:''');s=s.replace('\telif event.pressed and not event.echo and key in [KEY_L,KEY_P]:','\telif event.pressed and not event.echo and key == KEY_D:\n\t\tcommand("delete")\n\t\tget_viewport().set_input_as_handled()\n\telif event.pressed and not event.echo and key in [KEY_L,KEY_P]:');s=s.replace('\ttools.redo.disabled = redo_stack.is_empty()\n','');s=s.replace('\tcancel_pending()\n\tif key in ["line","point"]:','\tif key not in ["line","point","undo","delete"]: return\n\tcancel_pending()\n\tview.cancel_drag()\n\tif key in ["line","point"]:').replace('\t\tview.cancel_drag()\n','')
a=s.index('\telif key == "undo" or key == "redo":');z=s.index('\telif key == "delete":',a);s=s[:a]+'''\telif key == "undo":
\t\tif not undo_stack.is_empty():
\t\t\tdocument = undo_stack.pop_back()
\t\t\tclear_selection()
\t\t\tmeasure = null
\t\t\tautosave()
'''+s[z:];s=s.replace('\tredo_stack.clear()\n','');p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/point_naming_check.gd');s=p.read_text(encoding='utf-8');s=s.replace('\tb.command("redo")\n\tcheck("redo_name",b.point_label(first)=="a\'\'")','\tawait double_mm([-10,12])\n\tawait input_name("a\'\'")\n\tcheck("rename_after_undo",b.point_label(first)=="a\'\'")');s=s.replace('KEY_D','KEY_M').replace('held_d','held_m').replace('d_release','m_release').replace('guide_exit_d','guide_exit_m').replace('practice-held-d.png','practice-held-m.png');s=s.replace('"DLP"','"DMLP"').replace('naming_letters_do_not_trigger_shortcuts','naming_letters_do_not_trigger_shortcuts');p.write_text(s,encoding='utf-8')
