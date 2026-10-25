from pathlib import Path
app=Path('机械制图学习')
p=app/'section_guide.gd';s=p.read_text(encoding='utf-8')
s=s.replace('const Stroke = preload("res://stroke_3d.gd")','const Stroke = preload("res://stroke_3d.gd")\nconst Focus = preload("res://guide_focus.gd")\nvar focus_materials: Array[ShaderMaterial] = []\nvar busy := false\nvar fullscreen_requested := false\nvar window_snapshot: Dictionary = {}\nvar free_parents: Array = []\nvar locked_controls: Array = []')
s=s.replace('\tr = root\n','\tr = root\n\tr.observer.resized.connect(on_stage_resized)\n',1)
s=s.replace('\tactive = true\n','\tactive = true\n\tbusy = true\n\tenter_presentation()\n',1)
s=s.replace('\tr.observer.picking_enabled = false','\tr.observer.picking_enabled = false\n\tr.observer.interaction_enabled = false\n\tr.observer.dragging = false',1)
s=s.replace('\tapply_visual(visual)\n\tupdate_lesson()\n\tr.schedule_save()','\tapply_visual(visual)\n\tupdate_lesson()\n\tawait r.get_tree().process_frame\n\tif not active: return\n\tapply_camera(camera_target())\n\tfinish_animation()\n\tr.schedule_save()',1)
s=s.replace('\t# Capture base alpha once;', '\tfocus_materials.clear()\n\tfor pair in [[complete,false],[removed,true],[r.observer.model,false],[r.observer.helpers,false]]:\n\t\tfocus_materials.append_array(Focus.install(pair[0],r.data,pair[1]))\n\t# Capture base alpha once;')
s=s.replace('\t\t\tmat.shader = Stroke.shader_for(color.a < 0.9999)','\t\t\tmat.shader = Focus.shader_for(color.a < 0.9999) if node.get_meta("guide_body",false) else Stroke.shader_for(color.a < 0.9999)')
a=s.index('func go_to(');b=s.index('\nfunc update_lesson()',a)
s=s[:a]+'''func go_to(target: int, animate := true) -> void:
\tif not active or busy: return
\tvar destination := clampi(target,0,r.data.guide.steps.size()-1)
\tif destination == current_step: return
\tcurrent_step = destination
\tstop_animation()
\tbusy = animate
\tupdate_lesson()
\tvar finish: Array = r.data.guide.steps[current_step].state
\tif animate:
\t\tvar start := visual.duplicate()
\t\tvar camera_start: Dictionary = r.observer.get_state()
\t\tawait r.get_tree().process_frame
\t\tif not active: return
\t\tanimation = r.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t\tanimation.tween_method(animate_frame.bind(start,finish,camera_start,camera_target()),0.0,1.0,1.5)
\t\tanimation.finished.connect(finish_animation)
\telse:
\t\tapply_visual(finish)
\t\tapply_camera(camera_target())
\t\tfinish_animation()
\tr.schedule_save()

func animate_frame(t: float, start: Array, finish: Array, camera_start: Dictionary, camera_finish: Dictionary) -> void:
\tblend(t,start,finish)
\tvar state := camera_start.duplicate(true)
\tfor key in ["yaw","pitch","zoom"]: state[key] = lerpf(camera_start[key],camera_finish[key],t)
\tfor i in range(3): state.target[i] = lerpf(camera_start.target[i],camera_finish.target[i],t)
\tapply_camera(state)

func finish_animation() -> void:
\tif not active: return
\tbusy = false
\tupdate_navigation()

func update_navigation() -> void:
\tr.guide_prev.disabled = busy or current_step == 0
\tr.guide_next.disabled = busy or current_step == r.data.guide.steps.size()-1
''' +s[b:]
s=s.replace('\tr.guide_prev.disabled = current_step == 0\n\tr.guide_next.disabled = current_step == r.data.guide.steps.size()-1','\tupdate_navigation()\n\tr.guide_paper.visible = bool(lesson.get("show_projection",current_step>=4))\n\tfor mat in focus_materials: mat.set_shader_parameter("focus_mode",current_step)\n\tr.observer.request_render()')
s=s.replace('\tr.paper.guide_rib = current_step == 5','\tr.paper.guide_rib = current_step == 5\n\tr.paper.guide_focus = str(lesson.get("focus",""))')
s=s.replace('\tactive = false\n','\tactive = false\n\tbusy = false\n\texit_presentation()\n',1)
s=s.replace('\tlabels.clear()','\tlabels.clear()\n\tfocus_materials.clear()',1)
s=s.replace('\tr.observer.picking_enabled = true','\tr.observer.picking_enabled = true\n\tr.observer.interaction_enabled = true',1)
s=s.replace('\tr.paper.guide_rib = false','\tr.paper.guide_rib = false\n\tr.paper.guide_focus = ""',1)
s+='''
func lock_free_controls(node: Node) -> void:
\tif node is BaseButton:
\t\tlocked_controls.append([node,node.disabled])
\t\tnode.disabled = true
\tfor child in node.get_children(): lock_free_controls(child)

func enter_presentation() -> void:
\twindow_snapshot = {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
\tfullscreen_requested = true
\t# Native fullscreen is suppressed in offscreen QA so tests cannot cover or
\t# focus the user's desktop. Production uses the actual fullscreen window mode.
\tif not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
\tr.source_window.hide()
\tr.chooser.get_popup().hide()
\tr.chooser.release_focus()
\tfree_parents = [[r.observer,r.observer.get_parent(),r.observer.get_index()],[r.paper,r.paper.get_parent(),r.paper.get_index()]]
\tr.observer.reparent(r.guide_space,false)
\tr.paper.reparent(r.guide_paper,false)
\tlocked_controls.clear()
\tlock_free_controls(r.free_shell)
\tr.free_shell.hide()
\tr.guide_shell.show()

func exit_presentation() -> void:
\tfor entry in free_parents:
\t\tentry[0].reparent(entry[1],false)
\t\tentry[1].move_child(entry[0],entry[2])
\tfree_parents.clear()
\tfor entry in locked_controls: entry[0].disabled = entry[1]
\tlocked_controls.clear()
\tr.guide_shell.hide()
\tr.free_shell.show()
\tif not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(window_snapshot.mode)
\tif window_snapshot.mode == DisplayServer.WINDOW_MODE_WINDOWED:
\t\tDisplayServer.window_set_size(window_snapshot.size)
\t\tDisplayServer.window_set_position(window_snapshot.position)
\tfullscreen_requested = false

func camera_target() -> Dictionary:
\tvar pose: Dictionary = r.data.guide.steps[current_step].camera
\tvar zoom := float(pose.zoom)
\tif not r.guide_paper.visible:
\t\t# Fit the part in short wide windows as well as tall fullscreen layouts.
\t\tzoom = maxf(zoom,0.21*float(r.observer.size.y)/maxf(r.observer.size.x,1))
\tvar target: Vector3 = r.observer.g(pose.target_mm)
\treturn {"yaw":float(pose.yaw),"pitch":float(pose.pitch),"zoom":zoom,"target":[target.x,target.y,target.z]}

func apply_camera(state: Dictionary) -> void:
\tr.observer.restore_state(state)

func on_stage_resized() -> void:
\tif active and not busy: apply_camera(camera_target())
'''
p.write_text(s,encoding='utf-8')
p=app/'paper.gd';s=p.read_text(encoding='utf-8');s=s.replace('var guide_rib := false','var guide_rib := false\nvar guide_focus := ""')
a=s.index('\nfunc hit_test(')
s=s[:a]+'''\tif not guide_focus.is_empty(): draw_guide_focus()

func dim_outside(region: Rect2) -> void:
\tvar clipped := region.intersection(Rect2(Vector2.ZERO,size))
\tvar dim := Color(0.03,0.06,0.09,0.64)
\tdraw_rect(Rect2(0,0,size.x,clipped.position.y),dim)
\tdraw_rect(Rect2(0,clipped.end.y,size.x,maxf(0,size.y-clipped.end.y)),dim)
\tdraw_rect(Rect2(0,clipped.position.y,clipped.position.x,clipped.size.y),dim)
\tdraw_rect(Rect2(clipped.end.x,clipped.position.y,maxf(0,size.x-clipped.end.x),clipped.size.y),dim)

func draw_guide_focus() -> void:
\tif guide_focus == "projection":
\t\tvar b: Array = data.bounds
\t\tvar a := screen(Vector2(b[0][0],b[2][1]),"front")-Vector2(12,35)
\t\tvar end := screen(Vector2(b[0][1],b[2][0]),"front")+Vector2(12,15)
\t\tdim_outside(Rect2(a,end-a))
\telif guide_focus == "rib":
\t\tvar points := PackedVector2Array()
\t\tfor p in data.section.rib_polygon: points.append(screen(Vector2(p[0],p[1]),"front"))
\t\tvar region := Rect2(points[0],Vector2.ZERO)
\t\tfor point in points: region = region.expand(point)
\t\tdim_outside(region.grow(14))
\t\tvar outline := points.duplicate()
\t\toutline.append(points[0])
\t\tdraw_polyline(outline,Color("bd7924"),2.4,true)
''' +s[a:]
p.write_text(s,encoding='utf-8')
p=app/'render_bench.gd';s=p.read_text(encoding='utf-8');s=s.replace('\tr.guide.enter()','\tawait r.guide.enter()');s=s.replace('\tr.guide.go_to(0,false)\n\tfor i in range(5)', '\twhile r.guide.busy: await r.get_tree().process_frame\n\tr.guide.go_to(0,false)\n\tfor i in range(5)');p.write_text(s,encoding='utf-8')
