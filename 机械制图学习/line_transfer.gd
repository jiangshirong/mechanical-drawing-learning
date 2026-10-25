extends RefCounted
# One continuous third-projection construction shared by both line lessons.
# Front level runs alongside depth -> 45 degrees -> vertical transfer.
const DURATION := 2.4
const POINT_TIME := .64

static func portions(t:float) -> Array:
	var strokes:Array=[clampf(t/.64,0,1),clampf(t/.32,0,1),clampf((t-.32)/.32,0,1)]
	var erased:Array=[0.0,0.0,0.0]
	var sweep:=clampf((t-.76)/.24,0,1)*3
	for i in range(3):erased[[1,2,0][i]]=clampf(sweep-i,0,1)
	var result:Array=[]
	for i in range(3):result.append([erased[i],strokes[i]])
	return result

static func eraser(t:float) -> Array:
	if t<=.76 or t>=1:return []
	var sweep:=clampf((t-.76)/.24,0,1)*3
	var i:=mini(2,int(sweep))
	return [[1,2,0][i],sweep-i]

static func path(refs:Dictionary,action:Dictionary) -> Array:
	return [[refs[action.front],refs[action.height]],[refs[action.top],refs[action.diagonal]],[refs[action.diagonal],refs[action.side]]]
