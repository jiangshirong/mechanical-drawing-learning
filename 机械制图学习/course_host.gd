extends RefCounted
# Stable public entry points, delegating to existing players without rewriting them.
var r
func _init(root):r=root
func enter(id:String,kind:="concept",task_id:="")->void:
	if r.presentation_active():leave()
	if id in ["points","line","plane"] and (r.map_active or r.data.get("id","")!=id or r.course_workspace.visible):r.open_map_example(id)
	match id:
		"points":r.points_demo.enter("solution" if kind=="question" else "concept")
		"line":
			if kind=="concept":r.line_demo.enter()
			else:
				for task in r.line_workspace.config.tasks:
					if task.id==task_id:r.line_solution.enter(task);return
		"plane":
			if kind=="concept":r.plane_demo.enter()
			else:
				for task in r.plane_questions.config.tasks:
					if task.id==task_id:r.plane_solution.enter(task);return
		_:
			if not r.course_workspace.visible or r.course_workspace.chapter.get("id","")!=id:r.course_workspace.open(id)
			if kind=="question":r.course_workspace.start_task(task_id)
			else:r.course_workspace.start_concept()
func controller():
	for player in [r.points_demo,r.line_demo,r.line_solution,r.plane_demo,r.plane_solution]:
		if player.active:return player
	if r.course_workspace.active:return r.course_workspace.player
	return null
func advance()->void:
	var target=controller()
	if target:target.advance()
func retreat()->void:
	var target=controller()
	if target:target.retreat()
func jump(section:int)->void:
	var target=controller()
	if not target:return
	if target.has_method("jump_chapter"):target.jump_chapter(section)
	else:target.jump(section)
func leave()->void:
	if r.course_workspace.active:r.course_workspace.exit_lesson();return
	var target=controller()
	if target:target.exit()
