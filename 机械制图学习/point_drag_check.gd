extends RefCounted
var r
var checks: Array = []

func frames(n := 3) -> void:
	for frame in range(n): await r.get_tree().process_frame

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check":name,"passed":passed,"detail":detail})

func mouse_button(pos: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	r.get_viewport().push_input(motion,true)
	var button := InputEventMouseButton.new()
	button.position = pos
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	r.get_viewport().push_input(button,true)
	await frames()

func move_to(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	r.get_viewport().push_input(motion,true)
	await frames()

func pos(world: Vector3, view: String) -> Vector2:
	return r.paper.global_position+r.paper.screen(r.paper.uv([world.x,world.y,world.z],view),view)

func close_world(expected: Vector3) -> bool:
	if r.paper.picked_world.is_empty(): return false
	var p: Array = r.paper.picked_world
	return Vector3(p[0],p[1],p[2]).distance_to(expected)<0.1 and p==r.observer.picked_world

func run(root) -> Array:
	r = root
	r.save_path = "user://qa-observation-v1.json"
	r.states = {}
	r.load_example(1,false)
	await frames(5)
	var a := Vector3(-10,-5,15)
	var b := Vector3(-35.980762,-20,15)
	var camera_before: Dictionary = r.observer.get_state()
	await mouse_button(pos(a.lerp(b,0.25),"front"),true)
	check("solid_click",close_world(a.lerp(b,0.25)))
	await move_to(pos(a.lerp(b,0.75),"front"))
	check("solid_drag",close_world(a.lerp(b,0.75)))
	await move_to(pos(a.lerp(b,0.45),"front")+Vector2(0,80))
	check("off_line_mouse_moves_marker",close_world(a.lerp(b,0.45)))
	await move_to(pos(a.lerp(b,0.65),"front")+Vector2(0,110))
	check("farther_off_line_mouse_keeps_moving_marker",close_world(a.lerp(b,0.65)))
	await move_to(pos(b,"front")+Vector2(-70,80))
	check("off_line_drag_clamps_at_endpoint",close_world(b))
	await move_to(pos(a.lerp(b,0.75),"front"))
	check("return_to_line_keeps_dragging",close_world(a.lerp(b,0.75)))
	await mouse_button(pos(a.lerp(b,0.75),"front"),false)
	check("release_finishes_drag",not r.paper.dragging_point)
	await move_to(pos(a.lerp(b,0.9),"front"))
	check("movement_after_release_ignored",close_world(a.lerp(b,0.75)))
	await mouse_button(pos(a.lerp(b,0.75),"top"),true)
	await move_to(pos(a.lerp(b,0.4),"top"))
	check("same_marker_dragged_from_other_view",close_world(a.lerp(b,0.4)))
	var direction := (pos(b,"top")-pos(a,"top")).normalized()
	await move_to(pos(a.lerp(b,0.6),"top")+Vector2(-direction.y,direction.x)*90)
	check("off_line_drag_in_angled_view",close_world(a.lerp(b,0.6)))
	await mouse_button(pos(a.lerp(b,0.4),"top"),false)
	check("drag_preserves_camera",r.observer.get_state()==camera_before)
	var line_node := r.observer.model.find_child("AB",true,false) as MeshInstance3D
	check("line_material_unchanged",line_node.material_override is StandardMaterial3D and line_node.material_override.albedo_color==Color("6caec3"))
	r.load_example(3,false)
	await frames(5)
	check("example_switch_clears_point",r.paper.picked_world.is_empty() and r.observer.picked_world.is_empty())
	# The hidden groove-floor edge is a straight horizontal line in the front view.
	var start := Vector3(8,7,42)
	var finish := Vector3(25,7,42)
	await mouse_button(pos(start,"front"),true)
	check("hidden_click",close_world(start))
	await move_to(pos(finish,"front"))
	check("hidden_drag",close_world(finish))
	await mouse_button(pos(finish,"front"),false)
	r.select_feature("slot",[8,-7,42])
	await frames()
	await mouse_button(pos(Vector3(8,-7,42),"front"),true)
	await move_to(pos(Vector3(25,-7,42),"front"))
	check("overlapping_hidden_edges_keep_depth",close_world(Vector3(25,-7,42)))
	await mouse_button(pos(Vector3(25,-7,42),"front"),false)
	var body := r.observer.model.find_child("body",true,false) as MeshInstance3D
	check("solid_no_face_highlight",body.material_override is StandardMaterial3D and body.material_override.albedo_color==Color("6caec3"))
	r.observer.request_render()
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/point-drag-hidden.png")
	# Circular motion keeps its depth, but must also reach other disconnected rims.
	r.load_example(4,false)
	await frames(5)
	var c0 := Vector3(12,-20,36)
	var c1 := Vector3(0,-20,48)
	await mouse_button(pos(c0,"front"),true)
	for i in range(1,17):
		var angle := PI*0.5*float(i)/16
		await move_to(pos(Vector3(12*cos(angle),-20,36+12*sin(angle)),"front"))
	check("circular_rim_drag",close_world(c1))
	var outer := Vector3(0,-20,56)
	await move_to(pos(outer,"front"))
	check("drag_from_hole_to_disconnected_outer_rim",close_world(outer))
	var corner := Vector3(30,-35,0)
	await move_to(pos(corner,"front"))
	check("drag_from_rim_to_separate_base_outline",close_world(corner))
	await move_to(pos(c1,"front"))
	check("drag_back_to_hole_without_reclick",close_world(c1),{"actual":r.paper.picked_world.duplicate(),"expected":[c1.x,c1.y,c1.z],"scale":r.paper.scale_mm})
	await mouse_button(pos(c1,"front"),false)
	r.observer.request_render()
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/point-drag-circle.png")
	# A held drag can visit widely separated segments in each combination view.
	for example in [3,4,5]:
		r.load_example(example,false)
		await frames(5)
		for view in ["front","top","left"]:
			var targets: Array = []
			for seg in r.paper.screen_segments:
				if seg.view==view: targets.append((seg.a+seg.b)*0.5)
			var reachable := not targets.is_empty()
			if reachable:
				await mouse_button(r.paper.global_position+targets[0],true)
				for sample in range(24):
					var target: Vector2 = targets[mini(roundi(float(sample)*(targets.size()-1)/23),targets.size()-1)]
					await move_to(r.paper.global_position+target)
					if r.paper.picked_world.is_empty(): reachable = false
					else:
						var marker: Vector2 = r.paper.screen(r.paper.uv(r.paper.picked_world,view),view)
						reachable = reachable and marker.distance_to(target)<1.0 and r.paper.picked_world==r.observer.picked_world
				await mouse_button(r.paper.global_position+targets[-1],false)
			check(str(r.data.id)+"_"+view+"_all_sampled_regions_reachable",reachable)
	FileAccess.open("res://qa/point-drag-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	return checks
