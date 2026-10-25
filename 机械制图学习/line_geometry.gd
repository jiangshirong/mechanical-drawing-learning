extends RefCounted
const VIEWS = ["space","front","top","left"]
var config: Dictionary
var scenes: Dictionary = {}

static func vector(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func project(p: Vector3,view: String) -> Vector2:
	if view=="front": return Vector2(p.x,p.z)
	if view=="top": return Vector2(p.x,p.y)
	return Vector2(-p.y,p.z)

static func world(p: Vector3) -> Vector3:
	return Vector3(p.x,p.z,-p.y)*.001

func load_config(value: Dictionary) -> void:
	config = value
	scenes.clear()
	for id in config.scenes:
		var spec: Dictionary = config.scenes[id].duplicate(true)
		var points: Dictionary = {}
		if spec.has("parameter_source"):
			var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/examples/"+str(spec.parameter_source)+"/data.json"))
			var parameters: Dictionary = model.parameters.points_mm if spec.parameter_source=="points" else model.parameters
			points.A = vector(parameters.A)
			points.B = vector(parameters.B)
		for key in spec.points: points[key]=vector(spec.points[key])
		for key in spec.derived: points[key]=derive(spec.derived[key],points,spec.lines)
		points.O = Vector3.ZERO
		points.angle_axis = points.get("A",Vector3.ZERO)+Vector3(-12,0,0)
		spec.resolved = points
		scenes[id] = spec

func derive(recipe: Dictionary,points: Dictionary,lines: Dictionary) -> Vector3:
	var kind: String = recipe.type
	if kind in ["face_point","fraction"]:
		var ends: Array = lines[recipe.line]
		var a: Vector3 = points[ends[0]]
		var b: Vector3 = points[ends[1]]
		var t: float = float(recipe.get("value",.4))
		if kind=="face_point":
			var axis: int = ["x","y","z"].find(recipe.axis)
			t = (float(recipe.value)-a[axis])/(b[axis]-a[axis])
		return a.lerp(b,t)
	if kind=="parallel_end":
		var ends: Array = lines[recipe.line]
		return points[recipe.origin]+points[ends[1]]-points[ends[0]]
	if kind=="parallelogram": return points[recipe.a]+points[recipe.c]-points[recipe.d]
	if kind=="level_start":
		var p: Vector3 = points[recipe.point]
		return Vector3(-48,0,p.z) if recipe.axis=="z" else Vector3(-48,p.y,0)
	if kind=="axis_foot":
		var p: Vector3 = points[recipe.point]
		return Vector3(0,0,p.z) if recipe.axis=="z" else Vector3(0,p.y,0)
	if kind=="parallel_transversal":
		var ref: Array = lines[recipe.direction]
		var first: Array = lines[recipe.first]
		var second: Array = lines[recipe.second]
		var c: Vector3 = points[first[0]]
		var e: Vector3 = points[second[0]]
		var u: Vector3 = points[first[1]]-c
		var v: Vector3 = points[second[1]]-e
		var w: Vector3 = points[ref[1]]-points[ref[0]]
		var solved: Vector3 = Basis(u,-v,w).inverse()*(e-c)
		return c+u*solved.x if int(recipe.endpoint)==0 else e+v*solved.y
	var first: Array = lines[recipe.first]
	var second: Array = lines[recipe.second]
	var a: Vector3 = points[first[0]]
	var b: Vector3 = points[first[1]]
	var e: Vector3 = points[second[0]]
	var f: Vector3 = points[second[1]]
	if kind=="intersection":
		var r: Vector3 = b-a
		var s: Vector3 = f-e
		var cross: Vector3 = r.cross(s)
		return a+r*((e-a).cross(s).dot(cross)/cross.length_squared())
	var view: String = recipe.view
	var r2: Vector2 = project(b-a,view)
	var s2: Vector2 = project(f-e,view)
	var delta: Vector2 = project(e-a,view)
	if recipe.on==recipe.first: return a.lerp(b,delta.cross(s2)/r2.cross(s2))
	return e.lerp(f,delta.cross(r2)/r2.cross(s2))

func initial(scene_id: String) -> Dictionary:
	var spec: Dictionary = scenes[scene_id]
	var s: Dictionary = {"scene":scene_id,"points":{},"lines":{},"ticks":0.0,"fraction":.4,"side_guides":{"A":0.0,"B":0.0}}
	var known: Array = spec.get("known_views",VIEWS)
	for key in spec.resolved:
		s.points[key]={}
		for view in VIEWS: s.points[key][view]=1.0 if key in spec.visible_points and view in known else 0.0
	for key in spec.lines:
		s.lines[key]={}
		for view in VIEWS: s.lines[key][view]=1.0 if key in spec.initial_lines and view in known else 0.0
	return s

func apply_action(s: Dictionary,action: Dictionary) -> void:
	if action.type=="scene":
		var replacement := initial(action.scene)
		var known: Array = scenes[action.scene].get("known_views",VIEWS)
		for key in action.get("retain_lines",[]):
			if not s.lines.has(key) or not replacement.lines.has(key): continue
			for view in known:
				replacement.lines[key][view]=maxf(replacement.lines[key][view],s.lines[key][view])
		s.clear(); s.merge(replacement)
		return
	var views: Array = action.get("views",VIEWS)
	if action.type=="line":
		for view in views: s.lines[action.id][view]=1.0
	elif action.type=="side_point":
		s.side_guides[action.id]=1.0
		s.points[action.id].left=1.0
	elif action.type=="points":
		for key in action.ids:
			for view in views: s.points[key][view]=1.0
	elif action.type=="construct":
		for key in action.lines:
			for view in views: s.lines[key][view]=1.0
		for key in action.points:
			for view in views: s.points[key][view]=1.0
	elif action.type=="ticks": s.ticks=float(action.value)
	elif action.type=="fraction": s.fraction=float(action.value)

func point(s: Dictionary,key: String) -> Vector3:
	if s.get("positions",{}).has(key): return s.positions[key]
	var spec: Dictionary = scenes[s.scene]
	if key=="C" and s.scene=="ratio":
		return spec.resolved.A.lerp(spec.resolved.B,float(s.fraction))
	return spec.resolved.get(key,Vector3.ZERO)

func ends(s: Dictionary,key: String) -> Array[Vector3]:
	var spec: Dictionary = scenes[s.scene]
	var pair: Array = s.get("line_pairs",spec.lines)[key]
	return [point(s,pair[0]),point(s,pair[1])]

func transition(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	if t<=0: return a.duplicate(true)
	if t>=1: return b.duplicate(true)
	var result: Dictionary = a.duplicate(true)
	result.morph_target=b.scene
	result.positions={}
	result.line_pairs=scenes[a.scene].lines.duplicate(true)
	result.line_pairs.merge(scenes[b.scene].lines,true)
	var names: Dictionary = a.points.duplicate(true)
	names.merge(b.points,true)
	for key in names:
		var old: Vector3 = point(a,key) if a.points.has(key) else point(b,key)
		var target: Vector3 = point(b,key) if b.points.has(key) else old
		# A point hidden in the new exercise must not preview its answer.
		if not b.points.has(key) or b.points[key].values().all(func(v):return float(v)==0): target=old
		result.positions[key]=old.lerp(target,t)
		result.points[key]={}
		for view in VIEWS:
			result.points[key][view]=lerpf(float(a.points.get(key,{}).get(view,0)),float(b.points.get(key,{}).get(view,0)),t)
	# Transform a known segment by its centre, orientation and length. This
	# avoids the unintended collapse that endpoint-only interpolation can cause.
	for key in ["AB","EF"]:
		if not a.lines.has(key) or not b.lines.has(key): continue
		if float(a.lines[key].space)<=0 or float(b.lines[key].space)<=0: continue
		var old_ends: Array[Vector3] = ends(a,key)
		var new_ends: Array[Vector3] = ends(b,key)
		var old_delta: Vector3 = old_ends[1]-old_ends[0]
		var new_delta: Vector3 = new_ends[1]-new_ends[0]
		if old_delta.length()<.000001 or new_delta.length()<.000001: continue
		var rotation := Quaternion(old_delta.normalized(),new_delta.normalized())
		var direction: Vector3 = Quaternion.IDENTITY.slerp(rotation,t)*old_delta.normalized()
		var centre: Vector3 = ((old_ends[0]+old_ends[1])*.5).lerp((new_ends[0]+new_ends[1])*.5,t)
		var half: Vector3 = direction*lerpf(old_delta.length(),new_delta.length(),t)*.5
		var pair: Array = result.line_pairs[key]
		result.positions[pair[0]]=centre-half
		result.positions[pair[1]]=centre+half
	var all_lines: Dictionary = a.lines.duplicate(true)
	all_lines.merge(b.lines,true)
	for key in all_lines:
		result.lines[key]={}
		for view in VIEWS:
			result.lines[key][view]=lerpf(float(a.lines.get(key,{}).get(view,0)),float(b.lines.get(key,{}).get(view,0)),t)
	result.ticks=lerpf(a.ticks,b.ticks,t)
	result.side_guides=interpolate(a.side_guides,b.side_guides,t)
	return result

static func interpolate(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	var result: Dictionary = a.duplicate(true)
	for key in b:
		if b[key] is Dictionary: result[key]=interpolate(a[key],b[key],t)
		elif b[key] is float or b[key] is int: result[key]=lerpf(float(a[key]),float(b[key]),t)
		else: result[key]=b[key]
	return result

func side_projection_guides(s: Dictionary,key: String) -> Array:
	var p := point(s,key)
	var top := project(p,"top")
	var front := project(p,"front")
	var side := project(p,"left")
	var diagonal := Vector2(-p.y,p.y)
	return [[front,side+Vector2(6,0)],[top,diagonal],[diagonal,side]]
