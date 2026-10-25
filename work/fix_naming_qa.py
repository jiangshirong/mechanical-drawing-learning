from pathlib import Path
p=Path('机械制图学习/point_naming_check.gd');s=p.read_text(encoding='utf-8');s=s.replace('\tb.name_field.grab_focus()\n\tawait h.wait_frames(3)','''\tvar pos = b.name_field.get_global_transform_with_canvas()*(b.name_field.size*0.5)
\tvar motion = InputEventMouseMotion.new()
\tmotion.position = pos
\tb.naming_dialog.push_input(motion,true)
\tfor pressed in [true,false]:
\t\tvar mouse = InputEventMouseButton.new()
\t\tmouse.position = pos
\t\tmouse.button_index = MOUSE_BUTTON_LEFT
\t\tmouse.pressed = pressed
\t\tb.naming_dialog.push_input(mouse,true)
\t\tawait h.wait_frames(2)
\tb.name_field.grab_focus()
\tawait h.wait_frames(3)''');p.write_text(s,encoding='utf-8')
