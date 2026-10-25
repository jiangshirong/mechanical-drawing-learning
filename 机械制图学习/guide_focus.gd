extends RefCounted
# Semantic focus is evaluated on the existing material surfaces. It neither
# changes the mesh nor fills the empty bores or adds hatching to the rib.
static var solid_shader: Shader
static var fade_shader: Shader

static func shader_for(fading := false) -> Shader:
	if solid_shader == null:
		var source := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 line_color : source_color = vec4(0.42,0.68,0.76,1.0);
uniform int focus_mode = 0;
uniform bool removed_half = false;
uniform vec4 rib_span = vec4(-22.0,12.0,31.0,46.0);
uniform vec2 rib_source_x = vec2(-26.0,16.0);
uniform float base_height = 15.0;
uniform float rib_half_width = 8.0;
varying vec3 position_world;
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 p = vec3(position_world.x,-position_world.z,position_world.y)*1000.0;
    float brightness = 1.0;
    bool accent = false;
    if (focus_mode == 1) { brightness = 0.34; }
    if (focus_mode == 2) { brightness = removed_half ? 1.0 : 0.42; accent = removed_half; }
    if (focus_mode == 3 || focus_mode == 4) {
        bool cut_surface = abs(p.y) < 0.16;
        brightness = cut_surface ? 1.0 : (focus_mode == 3 ? 0.35 : 0.66);
        accent = cut_surface;
    }
    if (focus_mode == 5) {
        float roof = mix(rib_span.z,rib_span.w,(p.x-rib_source_x.x)/(rib_source_x.y-rib_source_x.x));
        bool rib = p.x >= rib_span.x-0.12 && p.x <= rib_span.y+0.12 &&
                   abs(p.y) <= rib_half_width+0.12 && p.z > base_height+0.08 && p.z <= roof+0.15;
        brightness = rib ? 1.0 : 0.30;
        accent = rib;
    }
    vec3 color = accent ? vec3(1.0,0.70,0.24) : line_color.rgb;
    ALBEDO = color * brightness;
    ROUGHNESS = 0.7;
    EMISSION = accent ? color * 0.12 : vec3(0.0);
}
"""
		solid_shader = Shader.new()
		solid_shader.code = source
		fade_shader = Shader.new()
		fade_shader.code = source.replace("render_mode cull_disabled;","render_mode cull_disabled, depth_draw_never;").replace("ROUGHNESS = 0.7;","ROUGHNESS = 0.7; ALPHA = line_color.a;")
	return fade_shader if fading else solid_shader

static func install(node: Node, data: Dictionary, removed := false) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		var mat := ShaderMaterial.new()
		mat.shader = shader_for()
		mat.set_shader_parameter("line_color",node.material_override.albedo_color)
		mat.set_shader_parameter("removed_half",removed)
		var p: Dictionary = data.parameters
		var rib: Array = data.section.rib_polygon
		mat.set_shader_parameter("rib_span",Vector4(rib[0][0],rib[1][0],p.rib_start_z,p.rib_end_z))
		mat.set_shader_parameter("rib_source_x",Vector2(p.rib_start_x,p.rib_end_x))
		mat.set_shader_parameter("base_height",p.base_height)
		mat.set_shader_parameter("rib_half_width",p.rib_half_width)
		node.material_override = mat
		node.set_meta("guide_body",true)
		result.append(mat)
	for child in node.get_children(): result.append_array(install(child,data,removed))
	return result
