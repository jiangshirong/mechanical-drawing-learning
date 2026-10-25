extends RefCounted
# Engineering edges retain depth testing, with pixel-sized strokes and a small
# view-space offset to avoid competing with their own coplanar material surface.
static var opaque_shader: Shader
static var fade_shader: Shader

static func shader_for(transparent: bool) -> Shader:
	if opaque_shader == null:
		var source := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
uniform vec4 line_color : source_color = vec4(1.0);
uniform float width_pixels = 1.4;
void vertex() {
    vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 direction = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    view.z += 0.00008;
    vec4 clip = PROJECTION_MATRIX * view;
    vec4 next_clip = PROJECTION_MATRIX * vec4(view.xyz + direction * 0.001, 1.0);
    vec2 delta = (next_clip.xy / next_clip.w - clip.xy / clip.w) * VIEWPORT_SIZE;
    vec2 along = length(delta) > 0.00001 ? normalize(delta) : vec2(1.0, 0.0);
    vec2 perpendicular = vec2(-along.y, along.x);
    clip.xy += (perpendicular * UV.x + along * UV.y) * width_pixels / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
}
void fragment() {
    ALBEDO = line_color.rgb;
}
"""
		opaque_shader = Shader.new()
		opaque_shader.code = source
		fade_shader = Shader.new()
		fade_shader.code = source.replace("skip_vertex_transform;", "skip_vertex_transform, depth_draw_never;").replace("ALBEDO = line_color.rgb;", "ALBEDO = line_color.rgb; ALPHA = line_color.a;")
	return fade_shader if transparent else opaque_shader

static func make(pairs: Array, color: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var directions := PackedVector3Array()
	var sides := PackedVector2Array()
	for pair in pairs:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		if a.distance_squared_to(b) < 0.000000000001: continue
		var direction := (b-a).normalized()
		for uv in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
			vertices.append(a if uv.y < 0 else b)
			directions.append(direction)
			sides.append(uv)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = directions
	arrays[Mesh.ARRAY_TEX_UV] = sides
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.extra_cull_margin = 0.003
	var material := ShaderMaterial.new()
	material.shader = shader_for(color.a < 0.9999)
	material.set_shader_parameter("line_color",color)
	node.material_override = material
	return node
