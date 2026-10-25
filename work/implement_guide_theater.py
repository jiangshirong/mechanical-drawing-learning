from pathlib import Path
import json
app=Path('机械制图学习')
p=app/'main.gd';s=p.read_text(encoding='utf-8');s=s.replace('var guide_next: Button','var guide_next: Button\nvar free_shell: MarginContainer\nvar guide_shell: MarginContainer\nvar guide_stage: HBoxContainer\nvar guide_space: VBoxContainer\nvar guide_paper: VBoxContainer')
s=s.replace('\tvar margin := MarginContainer.new()\n\tmargin.set_anchors', '\tvar margin := MarginContainer.new()\n\tfree_shell = margin\n\tmargin.set_anchors',1)
s=s.replace('func(): observer.standard_view(key)','func(): if not guide or not guide.active: observer.standard_view(key)')
a=s.index('\tguide_panel = VBoxContainer.new()',s.index('func build_ui()'));b=s.index('\tbuild_source_window()',a)
s=s[:a]+'''\tguide_shell = MarginContainer.new()
\tguide_shell.name = "GuideShell"
\tguide_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
\tfor side in ["left","right","top","bottom"]: guide_shell.add_theme_constant_override("margin_"+side,22)
\tadd_child(guide_shell)
\tguide_shell.hide()
\tvar lesson := VBoxContainer.new()
\tguide_shell.add_child(lesson)
\tguide_stage = HBoxContainer.new()
\tguide_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tlesson.add_child(guide_stage)
\tguide_space = VBoxContainer.new()
\tguide_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tguide_space.size_flags_stretch_ratio = 1.0
\tguide_stage.add_child(guide_space)
\tguide_paper = VBoxContainer.new()
\tguide_paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tguide_paper.size_flags_stretch_ratio = 1.0
\tguide_stage.add_child(guide_paper)
\tguide_panel = VBoxContainer.new()
\tguide_panel.name = "GuidePanel"
\tguide_panel.visible = false
\tlesson.add_child(guide_panel)
\tguide_heading = label("",20)
\tguide_panel.add_child(guide_heading)
\tguide_copy = label("",18)
\tguide_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tguide_copy.custom_minimum_size.y = 56
\tguide_panel.add_child(guide_copy)
\tvar navigation := HBoxContainer.new()
\tguide_panel.add_child(navigation)
\tvar leave := btn("退出",func(): guide.exit())
\tleave.name = "GuideExit"
\tnavigation.add_child(leave)
\tguide_prev = btn("上一步",func(): guide.go_to(guide.current_step-1))
\tguide_prev.name = "GuidePrevious"
\tnavigation.add_child(guide_prev)
\tguide_next = btn("下一步",func(): guide.go_to(guide.current_step+1))
\tguide_next.name = "GuideNext"
\tnavigation.add_child(guide_next)
\tfor control in [leave,guide_prev,guide_next]: control.focus_mode = Control.FOCUS_NONE
''' +s[b:]
s=s.replace('func show_source(mode: String) -> void:\n','func show_source(mode: String) -> void:\n\tif guide and guide.active: return\n')
s=s.replace('\tif guide and guide.active: guide.exit()\n\tif store', '\tif guide and guide.active: return\n\tif store')
s=s.replace('func _notification(what: int) -> void:', 'func _input(event: InputEvent) -> void:\n\tif guide and guide.active and event is InputEventKey:\n\t\tget_viewport().set_input_as_handled()\n\nfunc _notification(what: int) -> void:')
p.write_text(s,encoding='utf-8')
p=app/'observer.gd';s=p.read_text(encoding='utf-8');s=s.replace('var picking_enabled := true','var picking_enabled := true\nvar interaction_enabled := true');s=s.replace('func _gui_input(event: InputEvent) -> void:\n','func _gui_input(event: InputEvent) -> void:\n\tif not interaction_enabled:\n\t\taccept_event()\n\t\treturn\n');p.write_text(s,encoding='utf-8')
p=app/'模型/section_guide.json';d=json.loads(p.read_text(encoding='utf-8'));d['version']=2;d['presentation']={'fullscreen':True,'controls':['exit','previous','next'],'lock_navigation_during_animation':True,'projection_from_step':'project_section'}
poses=[(-.48,.38,.14),(-.55,.18,.17),(-.6,.32,.24),(-.40,.22,.15),(-.6,.25,.24),(-1.05,.32,.20)]
for i,(step,pose) in enumerate(zip(d['steps'],poses)):
 step['show_projection']=i>=4
 step['focus']=['whole','cut_plane','removed','material','projection','rib'][i]
 step['camera']={'yaw':pose[0],'pitch':pose[1],'zoom':pose[2],'target_mm':[5,0,32.5]}
p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
