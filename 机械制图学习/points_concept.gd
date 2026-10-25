extends RefCounted
# Knowledge-only examples reuse the same observation meshes and projection nodes.
const UI = preload("res://ui_style.gd")
const Stroke = preload("res://stroke_3d.gd")
var d
var mesh_bases: Array = []
var b_feet: Array = []
var b_rays: Array = []
var a_labels: Array = []
var b_labels: Array = []
var b_note: Label3D
var y_h: Label3D
var y_w: Label3D
var label_bases: Array = []

func highlight_labels(targets: Array) -> void:
	for item in label_bases:
		var selected: bool = item.key in targets
		item.label.font_size = roundi(item.font_size*d.emphasis_scale()) if selected else item.font_size
		item.label.modulate = Color("e99c56") if selected else item.color

func initial_state() -> Array:
	var value: Array = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	value.append_array(d.r.data.parameters.points_mm.A)
	value.append_array(d.r.data.parameters.points_mm.B)
	value.append(0.0)
	return value

func position(value: Array,key: String) -> Array:
	return value.slice(9,12) if key=="A" else value.slice(12,15)

func resolve_pose(spec: Array) -> Array:
	var result: Array = []
	for component in spec:
		if component is String:
			var token: String = component
			var shift := 0.0
			if token.begins_with("shift:"):
				var parts := token.split(":")
				shift = float(parts[2])
				token = parts[1]
			var split := token.split(".")
			result.append(float(d.r.data.parameters.points_mm[split[0]][["x","y","z"].find(split[1])])+shift)
		else: result.append(float(component))
	return result

func put_pose(value: Array,key: String,pose: Array) -> void:
	var start := 9 if key=="A" else 12
	for i in range(3): value[start+i] = float(pose[i])

func setup_state(value: Array,settings: Dictionary) -> void:
	for key in ["A","B"]:
		if settings.has(key): put_pose(value,key,resolve_pose(settings[key]))
	if settings.has("unfolded"):
		for i in range(6): value[i] = 1.0
		value[6] = 1.0 if settings.unfolded else 0.0
		value[7] = value[6]
	if settings.has("B_visible"): value[15] = 1.0 if settings.B_visible else 0.0

func update_refs(value: Array) -> void:
	for key in ["A","B"]:
		var p: Array = position(value,key)
		for prefix in [key]:
			d.refs[prefix+"_front"] = [p[0],p[2]]
			d.refs[prefix+"_top"] = [p[0],p[1]]
			d.refs[prefix+"_left"] = [-float(p[1]),p[2]]
			d.refs[prefix+"_x"] = [p[0],0.0]
			d.refs[prefix+"_height"] = [0.0,p[2]]
			d.refs[prefix+"_top_axis"] = [0.0,p[1]]
			d.refs[prefix+"_side_axis"] = [-float(p[1]),0.0]
			d.refs[prefix+"_turn"] = [-float(p[1]),p[1]]

func paper_primitives() -> Array:
	var beat: Dictionary = d.beats[d.current_beat]
	var scene: String = beat.get("scene","")
	var names: Array = beat.get("example_names",["A","B"])
	var result: Array = []
	for key in ["A","B"]:
		if key=="B" and float(d.state[15])<.001: continue
		var prefix: String = names[0 if key=="A" else 1].to_lower()
		for view in beat.get("known",["front","top","left"]):
			var label: String = prefix+{"front":"′","top":"","left":"″"}[view]
			var point: Array = d.refs[key+"_"+view]
			var same: Array = result.filter(func(item):return item.kind=="point" and Vector2(item.p[0],item.p[1]).is_equal_approx(Vector2(point[0],point[1])))
			if not same.is_empty():
				var item: Dictionary = same[0]
				item.name += "/"+label
			else: result.append({"kind":"point","p":point,"name":label,"view":view,"order":-1,"step":-1})
	var order := 0
	for b in d.beats:
		if b.get("scene","")!=scene: continue
		var a: Dictionary = b.action
		if a.type=="line":
			result.append({"kind":"line","a":d.refs[a.a],"b":d.refs[a.b],"dashed":true,"order":order,"step":d.beats.find(b),"id":b.id})
			order += 1
		elif a.type=="point":
			result.append({"kind":"point","p":d.refs[a.p],"name":a.name,"order":order,"step":d.beats.find(b)})
			order += 1
	return result

func build() -> void:
	for mesh in d.spatial_meshes:
		mesh_bases.append({"mesh":mesh,"position":mesh.global_position,"key":"A" if str(mesh.name).begins_with("A") else "B"})
		if not str(mesh.name).begins_with("A"): mesh.material_override = d.space.material(Color("76b5d7"))
	d.note(d.planes[0],"X",[-14,0,.8])
	d.note(d.planes[0],"Z",[-.8,0,14])
	d.note(d.scene,"O",[1,0,-1])
	y_h = d.note(d.planes[1],"Y",[-1,-14,0])
	y_w = d.note(d.planes[2],"Y_W",[0,-14,1])
	for foot in d.feet: a_labels.append(foot.find_children("*","Label3D",true,false)[0])
	var p: Array = d.r.data.parameters.points_mm.B
	b_note = d.note(d.scene,"B",[p[0]+2,p[1],p[2]+2])
	b_note.modulate = Color("76b5d7")
	for i in range(3):
		var foot: Node3D = d.node(d.planes[i])
		var sphere := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = .00065
		shape.height = .0013
		sphere.mesh = shape
		sphere.material_override = d.space.material(Color("76b5d7"))
		foot.add_child(sphere)
		var label: Label3D = d.note(foot,["b′","b","b″"][i],[1.7,0,1.5])
		label.modulate = Color("76b5d7")
		b_labels.append(label)
		b_feet.append(foot)
		var ray: Node3D = d.node(d.scene)
		var projected: Array = [[p[0],0,p[2]],[p[0],p[1],0],[0,p[1],p[2]]]
		ray.add_child(Stroke.make([[Vector3.ZERO,d.space.g(projected[i])-d.space.g(p)]],Color("76b5d7")))
		b_rays.append(ray)
	for label in d.scene.find_children("*","Label3D",true,false):
		label_bases.append({"label":label,"key":label.text.split(" ")[0],"font_size":label.font_size,"color":label.modulate})

func apply(value: Array) -> void:
	update_refs(value)
	var beat: Dictionary = d.beats[d.current_beat]
	var unfolded: bool = float(value[6])>.999 and float(value[7])>.999
	y_h.text = "Y_H" if float(value[6])>.001 else "Y"
	y_w.visible = float(value[7])>.001
	for entry in mesh_bases:
		var p: Array = position(value,entry.key)
		var original: Array = d.r.data.parameters.points_mm[entry.key]
		entry.mesh.global_position = entry.position+d.space.g(p)-d.space.g(original)
		entry.mesh.visible = not unfolded and (entry.key=="A" or float(value[15])>.001)
	var names: Array = beat.get("example_names",["A","B"])
	var labels: Array = []
	for key in ["A","B"]:
		var p: Array = position(value,key)
		var original: Array = d.r.data.parameters.points_mm[key]
		var i_key := 0 if key=="A" else 1
		var note: Label3D = d.point_note if key=="A" else b_note
		note.position = d.space.g([p[0]+2,p[1],p[2]+2])
		note.text = names[i_key]
		note.visible = not unfolded and (key=="A" or float(value[15])>.001)
		if note.visible: labels.append({"label":note,"point":d.space.g(p),"text":note.text})
		var projected: Array = [[p[0],0,p[2]],[p[0],p[1],0],[0,p[1],p[2]]]
		for i in range(3):
			var foot: Node3D = d.feet[i] if key=="A" else b_feet[i]
			var foot_label: Label3D = a_labels[i] if key=="A" else b_labels[i]
			var ray: Node3D = d.rays[i] if key=="A" else b_rays[i]
			var amount: float = float(value[i+3]) if key=="A" else float(value[15])
			foot.position = d.space.g(projected[i])
			foot.visible = amount>.001
			foot.scale = Vector3.ONE*maxf(.001,amount)
			foot_label.visible = foot.visible
			foot_label.text = str(names[i_key]).to_lower()+["′","","″"][i]
			if foot.visible: labels.append({"label":foot_label,"point":foot.global_position,"text":foot_label.text})
			var axis: int = [1,2,0][i]
			var ratio: float = float(p[axis])/float(original[axis])
			ratio *= float(value[i]) if key=="A" else float(value[15])
			ray.position = d.space.g(p)
			ray.scale = Vector3.ONE*(ratio if absf(ratio)>.001 else .001)
			ray.visible = absf(ratio)>.001 and not unfolded and not (i==1 and float(value[6])>.001) and not (i==2 and float(value[7])>.001)
	# Projections can share a position while successive coordinate shifts are introduced.
	for i in range(labels.size()):
		if not labels[i].label.visible: continue
		for j in range(i+1,labels.size()):
			if labels[j].label.visible and labels[i].point.distance_to(labels[j].point)<.00001:
				labels[i].label.text += "/"+labels[j].text
				labels[j].label.hide()
	d.sheet.canvas.primitives = paper_primitives()
	d.sheet.canvas.progress = float(value[8])
	highlight_labels(beat.get("label_focus",[]))

