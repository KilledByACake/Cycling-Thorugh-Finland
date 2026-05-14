shader_type canvas_item;
render_mode unshaded;

uniform vec4 col_left  : source_color = vec4(0.30, 0.75, 0.20, 1.0);
uniform vec4 col_mid   : source_color = vec4(0.90, 0.85, 0.40, 1.0);
uniform vec4 col_right : source_color = vec4(0.90, 0.25, 0.15, 1.0);

uniform float corner_px = 24.0;
uniform vec2 rect_size = vec2(600.0, 48.0);

void fragment() {
    float t = clamp(UV.x, 0.0, 1.0);
    vec3 c = mix(col_left.rgb, col_mid.rgb, smoothstep(0.0, 0.5, t));
    c = mix(c, col_right.rgb, smoothstep(0.5, 1.0, t));

    vec2 p = UV * rect_size - rect_size * 0.5;
    vec2 half_size = rect_size * 0.5 - vec2(corner_px);
    vec2 d = abs(p) - half_size;
    float dist = length(max(d, vec2(0.0))) - corner_px;

    float aa = max(fwidth(dist), 1.0);
    float alpha = smoothstep(0.0, aa, -dist);

    COLOR = vec4(c, alpha);
}