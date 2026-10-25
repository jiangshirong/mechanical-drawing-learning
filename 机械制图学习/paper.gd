extends Control
signal feature_selected(id: String, world: Array)
signal observation_point_moved(id: String, world: Array)

var data: Dictionary = {}
var selected := ""
var step := 0
var auxiliary := true
var projection := true
var ink := Color("263747")
var accent := Color("d06d35")
var font: Font
var screen_segments: Array = []
var origins: Dictionary = {}
var scale_mm := 1.0
var picked_world: Array = []
var dragging_point := false
var drag_view := ""
var point_press := Vector2.ZERO
var point_offset := Vector2.ZERO
var point_moved := false
var picking_enabled := true
var guide_rib := false
var guide_focus := ""
var draw_count := 0

func _ready() -> void:
	font = load("res://assets/fonts/msyh.ttc")
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func setup(d: Dictionary) -> void:
	data = d
	picked_world = []
	dragging_point = false
	drag_view = ""
	screen_segments.clear()
	queue_redraw()

func uv(p: Array, key: String) -> Vector2:
	if key == "front": return Vector2(p[0], p[2])
	if key == "top": return Vector2(p[0], p[1])
	return Vector2(-float(p[1]), p[2])

func screen(p: Vector2, key: String) -> Vector2:
	return origins[key] + Vector2(p.x, -p.y) * scale_mm

func label_at(p: Vector2, text: String, color: Color = Color("647788"), fs: int = 15) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func dashed(a: Vector2, b: Vector2, color: Color, width: float = 1.4) -> void:
	if a.x > b.x + 0.01 or (absf(a.x - b.x) <= 0.01 and a.y > b.y):
		var swap := a
		a = b
		b = swap
	var length := a.distance_to(b)
	if length < 0.05: return
	var direction := (b - a) / length
	# Global paper-space phase keeps small occlusion samples from becoming solid.
	var phase := fposmod(a.dot(direction), 10.0)
	var offset := -phase
	while offset < length:
		var start := maxf(0.0, offset)
		var finish := minf(length, offset + 6.0)
		if finish > start: draw_line(a + direction * start, a + direction * finish, color, width, true)
		offset += 10.0

func centerline(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var direction := (b-a).normalized()
	var offset := 0.0
	while offset < length:
		for interval in [[0.0, 12.0], [16.0, 18.0]]:
			var begin := offset + float(interval[0])
			var end := minf(offset + float(interval[1]), length)
			if begin < end: draw_line(a+direction*begin, a+direction*end, Color("687889"), 1.0, true)
		offset += 22

func _draw() -> void:
	draw_count += 1
	draw_style_box(get_theme_stylebox("panel", "Panel"), Rect2(Vector2.ZERO, size))
	if data.is_empty() or size.x < 100: return
	screen_segments.clear()
	var b: Array = data.bounds
	var dx := float(b[0][1]) - float(b[0][0])
	var dy := float(b[1][1]) - float(b[1][0])
	var dz := float(b[2][1]) - float(b[2][0])
	var gap := 74.0
	scale_mm = minf((size.x - 90.0 - gap) / maxf(dx + dy, 1.0), (size.y - 130.0 - gap) / maxf(dz + dy, 1.0))
	var left := 36.0
	var top := 65.0
	var fx := left - float(b[0][0]) * scale_mm
	var fz := top + float(b[2][1]) * scale_mm
	var lx := left + dx * scale_mm + gap + float(b[1][1]) * scale_mm
	var front_bottom := fz - float(b[2][0]) * scale_mm
	var ty := front_bottom + gap + float(b[1][1]) * scale_mm
	origins = {"front": Vector2(fx, fz), "left": Vector2(lx, fz), "top": Vector2(fx, ty)}
	var names := ["正面投影 V", "侧面投影 W", "水平投影 H"] if data.abstract else ["主视图", "左视图", "俯视图"]
	if data.get("section_active",false): names[0] = "主视图（全剖）"
	label_at(Vector2(left, top - 22), names[0], ink, 18)
	label_at(Vector2(left + dx * scale_mm + gap, top - 22), names[1], ink, 18)
	label_at(Vector2(left, front_bottom + gap - 20), names[2], ink, 18)
	if auxiliary and projection:
		for x in [float(b[0][0]), float(b[0][1])]:
			draw_line(screen(Vector2(x, b[2][1]), "front"), screen(Vector2(x, b[1][0]), "top"), Color("dbe4eb"), 1)
		for z in [float(b[2][0]), float(b[2][1])]:
			draw_line(screen(Vector2(b[0][0], z), "front"), screen(Vector2(-float(b[1][0]), z), "left"), Color("dbe4eb"), 1)
	if data.abstract:
		for key in ["front", "top", "left"]:
			draw_line(origins[key] - Vector2(10, 0), origins[key] + Vector2(10, 0), Color("c6d2dc"), 1)
			draw_line(origins[key] - Vector2(0, 10), origins[key] + Vector2(0, 10), Color("c6d2dc"), 1)
	# Draw hidden first, visible last. Coincident visible edges must take priority.
	for key in ["front","top","left"]:
		for h in data.views[key].get("hatches",[]):
			draw_line(screen(Vector2(h.a[0],h.a[1]),key),screen(Vector2(h.b[0],h.b[1]),key),ink,0.9,true)
	for c in data.get("center_marks", []):
		var p := Vector2(c.uv[0], c.uv[1])
		var radius := float(c.radius)+4
		centerline(screen(p-Vector2(radius,0),c.view),screen(p+Vector2(radius,0),c.view))
		centerline(screen(p-Vector2(0,radius),c.view),screen(p+Vector2(0,radius),c.view))
	for c in data.get("center_lines",[]):
		centerline(screen(Vector2(c.a[0],c.a[1]),c.view),screen(Vector2(c.b[0],c.b[1]),c.view))
	for hidden in [true, false]:
		for key in ["front", "top", "left"]:
			for index in range(data.views[key].segments.size()):
				var seg: Dictionary = data.views[key].segments[index]
				if bool(seg.hidden) != hidden: continue
				var a := screen(Vector2(seg.a[0], seg.a[1]), key)
				var c := screen(Vector2(seg.b[0], seg.b[1]), key)
				if hidden: dashed(a, c, ink, 1.3)
				else: draw_line(a, c, ink, 1.8, true)
				screen_segments.append({"a": a, "b": c, "id": seg.feature, "view": key, "hidden":hidden, "world_a": seg.world_a, "world_b": seg.world_b})
	for key in ["front", "top", "left"]:
		for point in data.views[key].points:
			var p := screen(Vector2(point.uv[0], point.uv[1]), key)
			draw_circle(p, 4.2, ink, true, -1.0, true)
			var suffix := "′" if key == "front" else ("″" if key == "left" else "")
			label_at(p + Vector2(7, -7), str(point.feature).to_lower() + suffix, ink, 18)
	if data.abstract and data.id == "plane" and auxiliary:
		var f: Dictionary = data.features[1]
		for key in ["front", "top", "left"]:
			dashed(screen(uv(f.points[0], key), key), screen(uv(f.points[1], key), key), Color("7ea1b9"))
	if not picked_world.is_empty():
		for key in ["front", "top", "left"]:
			var p := screen(uv(picked_world, key), key)
			draw_circle(p, 5, accent, true, -1.0, true)
	if guide_rib:
		var rib: Array = data.section.rib_polygon
		var center := Vector2.ZERO
		for p in rib: center += Vector2(p[0],p[1])
		center /= rib.size()
		var at := screen(center,"front")
		label_at(at+Vector2(-18,5),"肋板",ink,16)
	if not guide_focus.is_empty(): draw_guide_focus()

func dim_outside(region: Rect2) -> void:
	var clipped := region.intersection(Rect2(Vector2.ZERO,size))
	var dim := Color(0.03,0.06,0.09,0.64)
	draw_rect(Rect2(0,0,size.x,clipped.position.y),dim)
	draw_rect(Rect2(0,clipped.end.y,size.x,maxf(0,size.y-clipped.end.y)),dim)
	draw_rect(Rect2(0,clipped.position.y,clipped.position.x,clipped.size.y),dim)
	draw_rect(Rect2(clipped.end.x,clipped.position.y,maxf(0,size.x-clipped.end.x),clipped.size.y),dim)

func draw_guide_focus() -> void:
	if guide_focus == "projection":
		var b: Array = data.bounds
		var a := screen(Vector2(b[0][0],b[2][1]),"front")-Vector2(12,35)
		var end := screen(Vector2(b[0][1],b[2][0]),"front")+Vector2(12,15)
		dim_outside(Rect2(a,end-a))
	elif guide_focus == "rib":
		var points := PackedVector2Array()
		for p in data.section.rib_polygon: points.append(screen(Vector2(p[0],p[1]),"front"))
		var region := Rect2(points[0],Vector2.ZERO)
		for point in points: region = region.expand(point)
		dim_outside(region.grow(14))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline,Color("bd7924"),2.4,true)

func hit_test(pos: Vector2, view := "", radius := 10.0, preserve_world := false) -> Dictionary:
	var best := radius
	var hit: Dictionary = {}
	var continuity := INF
	var candidates: Array = []
	for key in ["front", "top", "left"]:
		if not origins.has(key) or (not view.is_empty() and view != key): continue
		for point in data.views[key].points:
			var distance := pos.distance_to(screen(Vector2(point.uv[0],point.uv[1]),key))
			if distance <= radius:
				best = minf(best,distance)
				candidates.append({"id":point.feature,"world":point.world,"view":key,"point":true,"distance":distance})
	for seg in screen_segments:
		if not view.is_empty() and seg.view != view: continue
		var p := Geometry2D.get_closest_point_to_segment(pos,seg.a,seg.b)
		var distance := pos.distance_to(p)
		if distance > radius: continue
		best = minf(best,distance)
		var t: float = seg.a.distance_to(p)/maxf(seg.a.distance_to(seg.b),0.001)
		var a := Vector3(seg.world_a[0],seg.world_a[1],seg.world_a[2])
		var b := Vector3(seg.world_b[0],seg.world_b[1],seg.world_b[2])
		var w := a.lerp(b,t)
		candidates.append({"id":seg.id,"world":[w.x,w.y,w.z],"view":seg.view,"hidden":seg.hidden,"distance":distance})
	# Compare all ties against the true minimum, so dense curves cannot accumulate drift.
	for candidate in candidates:
		if float(candidate.distance)>best+0.5: continue
		var p: Array = candidate.world
		var delta_world := INF if picked_world.is_empty() else Vector3(p[0],p[1],p[2]).distance_to(Vector3(picked_world[0],picked_world[1],picked_world[2]))
		var prefer := hit.is_empty()
		if not prefer:
			if candidate.get("point",false): prefer = not hit.get("point",false) or float(candidate.distance)<float(hit.distance)
			elif hit.get("point",false): continue
			elif preserve_world: prefer = delta_world < continuity
			else: prefer = (bool(hit.get("hidden",true)) and not bool(candidate.hidden)) or (bool(hit.hidden)==bool(candidate.hidden) and float(candidate.distance)<float(hit.distance))
		if prefer:
			continuity = delta_world
			hit = candidate
	return hit

func move_corresponding_point(pos: Vector2) -> void:
	if data.id == "points" and not selected.is_empty() and not picked_world.is_empty():
		if not point_moved and pos.distance_to(point_press) < 6: return
		point_moved = true
		var projected: Vector2 = (pos + point_offset - origins[drag_view]) / scale_mm
		var moved := picked_world.duplicate()
		if drag_view == "front":
			moved[0] = projected.x
			moved[2] = -projected.y
		elif drag_view == "top":
			moved[0] = projected.x
			moved[1] = -projected.y
		else:
			moved[1] = -projected.x
			moved[2] = -projected.y
		observation_point_moved.emit(selected, moved)
		return
	var hit := hit_test(pos,drag_view,INF,true)
	if hit.is_empty(): return
	feature_selected.emit(hit.id,hit.world)

func _gui_input(event: InputEvent) -> void:
	if not picking_enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			point_press = event.position
			point_offset = Vector2.ZERO
			point_moved = false
			dragging_point = false
			drag_view = ""
			if not picked_world.is_empty():
				for key in ["front","top","left"]:
					if origins.has(key) and event.position.distance_to(screen(uv(picked_world,key),key))<10:
						dragging_point = true
						drag_view = key
						point_offset = screen(uv(picked_world,key),key) - event.position
						accept_event()
						return
			var hit := hit_test(event.position)
			if not hit.is_empty():
				dragging_point = true
				drag_view = str(hit.view)
				point_offset = screen(uv(hit.world,drag_view),drag_view) - event.position
				feature_selected.emit(hit.id,hit.world)
				accept_event()
		else:
			if dragging_point: move_corresponding_point(event.position)
			dragging_point = false
	elif event is InputEventMouseMotion and dragging_point:
		move_corresponding_point(event.position)
		accept_event()
