shader_type canvas_item;

uniform vec4 color_1 : source_color = vec4(0.573, 0.459, 0.282, 1.0);
uniform vec4 color_2 : source_color = vec4(0.310, 0.475, 0.255, 1.0);
uniform vec4 color_3 : source_color = vec4(0.212, 0.361, 0.345, 1.0);
uniform vec4 color_4 : source_color = vec4(0.231, 0.271, 0.361, 1.0);
uniform vec4 color_5 : source_color = vec4(0.416, 0.353, 0.212, 1.0);
uniform vec4 color_6 : source_color = vec4(0.486, 0.224, 0.192, 1.0);
uniform vec4 color_7 : source_color = vec4(0.357, 0.231, 0.361, 1.0);
uniform vec4 color_8 : source_color = vec4(0.157, 0.196, 0.275, 1.0);
     
uniform float terrain_start : hint_range(-10000, 0)   = 0.0;
uniform float terrain_end   : hint_range(0, 20000)    = 10000.0;

// Weltposition vom vertex() an fragment() übergeben
varying float world_x;

void vertex() {
    world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}

void fragment() {
    float t = clamp((world_x - terrain_start) / (terrain_end - terrain_start), 0.0, 1.0);

    if      (t < 0.165) COLOR = mix(color_1, color_2, t / 0.165);
    else if (t < 0.312) COLOR = mix(color_2, color_3, (t - 0.165) / (0.312 - 0.165));
    else if (t < 0.454) COLOR = mix(color_3, color_4, (t - 0.312) / (0.454 - 0.312));
    else if (t < 0.609) COLOR = mix(color_4, color_5, (t - 0.454) / (0.609 - 0.454));
    else if (t < 0.780) COLOR = mix(color_5, color_6, (t - 0.609) / (0.780 - 0.609));
    else if (t < 0.895) COLOR = mix(color_6, color_7, (t - 0.780) / (0.895 - 0.780));
    else                COLOR = mix(color_7, color_8, (t - 0.895) / (1.000 - 0.895));
}