from pathlib import Path

root=Path(__file__).resolve().parents[1]/'机械制图学习'
path=root/'points_presentation.gd'
old=path.read_text(encoding='utf-8')
if 'var current_beat :=' in old:
    raise SystemExit('Initial migration already applied; edit the runtime directly. Later fixes are preserved.')
tail=old[old.index('func node(parent: Node3D)'):]
tail=tail[:tail.index('func apply_concept(value: Vector3)')]
head='''extends MarginContainer
const Board = preload("res://practice_board.gd")
const Observer = preload("res://observer.gd")
const Stroke = preload("res://stroke_3d.gd")
const UI = preload("res://ui_style.gd")
const Callout = preload("res://points_callout.gd")
var r
var config: Dictionary
var active := false
var busy := false
var kind := "concept"
var phase := "idle"
var current_step := 0
var current_beat := 0
var steps: Array = []
var beats: Array = []
var before_states: Array = []
var after_states: Array = []
var state: Array = []
var tween: Tween
var previous: Button
var next: Button
var leave: Button
var heading: Label
var copy: Label
var stage: HBoxContainer
var space
var sheet
var overlay
var scene: Node3D
var planes: Array = []
var plane_materials: Array = []
var feet: Array = []
var rays: Array = []
var distance_notes: Array = []
var concept_value := Vector3.ZERO
var window_state: Dictionary = {}
var locked: Array = []
var builds := 0
var spatial_meshes: Array = []
var point_note: Label3D
var refs: Dictionary = {}
var substitutions: Dictionary = {}
var hint_progress := 0.0
var typing_clock := 0.0
var typing_schedule: Array[float] = []
var epoch := 0
var held_keys: Dictionary = {}

func _ready() -> void:
\tset_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
\tfor side in ["left","right","top","bottom"]: add_theme_constant_override("margin_"+side,22)
\tvar column := VBoxContainer.new()
\tadd_child(column)
\tstage = HBoxContainer.new()
\tstage.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tcolumn.add_child(stage)
\tspace = Observer.new()
\tspace.custom_minimum_size = Vector2(350,300)
\tspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tstage.add_child(space)
\tspace.interaction_enabled = false
\tspace.picking_enabled = false
\tsheet = Board.new()
\tsheet.readonly = true
\tstage.add_child(sheet)
\theading = Label.new()
\theading.add_theme_font_size_override("font_size",UI.CAPTION)
\theading.add_theme_color_override("font_color",UI.MUTED)
\tcolumn.add_child(heading)
\tvar row := HBoxContainer.new()
\tcolumn.add_child(row)
\tleave = r.btn("退出",exit)
\tleave.name = "PointsExit"
\trow.add_child(leave)
\tvar gap := Control.new()
\tgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\trow.add_child(gap)
\tprevious = r.btn("上一步",retreat)
\tprevious.name = "PointsPrevious"
\tnext = r.btn("下一步",advance)
\tnext.name = "PointsNext"
\tfor pair in [[previous,"A"],[next,"D"]]:
\t\tvar unit := HBoxContainer.new()
\t\tunit.add_theme_constant_override("separation",7)
\t\trow.add_child(unit)
\t\tunit.add_child(pair[0])
\t\tUI.teaching_navigation(pair[0])
\t\tvar key := Label.new()
\t\tkey.text = pair[1]
\t\tkey.add_theme_font_size_override("font_size",UI.CAPTION)
\t\tkey.add_theme_color_override("font_color",UI.MUTED)
\t\tunit.add_child(key)
\tfor b in [leave,previous,next]: b.focus_mode = Control.FOCUS_NONE
\toverlay = Callout.new()
\toverlay.demo = self
\tadd_child(overlay)
\tcopy = overlay.label
\tresized.connect(func(): if active: call_deferred("fit_paper"))
\thide()

func _process(delta: float) -> void:
\tif not active: return
\tif phase == "typing":
\t\ttyping_clock += delta
\t\twhile copy.visible_characters < typing_schedule.size() and typing_clock >= typing_schedule[copy.visible_characters]:
\t\t\tcopy.visible_characters += 1
\t\tif copy.visible_characters == typing_schedule.size() and typing_clock >= typing_schedule[-1]+punctuation_pause():
\t\t\tphase = "ready"
\t\t\tupdate_controls()
\toverlay.refresh()

func punctuation_pause() -> float:
\treturn float(config.presentation.punctuation_pause)

func lock(node: Node) -> void:
\tif node is BaseButton:
\t\tlocked.append([node,"disabled",node.disabled])
\t\tnode.disabled = true
\telif node is LineEdit:
\t\tlocked.append([node,"editable",node.editable])
\t\tnode.editable = false
\tfor child in node.get_children(): lock(child)

func enter(mode: String) -> void:
\tif active or r.data.id != config.chapter_id: return
\tr.practice.cancel_pending()
\tr.practice.view.cancel_drag()
\tr.practice.save_draft()
\tr.remember_current()
\tr.hide_source()
\tactive = true
\tkind = mode
\tepoch += 1
\theld_keys.clear()
\tsteps = config.concept if kind == "concept" else config.solution
\tbeats.clear()
\tfor i in range(steps.size()):
\t\tfor original in steps[i].beats:
\t\t\tvar b: Dictionary = original.duplicate(true)
\t\t\tb.group = i
\t\t\tbeats.append(b)
\tresolve_parameters()
\tcurrent_beat = 0
\tif kind == "concept":
\t\tfor i in range(beats.size()):
\t\t\tif beats[i].id == r.points_step_id or steps[beats[i].group].id == r.points_step_id:
\t\t\t\tcurrent_beat = i
\t\t\t\tbreak
\tlocked.clear()
\tlock(r.free_shell)
\tlock(r.practice_shell)
\tr.free_shell.hide()
\tr.practice_shell.hide()
\tr.observer.interaction_enabled = false
\tr.paper.picking_enabled = false
\tvar focus := get_viewport().gui_get_focus_owner()
\tif focus: focus.release_focus()
\twindow_state = {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
\tif not "--qa" in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
\tshow()
\tspace.visible = kind == "concept"
\tif kind == "concept" and not is_instance_valid(scene): build_concept()
\tcompile_states()
\tsheet.canvas.concept_focus = false
\tsheet.canvas.primitives = solution_primitives() if kind == "solution" else concept_primitives()
\tprepare_beat()

func resolve_parameters() -> void:
\trefs = {"O":[0.0,0.0]}
\tsubstitutions.clear()
\tfor key in ["A","B"]:
\t\tvar p: Array = r.data.parameters.points_mm[key]
\t\trefs[key+"_front"] = [p[0],p[2]]
\t\trefs[key+"_top"] = [p[0],p[1]]
\t\trefs[key+"_left"] = [-float(p[1]),p[2]]
\t\trefs[key+"_x"] = [p[0],0.0]
\t\trefs[key+"_top_axis"] = [0.0,p[1]]
\t\trefs[key+"_side_axis"] = [-float(p[1]),0.0]
\t\trefs[key+"_height"] = [0.0,p[2]]
\t\trefs[key+"_turn"] = [-float(p[1]),p[1]]
\t\trefs[key+"_depth0"] = [0.0,0.0]
\t\tsubstitutions[key+"_x"] = str(int(absf(p[0])))
\t\tsubstitutions[key+"_y"] = str(int(absf(p[1])))
\t\tsubstitutions[key+"_z"] = str(int(p[2]))
\tvar a: Array = r.data.parameters.points_mm.A
\tvar b: Array = r.data.parameters.points_mm.B
\tsubstitutions.dx = str(int(absf(b[0]-a[0])))
\tsubstitutions.dy = str(int(absf(b[1]-a[1])))
\tsubstitutions.dz = str(int(absf(b[2]-a[2])))

func projection(key: String,view: String) -> Array:
\treturn refs[key+"_"+("left" if view=="left" else "top" if view=="top" else "front")]

func solution_primitives() -> Array:
\tvar result: Array = []
\tfor i in range(beats.size()):
\t\tvar action: Dictionary = beats[i].action
\t\tif action.type == "line":
\t\t\tresult.append({"kind":"line","a":refs[action.a],"b":refs[action.b],"step":i,"order":result.size()})
\t\telif action.type == "point":
\t\t\tresult.append({"kind":"point","p":refs[action.p],"name":action.name,"step":i,"order":result.size()})
\treturn result

func concept_primitives() -> Array:
\tvar result: Array = []
\tfor group in config.solution:
\t\tif group.id not in ["a-front","a-top","a-side"]: continue
\t\tfor b in group.beats:
\t\t\tvar a: Dictionary = b.action
\t\t\tif a.type == "line": result.append({"kind":"line","a":refs[a.a],"b":refs[a.b],"step":-1,"order":result.size()})
\t\t\telif a.type == "point": result.append({"kind":"point","p":refs[a.p],"name":a.name,"step":-1,"order":result.size()})
\treturn result

func compile_states() -> void:
\tbefore_states.clear()
\tafter_states.clear()
\tvar s: Array = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
\tfor b in beats:
\t\tbefore_states.append(s.duplicate())
\t\tvar a: Dictionary = b.action
\t\tvar plane_index := ["V","H","W"].find(a.get("plane",""))
\t\tif a.type == "ray": s[plane_index] = 1.0
\t\telif a.type == "foot": s[plane_index+3] = 1.0
\t\telif a.type == "unfold": s[6 if a.plane == "H" else 7] = 1.0
\t\telif a.type in ["line","point"]: s[8] += 1.0
\t\tafter_states.append(s.duplicate())

func prepare_beat() -> void:
\tif tween and tween.is_valid(): tween.kill()
\tepoch += 1
\tvar b: Dictionary = beats[current_beat]
\tcurrent_step = int(b.group)
\thint_progress = 0.0
\tsheet.visible = kind == "solution" or b.get("show_sheet",false)
\tapply_state(before_states[current_beat])
\tsheet.canvas.focused_step = current_beat
\theading.text = "%d / %d · %s" % [current_step+1,steps.size(),steps[current_step].title]
\tif kind == "concept":
\t\tr.points_step_id = b.id
\t\tr.schedule_save()
\toverlay.set_copy(str(b.text).format(substitutions))
\ttyping_clock = 0.0
\ttyping_schedule.clear()
\tvar at := 0.0
\tfor ch in copy.text:
\t\tat += 1.0/float(config.presentation.characters_per_second)
\t\ttyping_schedule.append(at)
\t\tif ch in "，。；：！？": at += punctuation_pause()
\tphase = "typing"
\tupdate_controls()
\tcall_deferred("fit_paper")

func fit_paper() -> void:
\tvar captured := epoch
\tawait get_tree().process_frame
\tif not active or captured != epoch: return
\tif sheet.visible: sheet.view.fit_content()
\toverlay.geometry_key.clear()
\toverlay.refresh()

func update_controls() -> void:
\tbusy = phase in ["typing","playing"]
\tprevious.disabled = busy or current_beat == 0
\tnext.disabled = busy or phase == "complete"

func advance() -> void:
\tif not active or busy or phase == "complete": return
\tif phase == "ready": play_action()
\telif phase == "settled":
\t\tcurrent_beat += 1
\t\tprepare_beat()

func retreat() -> void:
\tif not active or busy or current_beat == 0: return
\tcurrent_beat -= 1
\tprepare_beat()

func handle_key(event: InputEventKey) -> void:
\tvar code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
\tif code not in [KEY_A,KEY_D]: return
\tif not event.pressed:
\t\theld_keys.erase(code)
\t\treturn
\tif event.echo or held_keys.has(code): return
\theld_keys[code] = true
\tif event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed: return
\tif code == KEY_A: retreat()
\telse: advance()

func play_action() -> void:
\tphase = "playing"
\tupdate_controls()
\tvar captured := epoch
\tvar start: Array = before_states[current_beat]
\tvar goal: Array = after_states[current_beat]
\tvar duration := 1.4 if beats[current_beat].action.type == "unfold" else 0.9
\ttween = create_tween()
\ttween.tween_method(func(amount: float):
\t\tif not active or captured != epoch: return
\t\thint_progress = amount
\t\tvar value: Array = []
\t\tfor i in range(start.size()): value.append(lerpf(float(start[i]),float(goal[i]),amount))
\t\tapply_state(value)
\t,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\ttween.finished.connect(func():
\t\tif not active or captured != epoch: return
\t\tapply_state(goal)
\t\tphase = "complete" if current_beat == beats.size()-1 else "settled"
\t\tupdate_controls())

func apply_state(value: Array) -> void:
\tstate = value.duplicate()
\tif kind == "solution":
\t\tsheet.canvas.progress = float(value[8])
\telse:
\t\tsheet.canvas.progress = sheet.canvas.primitives.size() if sheet.visible else 0
\t\tif is_instance_valid(scene):
\t\t\tplanes[1].rotation.x = float(value[6])*PI/2
\t\t\tplanes[2].rotation.y = float(value[7])*PI/2
\t\t\tvar u := (float(value[6])+float(value[7]))/2
\t\t\tconcept_value = Vector3(float(value[0]),float(value[3]),u)
\t\t\tfor mesh in spatial_meshes: mesh.visible = u < 0.8
\t\t\tpoint_note.visible = u < 0.8
\t\t\tfor i in range(3):
\t\t\t\tfeet[i].scale = Vector3.ONE*maxf(.001,float(value[i+3]))
\t\t\t\tfeet[i].visible = float(value[i+3]) > .001
\t\t\t\trays[i].scale = Vector3.ONE*maxf(.001,float(value[i])*(1-u))
\t\t\t\trays[i].visible = float(value[i]) > .001 and u < .999
\t\t\t\tdistance_notes[i].hide()
\t\t\t\tvar focused: bool = ["V","H","W"][i] in beats[current_beat].focus
\t\t\t\tplane_materials[i].albedo_color = Color("7593a5",.30) if focused else Color("567181",.17)
\t\t\tspace.yaw = lerpf(-.48,0,u)
\t\t\tspace.pitch = lerpf(.38,0,u)
\t\t\tspace.zoom = lerpf(.064,.070,u)
\t\t\tspace.update_camera()
\tsheet.canvas.queue_redraw()

func world_anchor(ref: String) -> Vector3:
\tvar a: Array = r.data.parameters.points_mm.A
\tif ref == "A": return space.g(a)
\tvar i := ["V","H","W"].find(ref)
\tif i >= 0:
\t\tvar centers: Array = [[-14,0,14],[-14,-14,0],[0,-14,14]]
\t\treturn planes[i].to_global(space.g(centers[i]))
\tif ref.begins_with("foot_"):
\t\treturn feet[["V","H","W"].find(ref.substr(5))].global_position
\tif ref == "H_origin": return planes[1].to_global(space.g([a[0],0,0]))
\tif ref == "W_origin": return planes[2].to_global(space.g([0,0,a[2]]))
\treturn Vector3.ZERO

func screen_anchor(ref: String,paper: bool) -> Vector2:
\tif paper:
\t\tvar p: Array = refs.get(ref,[0.0,0.0])
\t\treturn sheet.canvas.get_global_transform_with_canvas()*preload("res://practice_canvas.gd").at(p)
\tvar p := space.camera.unproject_position(world_anchor(ref))
\treturn space.global_position+p*space.size/Vector2(space.viewport.size)

func screen_plane(ref: String) -> Array[Vector2]:
\tvar result: Array[Vector2] = []
\tvar i := ["V","H","W"].find(ref)
\tvar quads: Array = [
\t\t[[-28,0,0],[0,0,0],[0,0,28],[-28,0,28]],
\t\t[[-28,-28,0],[0,-28,0],[0,0,0],[-28,0,0]],
\t\t[[0,0,0],[0,-28,0],[0,-28,28],[0,0,28]]]
\tfor q in quads[i]:
\t\tvar p := space.camera.unproject_position(planes[i].to_global(space.g(q)))
\t\tresult.append(space.global_position+p*space.size/Vector2(space.viewport.size))
\treturn result

func distance_caption(names: Array,paper: bool) -> String:
\tif names.size()<2: return ""
\tvar distance := 0.0
\tif paper:
\t\tvar a: Array = refs.get(names[0],[0,0])
\t\tvar b: Array = refs.get(names[1],[0,0])
\t\tdistance = Vector2(float(a[0]),float(a[1])).distance_to(Vector2(float(b[0]),float(b[1])))
\telse: distance = world_anchor(names[0]).distance_to(world_anchor(names[1]))*1000
\treturn "%d mm" % roundi(distance)

func protected_rects(paper: bool,offset: Vector2) -> Array[Rect2]:
\tvar result: Array[Rect2] = []
\tif paper:
\t\tfor item in sheet.canvas.primitives:
\t\t\tif item.kind != "point" or sheet.canvas.progress <= float(item.order): continue
\t\t\tvar p: Vector2 = sheet.canvas.get_global_transform_with_canvas()*preload("res://practice_canvas.gd").at(item.p)-offset
\t\t\tresult.append(Rect2(p-Vector2(14,30),Vector2(52,46)))
\t\tfor name in ["O","A_x","B_x","A_height","B_height","A_top_axis","B_top_axis","A_side_axis","B_side_axis"]:
\t\t\tvar p := screen_anchor(name,true)-offset
\t\t\tresult.append(Rect2(p-Vector2(16,16),Vector2(32,32)))
\telse:
\t\tfor name in ["A","foot_V","foot_H","foot_W","V","H","W"]:
\t\t\tvar p := screen_anchor(name,false)-offset
\t\t\tresult.append(Rect2(p-Vector2(12,28),Vector2(55,40)))
\treturn result

func exit() -> void:
\tif not active: return
\tepoch += 1
\tif tween and tween.is_valid(): tween.kill()
\tactive = false
\tphase = "idle"
\tbusy = false
\theld_keys.clear()
\toverlay.geometry_key.clear()
\thide()
\tfor entry in locked: entry[0].set(entry[1],entry[2])
\tlocked.clear()
\tif not "--qa" in OS.get_cmdline_user_args():
\t\tDisplayServer.window_set_mode(window_state.mode)
\t\tif window_state.mode == DisplayServer.WINDOW_MODE_WINDOWED:
\t\t\tDisplayServer.window_set_size(window_state.size)
\t\t\tDisplayServer.window_set_position(window_state.position)
\tr.observer.interaction_enabled = true
\tr.paper.picking_enabled = true
\tr.apply_points_mode()
\tr.observer.request_render()
\tr.schedule_save()

'''
path.write_text(head+tail,encoding='utf-8')
style=root/'ui_style.gd'
text=style.read_text(encoding='utf-8')
if 'func teaching_navigation' not in text:
    text+='''
static func teaching_navigation(button: Button) -> void:
\tfor role in ["normal","hover","pressed","disabled"]:
\t\tvar color: String = {"normal":"d4dde2","hover":"e2e8ec","pressed":"bbc9d2","disabled":"87939c"}[role]
\t\tvar style := card(color,color,6,0)
\t\tstyle.content_margin_left = 14
\t\tstyle.content_margin_right = 14
\t\tstyle.content_margin_top = 8
\t\tstyle.content_margin_bottom = 8
\t\tbutton.add_theme_stylebox_override(role,style)
\tfor role in ["font_color","font_hover_color","font_pressed_color"]:
\t\tbutton.add_theme_color_override(role,Color("344b59"))
\tbutton.add_theme_color_override("font_disabled_color",Color("495d6a"))
'''
style.write_text(text,encoding='utf-8')
main=root/'main.gd'
text=main.read_text(encoding='utf-8')
text=text.replace('if presentation_active() and event is InputEventKey:\n\t\tget_viewport().set_input_as_handled()', 'if presentation_active() and event is InputEventKey:\n\t\tif points_demo.active: points_demo.handle_key(event)\n\t\tget_viewport().set_input_as_handled()')
main.write_text(text,encoding='utf-8')
canvas=root/'practice_canvas.gd'
text=canvas.read_text(encoding='utf-8')
text=text.replace('var color := ACTIVE if focus else Color("728694")','var color := INK')
text=text.replace('INK if focus else Color("728694")','INK')
canvas.write_text(text,encoding='utf-8')
print('Updated lesson controller, isolated overlay, navigation style and input routing')
