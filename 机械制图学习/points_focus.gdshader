shader_type canvas_item;
uniform vec2 logical_size;
uniform vec4 focus_regions[16];
uniform int focus_count = 0;

void fragment() {
    vec2 p = UV * logical_size;
    float distance = 100000.0;
    for (int i = 0; i < 16; i++) {
        if (i >= focus_count) { break; }
        vec4 r = focus_regions[i];
        float radius = min(18.0, min(r.z, r.w) * 0.5);
        vec2 q = abs(p - (r.xy + r.zw * 0.5)) - (r.zw * 0.5 - vec2(radius));
        float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
        distance = min(distance, d);
    }
    COLOR = vec4(0.035, 0.075, 0.11, 0.12 * smoothstep(0.0, 14.0, distance));
}
