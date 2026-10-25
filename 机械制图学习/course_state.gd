extends RefCounted
# Entity poses, shared by both renderers. Geometry stays in author millimetres.
static func patch(base:Dictionary,changes:Dictionary)->Dictionary:
	var result:Dictionary=base.duplicate(true)
	if changes.has("scene"):
		if changes.scene!=base.get("scene",""):result.parts={}
		result.scene=changes.scene
	if changes.has("view_box"):result.view_box=changes.view_box.duplicate()
	elif changes.has("scene") and changes.scene!=base.get("scene",""):result.erase("view_box")
	for id in changes.get("parts",{}):
		if not result.parts.has(id):result.parts[id]={"visibility":0.0,"draw":1.0,"move":[0,0,0],"angle":0.0}
		for key in changes.parts[id]:result.parts[id][key]=changes.parts[id][key]
	return result
static func blend(a:Dictionary,b:Dictionary,t:float)->Dictionary:
	if t<=0:return a.duplicate(true)
	if t>=1:return b.duplicate(true)
	var result:Dictionary=a.duplicate(true)
	if a.scene!=b.scene:result.parts={}
	result.scene=b.scene
	if b.has("view_box"):
		result.view_box=[]
		var before:Array=a.get("view_box",b.view_box) if a.scene==b.scene else b.view_box
		for i in range(4):result.view_box.append(lerpf(float(before[i]),float(b.view_box[i]),t))
	else:result.erase("view_box")
	for id in b.parts:
		var end:Dictionary=b.parts[id]
		var old:Dictionary=a.parts.get(id,{"visibility":0.0,"draw":0.0,"move":[0,0,0],"angle":0.0}) if a.scene==b.scene else {"visibility":0.0,"draw":0.0,"move":[0,0,0],"angle":0.0}
		var p:Dictionary=end.duplicate(true)
		for key in ["visibility","draw","angle"]:p[key]=lerpf(float(old.get(key,0)),float(end.get(key,0)),t)
		p.move=[]
		for i in range(3):p.move.append(lerpf(float(old.get("move",[0,0,0])[i]),float(end.get("move",[0,0,0])[i]),t))
		result.parts[id]=p
	return result
static func sample(a:Dictionary,b:Dictionary,frames:Array,t:float)->Dictionary:
	var old:Dictionary=a;var start:=0.0
	for frame in frames:
		var finish:float=frame.at
		if t<=finish:
			var u:=clampf((t-start)/maxf(finish-start,.00001),0,1)
			return blend(old,frame.state,u*u*(3-2*u))
		old=frame.state;start=finish
	var u:=clampf((t-start)/maxf(1-start,.00001),0,1)
	return blend(old,b,u*u*(3-2*u))
