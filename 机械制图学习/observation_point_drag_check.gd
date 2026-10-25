extends "res://point_drag_check.gd"

func run(root) -> Array:
	r = root
	r.save_path = "user://qa-observation-point-drag.json"
	var h = load("res://interaction_check.gd").new()
	h.r = r
	await h.choose(0)
	await frames(6)
	var original: Dictionary = r.data.duplicate(true)
	var camera_before: Dictionary = r.observer.get_state()
	var a := Vector3(-10,-15,12)
	for view in ["front","top","left"]:
		var target := a + (Vector3(2,0,3) if view == "front" else (Vector3(-1,2,0) if view == "top" else Vector3(0,-2,-1)))
		await mouse_button(pos(a,view),true)
		await move_to(pos(target,view))
		check(view+"_free_drag",close_world(target),r.paper.picked_world.duplicate())
		await mouse_button(pos(target,view),false)
		check(view+"_release",not r.paper.dragging_point)
		for key in ["front","top","left"]:
			var point: Dictionary = r.paper.data.views[key].points[0]
			check(view+"_sync_"+key,Vector2(point.uv[0],point.uv[1]).distance_to(r.paper.uv([target.x,target.y,target.z],key))<0.01)
		var sphere := r.observer.model.find_child("A",true,false) as Node3D
		check(view+"_actual_sphere",is_instance_valid(sphere) and sphere.global_position.distance_to(r.observer.g([target.x,target.y,target.z]))<0.00001)
		a = target
	check("source_parameters_unchanged",r.data==original)
	check("camera_unchanged",r.observer.get_state()==camera_before)
	check("other_point_unchanged",r.paper.data.features[1].points==original.features[1].points)
	r.show_knowledge_map()
	r.open_map_example("points")
	await frames()
	check("map_return_keeps_position",close_world(a))
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/observation-point-drag.png")
	FileAccess.open("res://qa/observation-point-drag-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	return checks
