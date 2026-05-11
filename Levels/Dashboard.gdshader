shader_type canvas_item;
render_mode unshaded;

// Linear gradient: dark (bottom-left) → light (top-right)
uniform vec4 color_dark  : source_color = vec4(0.2196, 0.3020, 0.2157, 1.0); // #384D37
uniform vec4 color_light : source_color = vec4(0.7529, 0.7137, 0.3647, 1.0); // #C0B65D

void fragment() {
    vec2 uv = UV;
    float t = clamp(0.5 * (uv.x - uv.y + 1.0), 0.0, 1.0);
    COLOR = mix(color_dark, color_light, t);
}