shader_type canvas_item;
render_mode unshaded;

uniform vec4 color_dark  : source_color = vec4(0.18, 0.24, 0.31, 1.0);
uniform vec4 color_light : source_color = vec4(0.50, 0.74, 0.77, 1.0);

void fragment() {
    float angle = radians(-50.0);
    vec2 dir = vec2(cos(angle), sin(angle));
    float t = clamp(dot(UV - 0.5, dir) + 0.5, 0.0, 1.0);
    COLOR = mix(color_dark, color_light, t);
}