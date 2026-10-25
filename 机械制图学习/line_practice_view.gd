extends "res://practice_view.gd"
func _gui_input(event: InputEvent) -> void:
	if not board.readonly and board.helper!=null and board.helper.handle_canvas(event):
		accept_event(); return
	super._gui_input(event)

func constrain_pan() -> void:
	# The same millimetre conversion can place original drawings outside the
	# point exercise's 600x600 rectangle. Bound the actual exercise extent.
	if board.task.is_empty(): super.constrain_pan(); return
	var b: Array = board.task.bounds
	var a:Vector2 = board.canvas.at([b[0],b[3]])*zoom
	var extent := Vector2(b[2]-b[0],b[3]-b[1])*10*zoom
	var edge := extent.min(size*.5).min(Vector2(96,96))
	pan.x=clampf(pan.x,edge.x-a.x-extent.x,size.x-edge.x-a.x)
	pan.y=clampf(pan.y,edge.y-a.y-extent.y,size.y-edge.y-a.y)
