extends RefCounted
var r
var h
var checks: Array = []
var stage := "after"

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check":name,"passed":passed,"detail":detail})

func rendered() -> void:
	r.observer.request_render()
	await h.wait_frames(3)
	await RenderingServer.frame_post_draw

func screenshot(name: String) -> void:
	await rendered()
	r.get_viewport().get_texture().get_image().save_png("res://qa/point-quality-"+stage+"-"+name+".png")

func plane_labels() -> Array:
	return r.observer.helpers.get_children().filter(func(n):return n is Label3D and n.text in ["V 正面","H 水平面","W 侧面"])

func overlap(label: Label3D) -> void:
	var ball: Vector3 = r.observer.g(r.data.features[0].points[0])
	var direction := (ball-label.global_position).normalized()
	r.observer.target = label.global_position
	r.observer.yaw = atan2(direction.x,direction.z)
	r.observer.pitch = asin(direction.y)
	r.observer.zoom = 0.052
	r.observer.update_camera()
	await rendered()
	var with_text: Image = r.observer.viewport.get_texture().get_image()
	var center: Vector2 = r.observer.camera.unproject_position(ball)
	label.visible = false
	await rendered()
	var without_text: Image = r.observer.viewport.get_texture().get_image()
	label.visible = true
	await rendered()
	var difference := 0.0
	# Stay within the opaque center of the real source-point sphere, avoiding MSAA edges.
	for y in range(-2,3):
		for x in range(-2,3):
			var p := Vector2i(center)+Vector2i(x,y)
			var a := with_text.get_pixelv(p)
			var b := without_text.get_pixelv(p)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	check("ball_occludes_"+label.text, difference<0.01 if stage=="after" else true,{"interior_difference":difference,"no_depth_test":label.no_depth_test})
	await screenshot("overlap-"+label.text.left(1))

func run(root, phase: String) -> void:
	r = root
	stage = phase
	h = load("res://interaction_check.gd").new()
	h.r = r
	await h.wait_frames(10)
	for i in [0,1,2]:
		await h.choose(i)
		r.observer.standard_view("reset")
		await rendered()
		check("three_plane_labels_"+str(r.data.id),plane_labels().size()==3)
		check("labels_inside_planes_"+str(r.data.id),plane_labels().all(func(n):return n.billboard==BaseMaterial3D.BILLBOARD_DISABLED))
		if stage=="after": check("plane_labels_use_depth_"+str(r.data.id),plane_labels().all(func(n):return not n.no_depth_test))
		await screenshot(str(r.data.id))
		# Crop the rendered paper around a real projection point for visual comparison.
		var point: Dictionary = r.data.views.front.points[0]
		var pos: Vector2 = r.paper.global_position+r.paper.screen(Vector2(point.uv[0],point.uv[1]),"front")
		var transform: Transform2D = r.get_viewport().get_final_transform()
		var pixel: Vector2 = transform*pos
		var image: Image = r.get_viewport().get_texture().get_image()
		image.get_region(Rect2i(Vector2i(pixel)-Vector2i(18,18),Vector2i(36,36))).save_png("res://qa/point-quality-"+stage+"-"+str(r.data.id)+"-detail.png")
		await h.click(pos)
		check("smooth_dot_picking_"+str(r.data.id),r.paper.picked_world==point.world and r.observer.picked_world==point.world)
		await screenshot(str(r.data.id)+"-selected")
	await h.choose(0)
	for label in plane_labels(): await overlap(label)
	if stage=="after":
		checks.append_array(await h.run(r))
		checks.append_array(await load("res://point_drag_check.gd").new().run(r))
	FileAccess.open("res://qa/point-quality-"+stage+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failures := checks.filter(func(c):return not c.passed)
	print("POINT_QUALITY ",JSON.stringify({"stage":stage,"total":checks.size(),"failures":failures}))
	if not failures.is_empty(): push_error("Point display acceptance failed")
