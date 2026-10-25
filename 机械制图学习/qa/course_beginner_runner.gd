extends RefCounted
# Evidence for a human teaching review. Assertions alone do not approve content.
var r
var c
var h
var checks:Array=[]
var pictures:Array=[]
var suffix:="normal"
func check(name:String,ok:bool)->void:checks.append({"check":name,"passed":ok})
func frames(n:=3)->void:await h.frames(n)
func shot(id:String,stage:String)->void:
	await frames();c.paper.queue_redraw();await RenderingServer.frame_post_draw
	var file:="beginner-"+id.replace(":","_")+"-"+stage+"-"+suffix+".png"
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+file)
	pictures.append({"beat":id,"stage":stage,"file":file,"text":c.current_beat.text,"scene":c.player.state.scene,"phase":c.player.phase})
func settle()->void:
	if c.player.phase in ["typing","playing"]:await h.key(KEY_D)
	if c.player.phase=="ready":await h.click(c.next);await h.key(KEY_D)
	if c.player.phase=="playing":await h.key(KEY_D)
func legacy_picture(d,chapter:String,stage:String)->void:
	await frames();r.queue_redraw();await RenderingServer.frame_post_draw
	var b:Dictionary=d.beats[d.current_beat]
	var file:String="beginner-legacy_"+chapter+"_"+b.id.replace(":","_")+"-"+stage+"-"+suffix+".png"
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+file)
	pictures.append({"beat":chapter+":"+b.id,"stage":stage,"file":file,"text":b.text,"scene":b.get("scene","legacy"),"phase":d.phase})
func legacy_evidence()->void:
	var targets:Dictionary={"points":["planes:purpose","planes:names","relative:purpose","alignment:depth"],"line":["projection:purpose","intersection:both-clue"],"plane":["in-point:problem","in-point:level","complete:E-top"]}
	for chapter in targets:
		var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://模型/"+chapter+"_learning.json"))
		var wanted:Array=targets[chapter].duplicate()
		for group in config.concept:
			wanted.append(group.beats[0].id)
			wanted.append(group.beats[-1].id)
		var ordered:Array=[]
		for group in config.concept:
			for beat in group.beats:
				if beat.id in wanted and beat.id not in ordered:ordered.append(beat.id)
		targets[chapter]=ordered
	for chapter in targets:
		r.open_map_example(chapter);await frames()
		for target in targets[chapter]:
			r.set(chapter+"_step_id",target);r.course_host.enter(chapter);await frames()
			var d=r.course_host.controller()
			check(chapter+" "+target+" visible target",d.beats[d.current_beat].id==target)
			await h.key(KEY_D)
			if d.phase=="ready" and d.has_action():
				if chapter=="plane" and target=="in-point:level":
					await legacy_picture(d,chapter,"before");await h.click(d.next);await h.wait_seconds(2.1)
					check("plane familiar method really continues",d.phase=="playing" and d.sheet.canvas.progress>d.before_states[d.current_beat] and d.sheet.canvas.progress<d.after_states[d.current_beat])
					await legacy_picture(d,chapter,"during");await h.wait_seconds(2.3)
					check("plane continuous construction finishes naturally",d.phase=="settled")
				else:await h.click(d.next);await h.key(KEY_D)
			await legacy_picture(d,chapter,"settled");r.course_host.leave();await frames()
		r.show_knowledge_map();await frames()
func run(main)->void:
	r=main;c=r.course_workspace;h=load("res://line_practice_check.gd").new();h.r=r
	suffix="minimum" if "--minimum" in OS.get_cmdline_user_args() else "normal"
	DisplayServer.window_set_size(Vector2i(1060,720) if suffix=="minimum" else Vector2i(1440,900))
	await frames(8);r.states={};r.save_blocked=false;r.show_knowledge_map()
	if "--method-review" in OS.get_cmdline_user_args():
		await load("res://qa/course_method_runner.gd").new().run(r,suffix);return
	var natural=["basic_solids:cone:point","intersection_plane:prism:remove","intersection_plane:cone:points","intersection_solids:inner:both-surfaces","combination:slope:parts","section:full:remove","section:half:cut","section:rotated:unfold","removed_section:key:outline","dimensions:meaning:datum","threads:meaning:pitch","gears:single:pitch0","bearings:structure:rings","bearings:assembly:shaft","requirements:hole:grade","requirements:perpendicular:units","roughness:meaning:profile"]
	for id in c.registry.chapters:
		if "--legacy-only" in OS.get_cmdline_user_args():continue
		if c.registry.chapters[id].legacy:continue
		print("BEGINNER_REVIEW ",suffix," ",id)
		r.open_map_example(id);await frames();await h.click(c.nav.get_node("CourseNav_concept"));c.player.current=0;c.player.prepare();await frames()
		for i in range(c.player.beats.size()):
			var b:Dictionary=c.player.beats[i]
			check(b.id+" order",c.player.current==i)
			if b.has("camera"):check(b.id+" relevant cut faces camera",is_equal_approx(c.space.yaw,float(b.camera.yaw)))
			if b.has("setup"):check(b.id+" new context never shows previous scene",c.player.state.scene==b.scene)
			if i==0:
				await h.wait_seconds(.2);check(b.id+" genuine typewriter",c.copy.visible_characters>0 and c.copy.visible_characters<c.copy.text.length())
			if b.id in natural:
				await h.key(KEY_D)
				if c.player.phase=="ready":
					await shot(b.id,"before");await h.click(c.next);await h.wait_seconds(float(b.action.get("duration",1.8))*.48)
					check(b.id+" intermediate real state",c.player.phase=="playing" and c.player.state!=c.player.before[i] and c.player.state!=c.player.after[i])
					await shot(b.id,"during");await h.wait_seconds(float(b.action.get("duration",1.8))*.6+.1)
					check(b.id+" natural completion",c.player.phase in ["settled","complete"] and c.player.state==c.player.after[i]);await shot(b.id,"after")
			await settle()
			check(b.id+" full text",c.copy.visible_characters<0 or c.copy.visible_characters>=c.copy.text.length())
			check(b.id+" caption fits",r.get_global_rect().encloses(c.caption.get_global_rect()))
			check(b.id+" footer fits",r.get_global_rect().encloses(c.footer.get_global_rect()))
			check(b.id+" stable",c.player.state==c.player.after[i])
			if i==0 or (i>0 and b.group!=c.player.beats[i-1].group) or i==c.player.beats.size()-1 or (i+1<c.player.beats.size() and b.group!=c.player.beats[i+1].group):await shot(b.id,"settled")
			if i<c.player.beats.size()-1:await h.key(KEY_D)
		for old in c.course.concept.get("resume_aliases",{}):
			c.player.open(c.course.concept,old)
			check(old+" alias",c.player.beats[c.player.current].id==c.course.concept.resume_aliases[old])
		c.exit_lesson();c.leave_to_map();await frames()
	await legacy_evidence()
	check("true viewport size",r.get_viewport().get_visible_rect().size==Vector2(DisplayServer.window_get_size()))
	check("isolated save",r.save_path=="user://qa-course-beginner.json")
	check("offscreen no focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	var report_suffix:String=("legacy-" if "--legacy-only" in OS.get_cmdline_user_args() else "")+suffix
	FileAccess.open("res://qa/course-beginner-"+report_suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"pictures":pictures,"evidence_boundary":"Rendered contexts and natural intermediate states. Human content review is recorded separately."},"\t"))
