from pathlib import Path
app=Path('机械制图学习')
p=app/'observer.gd';s=p.read_text(encoding='utf-8')
s=s.replace('signal observation_changed','signal observation_changed\nconst Stroke = preload("res://stroke_3d.gd")\nvar helper_key: Array = []\nvar point_marker: MeshInstance3D\nvar helper_builds := 0')
s=s.replace('viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS','viewport.render_target_update_mode = SubViewport.UPDATE_ONCE\n\tviewport.msaa_3d = Viewport.MSAA_4X\n\tresized.connect(request_render)')
s=s.replace('camera.near = 0.001','camera.near = 0.05').replace('camera.far = 5','camera.far = 1.2')
s=s.replace('\tclear_branch(helpers)\n\tdata = d','\tclear_branch(helpers)\n\thelper_key.clear()\n\tdata = d')
s=s.replace('ResourceLoader.CACHE_MODE_REPLACE_DEEP','ResourceLoader.CACHE_MODE_REUSE')
s=s.replace('func update_camera() -> void:','func request_render() -> void:\n\tif is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE\n\nfunc update_camera() -> void:')
s=s.replace('\tcamera.look_at(target, Vector3.UP)','\tcamera.look_at(target, Vector3.UP)\n\trequest_render()')
a=s.index('\tvar mesh := ImmediateMesh.new()',s.index('func add_lines('));b=s.index('\nfunc plane_quad',a)
s=s[:a]+'\thelpers.add_child(Stroke.make(lines,color))\n'+s[b:]
s=s.replace('func refresh_helpers() -> void:\n\tclear_branch(helpers)','func refresh_helpers() -> void:\n\tupdate_marker()\n\tvar key := [data.get("id",""),data.get("section_active",false),auxiliary,projections,unfold]\n\tif key == helper_key and is_instance_valid(helpers): return\n\thelper_key = key\n\thelper_builds += 1\n\trequest_render()\n\tclear_branch(helpers)')
a=s.index('\tif not picked_world.is_empty():',s.index('func refresh_helpers'));b=s.index('\nfunc _process(',a)
s=s[:a]+'''\nfunc update_marker() -> void:
\tif not is_instance_valid(point_marker):
\t\tpoint_marker = MeshInstance3D.new()
\t\tvar sm := SphereMesh.new()
\t\tsm.radius = 0.0012
\t\tsm.height = 0.0024
\t\tpoint_marker.mesh = sm
\t\tvar marker_material := material(Color("ffb66b"))
\t\tmarker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
\t\tmarker_material.no_depth_test = true
\t\tmarker_material.render_priority = 127
\t\tpoint_marker.material_override = marker_material
\t\tworld.add_child(point_marker)
\tpoint_marker.visible = not picked_world.is_empty()
\tif point_marker.visible: point_marker.position = g(picked_world)
\trequest_render()
''' +s[b:]
p.write_text(s,encoding='utf-8')
p=app/'section_guide.gd';s=p.read_text(encoding='utf-8')
s=s.replace('var labels: Array[Label3D] = []','var labels: Array[Label3D] = []\nvar label_scale_key := Vector2.ZERO\nvar last_visual: Array = []\nconst Stroke = preload("res://stroke_3d.gd")')
a=s.index('\tvar mesh := ImmediateMesh.new()',s.index('func lines('));b=s.index('\nfunc note(',a)
s=s[:a]+'\tparent.add_child(Stroke.make(pairs,color))\n'+s[b:]
s=s.replace('func build_scene() -> void:\n','func build_scene() -> void:\n\tlabel_scale_key = Vector2.ZERO\n\tlast_visual.clear()\n')
s=s.replace('\t# Keep teaching labels readable while the orthographic camera is freely zoomed.','\tvar key := Vector2(r.observer.zoom,r.observer.viewport.size.y)\n\tif key == label_scale_key: return\n\tlabel_scale_key = key\n\tr.observer.request_render()\n\t# Keep teaching labels readable while the orthographic camera is freely zoomed.')
a=s.index('func capture_alpha(');b=s.index('\nfunc apply_visual(',a)
s=s[:a]+'''func capture_alpha(node: Node) -> void:
\tif node is MeshInstance3D and node.material_override:
\t\tvar mat = node.material_override
\t\tvar color: Color = mat.get_shader_parameter("line_color") if mat is ShaderMaterial else mat.albedo_color
\t\tnode.set_meta("base_alpha",color.a)
\tif node is Label3D: node.set_meta("base_alpha",node.modulate.a)
\tfor child in node.get_children(): capture_alpha(child)

func opacity(node: Node, amount: float) -> void:
\tif node is MeshInstance3D and node.material_override:
\t\tvar mat = node.material_override
\t\tvar color: Color = mat.get_shader_parameter("line_color") if mat is ShaderMaterial else mat.albedo_color
\t\tcolor.a = float(node.get_meta("base_alpha",1.0))*amount
\t\tif mat is ShaderMaterial:
\t\t\tmat.shader = Stroke.shader_for(color.a < 0.9999)
\t\t\tmat.set_shader_parameter("line_color",color)
\t\telse:
\t\t\tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.9999 else BaseMaterial3D.TRANSPARENCY_DISABLED
\t\t\tmat.albedo_color = color
\tif node is Label3D:
\t\tnode.modulate.a = float(node.get_meta("base_alpha",1.0))*amount
\tfor child in node.get_children(): opacity(child,amount)
''' +s[b:]
s=s.replace('func apply_visual(values: Array) -> void:\n\tvisual = values.duplicate()','func apply_visual(values: Array) -> void:\n\tif values == last_visual: return\n\tvar previous := last_visual\n\tlast_visual = values.duplicate()\n\tvisual = values.duplicate()\n\tr.observer.request_render()')
s=s.replace('\topacity(removed,clampf((1.0-split)/0.20,0.0,1.0))','\tif previous.is_empty() or previous[0] != values[0]: opacity(removed,clampf((1.0-split)/0.20,0.0,1.0))')
s=s.replace('\t\topacity(nodes[i],float(values[i+1]))','\t\tif previous.is_empty() or previous[i+1] != values[i+1]: opacity(nodes[i],float(values[i+1]))')
s=s.replace('\tr.paper.guide_rib = float(values[4]) > 0.5\n\tr.paper.queue_redraw()','\tvar show_rib := float(values[4]) > 0.5\n\tif r.paper.guide_rib != show_rib:\n\t\tr.paper.guide_rib = show_rib\n\t\tr.paper.queue_redraw()')
p.write_text(s,encoding='utf-8')
p=app/'main.gd';s=p.read_text(encoding='utf-8');s=s.replace('func _ready() -> void:\n','func _ready() -> void:\n\tOS.low_processor_usage_mode = true\n\tOS.low_processor_usage_mode_sleep_usec = 8000\n',1);p.write_text(s,encoding='utf-8')
