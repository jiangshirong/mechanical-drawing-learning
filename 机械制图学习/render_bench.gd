extends RefCounted
var r
var samples: Array = []
var rendered_frames := 0

func on_render() -> void:
	rendered_frames += 1

func measure(name: String, count := 90, rotate := false) -> void:
	var cpu: Array = []
	var frame: Array = []
	var calls: Array = []
	var draws_before: int = r.paper.draw_count
	var renders_before := rendered_frames
	var builds_before: int = r.observer.helper_builds
	var last := Time.get_ticks_usec()
	for i in range(count):
		if rotate:
			r.observer.yaw += 0.008
			r.observer.update_camera()
		await r.get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame.append((now-last)/1000.0)
		last = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	cpu.sort()
	frame.sort()
	samples.append({"name":name,"cpu_median_ms":cpu[count/2],"cpu_p95_ms":cpu[int(count*0.95)],"frame_median_ms":frame[count/2],"draw_calls_last":calls.back(),"rendered_frames":rendered_frames-renders_before,"paper_redraws":r.paper.draw_count-draws_before,"helper_rebuilds":r.observer.helper_builds-builds_before})

func screenshot(name: String) -> void:
	r.observer.request_render()
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+name+".png")

func run(root,stage: String) -> void:
	r = root
	RenderingServer.frame_post_draw.connect(on_render)
	r.load_example(6,false)
	r.observer.standard_view("reset")
	for i in range(20): await r.get_tree().process_frame
	await screenshot("render-"+stage+"-section")
	await measure("free_idle")
	await measure("free_rotate",90,true)
	var helper_before: int = r.observer.helpers.get_instance_id()
	var marker_before: int = r.observer.point_marker.get_instance_id()
	var start := Time.get_ticks_usec()
	for i in range(30): r.select_feature("cut",[-37,0,25+float(i)*0.1])
	samples.append({"name":"thirty_point_updates","total_ms":(Time.get_ticks_usec()-start)/1000.0,"same_helpers":helper_before==r.observer.helpers.get_instance_id(),"same_marker":marker_before==r.observer.point_marker.get_instance_id()})
	for i in range(10): await r.get_tree().process_frame
	await r.guide.enter()
	r.guide.go_to(0,false)
	await measure("guide_idle")
	r.guide.go_to(2)
	await measure("guide_animation",90)
	while r.guide.busy: await r.get_tree().process_frame
	r.guide.go_to(0,false)
	for i in range(5): await r.get_tree().process_frame
	r.guide.go_to(2)
	await measure("guide_animation_warm",90)
	r.guide.go_to(5,false)
	r.observer.standard_view("reset")
	for i in range(8): await r.get_tree().process_frame
	await screenshot("render-"+stage+"-guide")
	await measure("guide_final_idle")
	var report := {"stage":stage,"samples":samples,"viewport_size":[r.observer.viewport.size.x,r.observer.viewport.size.y],"msaa":r.observer.viewport.msaa_3d,"camera":r.observer.get_state(),"monitor_note":"TIME_PROCESS is a delayed engine monitor; samples can include scene loading and must not be treated as per-frame CPU time. Idle frame interval is not rendered FPS.","offscreen":DisplayServer.window_get_position().x<0}
	if stage == "after":
		r.guide.exit()
		DisplayServer.window_set_size(Vector2i(1920,1080))
		for i in range(20): await r.get_tree().process_frame
		var scale: Vector2 = r.get_viewport().get_final_transform().get_scale()
		report["large_window"] = {"window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"container":[r.observer.size.x,r.observer.size.y],"render_pixels":[r.observer.viewport.size.x,r.observer.viewport.size.y],"canvas_scale":[scale.x,scale.y],"density":r.observer.render_scale,"native_resolution":r.observer.viewport.size.x>=ceili(r.observer.size.x*scale.x) and r.observer.viewport.size.y>=ceili(r.observer.size.y*scale.y)}
		for chapter in [0,3,4,5,6]:
			r.load_example(chapter,false)
			r.observer.standard_view("reset")
			for i in range(8): await r.get_tree().process_frame
			if chapter == 0:
				var point: Array = r.data.features[0].points[0]
				var pixel: Vector2 = r.observer.camera.unproject_position(r.observer.g(point))
				var local: Vector2 = pixel* r.observer.size/Vector2(r.observer.viewport.size)
				var input = load("res://interaction_check.gd").new()
				input.r = r
				await input.click(r.observer.global_position+local)
				report.large_window["point_input_scaled"] = r.paper.picked_world == point and r.observer.picked_world == point
			await screenshot("render-quality-"+str(r.data.id))
		DisplayServer.window_set_size(Vector2i(1440,900))
	FileAccess.open("res://qa/render-"+stage+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RENDER_BENCH ",JSON.stringify(report))
	RenderingServer.frame_post_draw.disconnect(on_render)
