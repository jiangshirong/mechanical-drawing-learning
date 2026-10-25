extends RefCounted
# Author meshes use outward CCW triangles. Godot front faces use CW.
# Keep every position; only reorder corners and average normals within 12 degrees.
const SMOOTH_COS := 0.9781476

static func arrays(vertices:PackedVector3Array)->Array:
	var faces:=PackedVector3Array()
	var corner_weights:=PackedFloat32Array()
	var adjacent:Dictionary={}
	for i in range(0,vertices.size(),3):
		var n:Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
		faces.append(n)
		for j in range(3):
			var index:=i+j
			var a:Vector3=vertices[i+(j+1)%3]-vertices[index]
			var b:Vector3=vertices[i+(j+2)%3]-vertices[index]
			corner_weights.append(a.angle_to(b) if a.length_squared()>0 and b.length_squared()>0 else 0.0)
			var key:=Vector3i((vertices[index]*100000000.0).round())
			if not adjacent.has(key):adjacent[key]=[]
			adjacent[key].append(index)
	var normals:=PackedVector3Array()
	var ordered:=PackedVector3Array()
	for i in range(0,vertices.size(),3):
		var normal:Vector3=faces[i/3]
		for j in [0,2,1]:
			var index:int=i+j
			var key:=Vector3i((vertices[index]*100000000.0).round())
			var sum:=Vector3.ZERO
			for other:int in adjacent[key]:
				var candidate:Vector3=faces[other/3]
				if candidate.dot(normal)>=SMOOTH_COS:sum+=candidate*corner_weights[other]
			normals.append(sum.normalized() if sum.length_squared()>0 else normal)
			ordered.append(vertices[index])
	var result:=[];result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX]=ordered;result[Mesh.ARRAY_NORMAL]=normals
	return result
