shader_type canvas_item;

void fragment() {
	float y = UV.x; // Vertikaler Verlauf
	vec3 final_color;

	// Definition der Farben aus grafik.png
	//vec3 c0 = vec3(0.314, 0.396, 0.494); // 0%   (#50657E)
	vec3 c1 = vec3(0.502, 0.753, 1.000); // 12%  (#80C0FF)
	vec3 c2 = vec3(0.239, 0.706, 1.000); // 24%  (#3DB4FF)
	vec3 c3 = vec3(0.231, 0.639, 1.000); // 39%  (#3BA3FF)
	vec3 c4 = vec3(0.729, 0.651, 0.404); // 52%  (#BBA867)
	vec3 c5 = vec3(0.545, 0.298, 0.349); // 66%  (#8B4C59)
	vec3 c6 = vec3(0.424, 0.286, 0.431); // 82%  (#6C496E)
	vec3 c7 = vec3(0.157, 0.196, 0.275); // 98%  (#283246)

	// Interpolations-Logik 
	//if (y < 0.24) {
		//final_color = mix(c1, c2, smoothstep(0.12, 0.24, y));
	//} else
	 if (y < 0.39) {
		final_color = mix(c2, c3, smoothstep(0.0, 0.39, y));
	} else if (y < 0.60) {
		final_color = mix(c3, c4, smoothstep(0.39, 0.60, y));
	} else if (y < 0.80) {
		final_color = mix(c4, c5, smoothstep(0.60, 0.80, y));
	} else if (y < 0.89) {
		final_color = mix(c5, c6, smoothstep(0.80, 0.89, y));
	} else {
		final_color = mix(c6, c7, smoothstep(0.89, 1.0, y));
	}

	COLOR = vec4(final_color, 1.0);
}