shader_type canvas_item;

uniform vec4 color_1 : source_color = vec4(0.573, 0.459, 0.282, 1.0); // #927548 - 0%
uniform vec4 color_2 : source_color = vec4(0.310, 0.475, 0.255, 1.0); // #4F7941 - 12%
uniform vec4 color_3 : source_color = vec4(0.212, 0.361, 0.345, 1.0); // #365C58 - 21%
uniform vec4 color_4 : source_color = vec4(0.231, 0.271, 0.361, 1.0); // #3B455C - 33%
uniform vec4 color_5 : source_color = vec4(0.416, 0.353, 0.212, 1.0); // #6A5A36 - 44%
uniform vec4 color_6 : source_color = vec4(0.486, 0.224, 0.192, 1.0); // #7C3931 - 56%
uniform vec4 color_7 : source_color = vec4(0.357, 0.231, 0.361, 1.0); // #5B3B5C - 67%
uniform vec4 color_8 : source_color = vec4(0.157, 0.196, 0.275, 1.0); // #283246 - 80%
uniform vec4 color_9 : source_color = vec4(0.251, 0.424, 0.420, 1.0); // #406C6B - 91%
uniform vec4 color_10: source_color = vec4(0.573, 0.459, 0.282, 1.0); // #927548 - 100%

uniform float terrain_start : hint_range(-10000, 0)  = 0.0;
uniform float terrain_end   : hint_range(0, 2000000)   = 2000000.0; //length of the whole 
uniform float speed         : hint_range(-5.0, 5.0)  = 0.5;

varying float world_x;

void vertex() {
    world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}

void fragment() {
    float range = terrain_end - terrain_start;
    float offset = fract(TIME * speed / range * 1000.0);
    float t = fract(clamp((world_x - terrain_start) / range, 0.0, 1.0) + offset);

    if      (t < 0.12) COLOR = mix(color_1,  color_2,  t / 0.12);
    else if (t < 0.21) COLOR = mix(color_2,  color_3,  (t - 0.12) / (0.21 - 0.12));
    else if (t < 0.33) COLOR = mix(color_3,  color_4,  (t - 0.21) / (0.33 - 0.21));
    else if (t < 0.44) COLOR = mix(color_4,  color_5,  (t - 0.33) / (0.44 - 0.33));
    else if (t < 0.56) COLOR = mix(color_5,  color_6,  (t - 0.44) / (0.56 - 0.44));
    else if (t < 0.67) COLOR = mix(color_6,  color_7,  (t - 0.56) / (0.67 - 0.56));
    else if (t < 0.80) COLOR = mix(color_7,  color_8,  (t - 0.67) / (0.80 - 0.67));
    else if (t < 0.91) COLOR = mix(color_8,  color_9,  (t - 0.80) / (0.91 - 0.80));
    else               COLOR = mix(color_9,  color_10, (t - 0.91) / (1.00 - 0.91));
}