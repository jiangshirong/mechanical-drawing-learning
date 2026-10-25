extends Control
signal feature_selected(id: String, world: Array)
signal observation_changed
const Stroke = preload("res://stroke_3d.gd")
const UI = preload("res://ui_style.gd")
var helper_key: Array = []
var point_marker: MeshInstance3D
var helper_builds := 0

var data: Dictionary = {}
var render_scale := 1.0
var active_until_msec := 0
var image: TextureRect
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var model: Node3D
var helpers: Node3D
var selected := ""
var auxiliary := true
var projections := true
var unfold := 0.0
var unfold_target := 0.0
var yaw := -0.48
var pitch := 0.38
var zoom := 0.13
var target := Vector3.ZERO
var drag_start := Vector2.ZERO
var last_pos := Vector2.ZERO
var dragging := false
var drag_distance := 0.0
var picked_world: Array = []
var picking_enabled := true
var interaction_enabled := true
var rotation_only := false

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 600)
	viewport.handle_input_locally = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_4X
	resized.connect(sync_render_size)
	get_viewport().size_changed.connect(sync_render_size)
	add_child(viewport)
	image = TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sync_render_size()
	world = Node3D.new()
	viewport.add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UI.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env_node.environment = env
	world.add_child(env_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 1.2
	world.add_child(camera)
	camera.current = true

func g(p: Array) -> Vector3:
	return Vector3(p[0], p[2], -float(p[1])) * 0.001

func clear_branch(node: Node) -> void:
	if is_instance_valid(node):
		if node.get_parent(): node.get_parent().remove_child(node)
		node.queue_free()

func material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func install(d: Dictionary, path: String) -> void:
	clear_branch(model)
	clear_branch(helpers)
	helper_key.clear()
	data = d
	model = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE).instantiate()
	world.add_child(model)
	decorate(model)
	var b: Array = data.bounds
	target = g([(float(b[0][0]) + float(b[0][1])) / 2, (float(b[1][0]) + float(b[1][1])) / 2, (float(b[2][0]) + float(b[2][1])) / 2])
	zoom = maxf(float(b[0][1]) - float(b[0][0]), maxf(float(b[1][1]) - float(b[1][0]), float(b[2][1]) - float(b[2][0]))) * 0.001 * 1.7
	if data.abstract:
		var xmin := minf(float(b[0][0]) - 7, -5)
		var ymin := minf(float(b[1][0]) - 7, -5)
		var zmax := float(b[2][1]) + 8
		target = g([(xmin + 8) / 2, (ymin + 6) / 2, zmax / 2])
		zoom = maxf(0.082, maxf(8-xmin, zmax) * 0.00198)
	yaw = -0.48
	pitch = 0.38
	picked_world = []
	unfold = 0
	unfold_target = 0
	refresh_helpers()
	update_camera()

func decorate(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = material(Color("6caec3"), 0.62 if node.name == "ABCD" else 1.0)
		if not data.abstract or data.id == "plane": node.create_trimesh_collision()
	for child in node.get_children(): decorate(child)

func sync_render_size() -> void:
	if not is_instance_valid(viewport): return
	var density := get_viewport().get_final_transform().get_scale().abs()
	render_scale = clampf(maxf(density.x,density.y),1.0,2.0)
	var pixels := Vector2i(maxi(1,ceili(size.x*render_scale)),maxi(1,ceili(size.y*render_scale)))
	if viewport.size != pixels:
		viewport.size = pixels
		request_render()

func request_render() -> void:
	active_until_msec = Time.get_ticks_msec()+100
	if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_camera() -> void:
	camera.size = zoom
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 0.5
	camera.look_at(target, Vector3.UP)
	request_render()

func get_state() -> Dictionary:
	return {"yaw": yaw, "pitch": pitch, "zoom": zoom, "target": [target.x, target.y, target.z]}

func restore_state(state: Dictionary) -> void:
	if state.is_empty(): return
	yaw = float(state.get("yaw", yaw))
	pitch = clampf(float(state.get("pitch", pitch)), -1.4, 1.4)
	zoom = clampf(float(state.get("zoom", zoom)), 0.025, 0.35)
	var p: Array = state.get("target", [target.x, target.y, target.z])
	target = Vector3(p[0], p[1], p[2])
	update_camera()

func standard_view(key: String) -> void:
	if key == "front": yaw = 0; pitch = 0
	elif key == "left": yaw = -PI / 2; pitch = 0
	elif key == "top": yaw = 0; pitch = PI / 2 - 0.001
	else: yaw = -0.48; pitch = 0.38
	update_camera()
	observation_changed.emit()

func add_lines(lines: Array, color: Color) -> void:
	if lines.is_empty(): return
	helpers.add_child(Stroke.make(lines,color))

func plane_quad(points: Array, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 1, 2, 0, 2, 3]: mesh.surface_add_vertex(g(points[i]))
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, 0.13)
	helpers.add_child(mi)
	var lines: Array = []
	for i in range(4): lines.append([g(points[i]), g(points[(i+1)%4])])
	add_lines(lines, color)

func transform_plane(p: Array, key: String) -> Array:
	var angle := unfold * PI / 2
	if key == "front": return [p[0], 0, p[2]]
	if key == "top": return [p[0], float(p[1]) * cos(angle), float(p[1]) * sin(angle)]
	return [-float(p[1]) * sin(angle), float(p[1]) * cos(angle), p[2]]

func add_label(text: String, position: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/msyh.ttc")
	label.font_size = 36
	label.pixel_size = 0.000065
	label.outline_size = 2
	label.outline_modulate = UI.BACKGROUND
	label.modulate = color
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	helpers.add_child(label)
	return label

func add_plane_label(text: String, quad: Array, key: String, color: Color) -> void:
	var origin := g(quad[0])
	var across := g(quad[1]) - origin
	var upwards := g(quad[3]) - origin
	var horizontal := across.normalized() * (-1.0 if key == "left" else 1.0)
	var vertical := upwards.normalized()
	var normal := horizontal.cross(vertical).normalized()
	var position := origin + across * 0.5 + upwards * (0.82 if key == "top" else 0.16)
	var label := add_label(text, position + normal * 0.00015, color)
	# A plane caption belongs to the plane: foreground points and geometry occlude it.
	label.no_depth_test = false
	label.outline_size = 0
	label.pixel_size = 0.00006
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.basis = Basis(horizontal, vertical, normal)
	var text_width := label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	label.pixel_size = minf(label.pixel_size, across.length() * 0.8 / maxf(text_width, 1))

func refresh_helpers() -> void:
	update_marker()
	var cache_key := [data.get("id",""),data.get("section_active",false),auxiliary,projections,unfold]
	if cache_key == helper_key and is_instance_valid(helpers): return
	helper_key = cache_key
	helper_builds += 1
	request_render()
	clear_branch(helpers)
	helpers = Node3D.new()
	world.add_child(helpers)
	if data.is_empty(): return
	var plain: Array = []
	for curve in data.curves:
		if curve.get("projection_only", false): continue
		for i in range(curve.points.size() - 1):
			var pair := [g(curve.points[i]), g(curve.points[i+1])]
			plain.append(pair)
	add_lines(plain, Color("264656"))
	if data.get("section_active",false):
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for polygon in data.section.polygons:
			var points := PackedVector2Array()
			for p in polygon: points.append(Vector2(p[0],p[1]))
			for i in Geometry2D.triangulate_polygon(points):
				mesh.surface_add_vertex(g([points[i].x,-0.03,points[i].y]))
		mesh.surface_end()
		var cut_face := MeshInstance3D.new()
		cut_face.name = "CutFaces"
		cut_face.mesh = mesh
		cut_face.material_override = material(Color("d4b482"))
		helpers.add_child(cut_face)
		var hatch_lines: Array = []
		for h in data.section.hatches:
			hatch_lines.append([g([h.a[0],-0.05,h.a[1]]),g([h.b[0],-0.05,h.b[1]])])
		add_lines(hatch_lines,Color("47505a"))
	for f in data.features:
		if f.kind == "point": add_label(f.id, g(f.points[0]) + Vector3(0.0018, 0.0022, 0), Color.WHITE)
	if data.abstract and projections:
		var b: Array = data.bounds
		var xmin := minf(b[0][0] - 7, -5)
		var ymin := minf(b[1][0] - 7, -5)
		var xmax := 8.0
		var ymax := 6.0
		var zmax := float(b[2][1]) + 8
		var quads := {"front": [[xmin, 0, 0], [xmax, 0, 0], [xmax, 0, zmax], [xmin, 0, zmax]], "top": [[xmin, ymin, 0], [xmax, ymin, 0], [xmax, ymax, 0], [xmin, ymax, 0]], "left": [[0, ymin, 0], [0, ymax, 0], [0, ymax, zmax], [0, ymin, zmax]]}
		var colors := {"front": Color("74aace"), "top": Color("88b792"), "left": Color("c6a77b")}
		for key in ["front", "top", "left"]:
			var quad: Array = []
			for p in quads[key]: quad.append(transform_plane(p, key))
			plane_quad(quad, colors[key])
			var name := "V 正面" if key == "front" else ("H 水平面" if key == "top" else "W 侧面")
			add_plane_label(name, quad, key, colors[key])
			var rays: Array = []
			var projected: Array = []
			for f in data.features:
				if f.kind != "point": continue
				var p: Array = f.points[0]
				var foot := transform_plane(p, key)
				if unfold < 0.001 or key == "front": rays.append([g(p), g(foot)])
				add_label(f.id.to_lower() + ("′" if key == "front" else ("″" if key == "left" else "")), g(foot) + Vector3(0.001, 0.001, 0), colors[key])
			for c in data.curves:
				for i in range(c.points.size()-1): projected.append([g(transform_plane(c.points[i],key)), g(transform_plane(c.points[i+1],key))])
			add_lines(rays, Color(colors[key], 0.65))
			add_lines(projected, colors[key])

func update_marker() -> void:
	if not is_instance_valid(point_marker):
		point_marker = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.0012
		sm.height = 0.0024
		point_marker.mesh = sm
		var marker_material := material(Color("ffb66b"))
		marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker_material.no_depth_test = true
		marker_material.render_priority = 127
		point_marker.material_override = marker_material
		world.add_child(point_marker)
	point_marker.visible = not picked_world.is_empty()
	if point_marker.visible: point_marker.position = g(picked_world)
	request_render()

func _process(delta: float) -> void:
	if absf(unfold - unfold_target) > 0.001:
		unfold = move_toward(unfold, unfold_target, delta * 1.5)
		refresh_helpers()
	elif unfold != unfold_target:
		unfold = unfold_target
		refresh_helpers()

func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if rotation_only: accept_event(); return
			if not event.pressed: return
			zoom = clampf(zoom * (0.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.11), 0.025, 0.35)
			update_camera()
			observation_changed.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
				last_pos = event.position
				drag_distance = 0
			else:
				dragging = false
				if drag_distance < 5: pick(event.position)
				else: observation_changed.emit()
	elif event is InputEventMouseMotion and dragging:
		var movement: Vector2 = event.relative
		drag_distance += movement.length()
		yaw -= movement.x * 0.009
		pitch = clampf(pitch + movement.y * 0.007, -1.4, 1.4)
		last_pos = event.position
		update_camera()

func pick(pos: Vector2) -> void:
	if not picking_enabled: return
	pos *= Vector2(viewport.size)/size
	# Screen-space point/edge picking avoids tiny geometry becoming impossible to hit.
	var best := 10.0
	var id := ""
	var picked: Array = []
	for f in data.features:
		if f.kind != "point": continue
		var p := camera.unproject_position(g(f.points[0]))
		var distance := p.distance_to(pos)
		if distance < best:
			best = distance
			id = f.id
			picked = f.points[0]
	for c in data.curves:
		if c.get("projection_only", false): continue
		for i in range(c.points.size()-1):
			var a := camera.unproject_position(g(c.points[i]))
			var b := camera.unproject_position(g(c.points[i+1]))
			var p := Geometry2D.get_closest_point_to_segment(pos,a,b)
			if p.distance_to(pos) < best:
				best = p.distance_to(pos)
				id = c.id
				var t := a.distance_to(p) / maxf(a.distance_to(b), 0.001)
				var w := g(c.points[i]).lerp(g(c.points[i+1]), t)
				picked = [w.x*1000, -w.z*1000, w.y*1000]
	# A solid's visible surface takes precedence over an occluded screen-space edge.
	var origin := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2)
	var space := viewport.find_world_3d()
	var hit: Dictionary = space.direct_space_state.intersect_ray(query) if space else {}
	if not hit.is_empty():
		var w: Vector3 = hit.position
		var wp := [w.x*1000, -w.z*1000, w.y*1000]
		if picked.is_empty() or origin.distance_to(g(picked)) > origin.distance_to(w) + 0.003:
			id = "body"
			if data.id == "plane": id = "ABCD"
			picked = wp
			if data.id == "slope":
				if absf(wp[2]-42) < 0.2 or (absf(absf(wp[1])-7) < 0.2 and wp[2] >= 42): id = "slot"
				elif wp[0] < -8 and wp[2] > 26: id = "slope"
			elif data.id == "base":
				if absf(absf(wp[0])-17) < 0.3 and wp[1] > 12: id = "slot"
				elif absf(Vector2(wp[0],wp[2]-36).length()-12) < 0.5: id = "bore"
			elif data.id == "bracket":
				if absf(Vector2(wp[0],wp[2]-38).length()-12) < 0.5: id = "upright_hole"
				elif absf(Vector2(wp[1]+20,wp[2]-12).length()-7) < 0.5: id = "base_hole"
	if not id.is_empty(): feature_selected.emit(id, picked)
