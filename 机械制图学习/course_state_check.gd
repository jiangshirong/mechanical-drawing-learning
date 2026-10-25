extends RefCounted
var r
var h
var checks:Array=[]
func check(label:String,value:bool)->void:
	checks.append({"check":label,"passed":value})
	if not value:push_warning("COURSE_STATE_QA "+label)
func frames(n:=3)->void:await h.frames(n)
func drag(a:Vector2,b:Vector2)->void:
	var hover:=InputEventMouseMotion.new();hover.position=a;r.get_viewport().push_input(hover,true);await frames()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=a;r.get_viewport().push_input(e,true);await frames()
	var m:=InputEventMouseMotion.new();m.position=b;m.relative=b-a;m.button_mask=MOUSE_BUTTON_MASK_LEFT;r.get_viewport().push_input(m,true);await frames()
	e=e.duplicate();e.pressed=false;e.position=b;r.get_viewport().push_input(e,true);await frames()
func run(root)->void:
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	await frames(5);var c=r.course_workspace
	var writing:bool="--state-write" in OS.get_cmdline_user_args()
	var expected:Dictionary={} if writing else JSON.parse_string(FileAccess.get_file_as_string("res://qa/course-resume-targets.json"))
	for id in c.registry.chapters:
		if c.registry.chapters[id].legacy:continue
		r.open_map_example(id);await frames();c.start_concept();await frames()
		if writing:
			var target:int=mini(c.player.beats.size()-1,3)
			for i in range(1,c.player.beats.size()):
				c.player.current=i
				if c.player.has_action() and not c.player.prepares_with_text():target=i;break
			c.player.current=target;c.player.prepare();expected[id]=c.player.beats[target].id
		else:
			check(id+" persisted target",c.player.beats[c.player.current].id==expected[id])
			check(id+" restores before action",c.player.state==c.player.before[c.player.current] and c.player.phase=="typing")
		c.exit_lesson();await frames();var nodes:int=c.space.world.get_child_count()
		c.start_concept();c.exit_lesson();c.start_concept();c.exit_lesson();await frames()
		check(id+" node pools stable",c.space.world.get_child_count()==nodes)
		c.leave_to_map()
	if writing:
		FileAccess.open("res://qa/course-resume-targets.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
	else:
		for id in ["points","line","plane"]:
			r.course_host.enter(id);await frames(4)
			check(id+" compatibility host enters requested chapter",r.data.id==id and r.course_host.controller()!=null)
			r.course_host.advance();r.course_host.jump(0);await frames();r.course_host.retreat();r.course_host.leave();await frames()
			check(id+" compatibility host exits",not r.presentation_active())
		# Natural text, natural action, and copied native text rather than a simulated final-state assertion.
		for id in ["basic_solids","combination","section","gears","requirements"]:
			r.open_map_example(id);c.start_concept();await frames()
			for i in range(c.player.beats.size()):
				c.player.current=i
				if c.player.has_action() and not c.player.prepares_with_text():break
			c.player.prepare();await h.wait_seconds(.2)
			check(id+" natural typing partial",c.copy.visible_characters>0 and c.copy.visible_characters<c.copy.text.length())
			var timeout:=0.0
			while c.player.phase=="typing" and timeout<10:await h.wait_seconds(.1);timeout+=.1
			check(id+" natural typing stops at ready",c.player.phase=="ready")
			var caption:Rect2=c.caption.get_global_rect()
			if c.space.visible:
				var yaw:float=c.space.yaw;var p:Vector2=c.space.get_global_rect().get_center();await drag(p,p+Vector2(28,12))
				check(id+" internal orbit",not is_equal_approx(c.space.yaw,yaw))
				check(id+" caption stable while orbiting",c.caption.get_global_rect()==caption)
			await h.click(c.next);check(id+" step resets camera",is_equal_approx(c.space.yaw,.65))
			await h.wait_seconds(float(c.player.beats[c.player.current].action.get("duration",2))+0.15)
			check(id+" natural action stops",c.player.phase in ["settled","complete"] and c.player.state==c.player.after[c.player.current])
			var n:int=c.player.current;await h.wait_seconds(.25);check(id+" result waits for next input",c.player.current==n)
			# RichTextLabel's drag timer samples the OS cursor; offscreen injected
			# motion cannot certify system dragging. Double-click uses event-local
			# hit testing and exercises the native selection/copy path safely.
			for x in range(6,150,12):
				var at:Vector2=c.copy.get_global_rect().position+Vector2(x,18)
				await h.click_at(at)
				for pressed in [true,false]:
					var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.double_click=pressed;r.get_viewport().push_input(event,true);await frames(2)
				if not c.copy.get_selected_text().is_empty():break
			check(id+" native pointer selection",not c.copy.get_selected_text().is_empty())
			check(id+" selected text never becomes drag object",not c.copy.drag_and_drop_selection_enabled)
			var previous_clipboard:String=DisplayServer.clipboard_get();await h.key(KEY_C,true)
			check(id+" native copy",DisplayServer.clipboard_get()==c.copy.get_selected_text());DisplayServer.clipboard_set(previous_clipboard)
			c.exit_lesson();c.leave_to_map()
		# Both old guide IDs and invalid IDs are resolved before typing begins.
		r.states.erase("course:section");r.states["section"]={"guide_step_id":"rib_convention"};r.open_map_example("section");c.start_concept();await frames()
		check("old full-section ID",c.player.beats[c.player.current].id=="section:full:rib");c.exit_lesson();c.leave_to_map()
		r.states["course:gears"]={"concept_step_id":"deleted-and-invalid"};r.open_map_example("gears");c.start_concept();await frames()
		check("invalid ID starts at beginning",c.player.current==0);c.exit_lesson();c.leave_to_map()
		# A real internal pointer can select existing projected geometry and its spatial counterpart.
		r.open_map_example("basic_solids");await frames(5)
		await h.click_at(c.space.get_global_rect().get_center());await frames()
		check("3D corresponding point",c.paper.marker.size()==3 and c.space.marker.visible)
		var picked:=false
		for entity in c.paper.scene.entities.values():
			for view in entity.get("paths",{}):
				for line in entity.paths[view]:
					if line.has("world_points") and not picked:
						var at:Vector2=(c.paper.at(line.points[0],view)+c.paper.at(line.points[1],view))*.5+c.paper.global_position
						await h.click_at(at);picked=true;break
		check("2D corresponding point",picked and c.paper.marker.size()==3 and c.space.marker.visible)
		var marker:Array=c.paper.marker.duplicate();c.start_concept();await frames();c.exit_lesson();await frames()
		check("lesson restores corresponding point",c.paper.marker==marker and c.space.marker.visible);c.leave_to_map()
		for key in [KEY_Q,KEY_W,KEY_E,KEY_R]:await h.key(key)
		check("qwer developer mode",r.developer_mode)
		r.open_map_example("gears");await frames();c.show_source("question");await frames();check("developer original opens",c.source_overlay.visible and c.source_texture.texture!=null);c.source_overlay.hide()
		c.show_source("answer");await frames();check("developer reference opens",c.source_overlay.visible and c.source_texture.texture!=null);c.source_overlay.hide();c.leave_to_map()
		var old_path:String=r.save_path;var old_states:Dictionary=r.states.duplicate(true)
		r.save_path="user://qa-course-corrupt.json";var bad:="{broken save";FileAccess.open(r.save_path,FileAccess.WRITE).store_string(bad);r.load_states();r.save_states()
		check("corrupt original retained",r.save_blocked and FileAccess.get_file_as_string(r.save_path)==bad)
		for payload in [{"schema_version":1,"states":{"course:gears":{"observation":{"pan":[1]}}}},{"schema_version":1,"states":{"points":{"camera":{"target":[1,2]}}}},{"schema_version":1,"states":{"line":[]}}]:
			bad=JSON.stringify(payload);r.save_path="user://qa-course-shape-"+str(checks.size())+".json";r.save_blocked=false;FileAccess.open(r.save_path,FileAccess.WRITE).store_string(bad);r.load_states();r.save_states()
			check("invalid nested save retained "+str(checks.size()),r.save_blocked and FileAccess.get_file_as_string(r.save_path)==bad)
		r.save_path=old_path;r.states=old_states;r.save_blocked=false;r.persistence_error=""
	r.save_states();await frames()
	FileAccess.open("res://qa/course-state-"+("write" if writing else "reopen")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
