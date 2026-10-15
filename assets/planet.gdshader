shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_map : source_color, repeat_enable, filter_linear_mipmap;
uniform float animation_time = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.17, 0.31, 0.53));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(cell), hash(cell + vec3(1, 0, 0)), f.x),
			mix(hash(cell + vec3(0, 1, 0)), hash(cell + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(cell + vec3(0, 0, 1)), hash(cell + vec3(1, 0, 1)), f.x),
			mix(hash(cell + vec3(0, 1, 1)), hash(cell + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float cloud_noise(vec3 p) {
	float result = 0.0;
	float amplitude = 0.52;
	for (int i = 0; i < 5; i++) {
		result += noise(p) * amplitude;
		p = p * 2.03 + vec3(7.3, 1.9, 4.1);
		amplitude *= 0.48;
	}
	return result;
}

vec3 turn(vec3 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

void fragment() {
	// Render an actual spherical projection, with room outside for the atmosphere.
	vec2 p = (UV - vec2(0.5)) * 2.4;
	float distance_from_center = length(p);
	vec3 light_direction = normalize(vec3(-0.65, 0.55, 0.85));
	vec3 color = vec3(0.0);
	float alpha = 0.0;
	if (distance_from_center <= 1.0) {
		vec3 normal = vec3(p.x, -p.y, sqrt(max(0.0, 1.0 - dot(p, p))));
		// A slight axial tilt gives the globe a natural orientation.
		vec3 tilted = vec3(normal.x * 0.98 - normal.y * 0.20,
			normal.x * 0.20 + normal.y * 0.98, normal.z);
		vec3 surface = turn(tilted, animation_time * 0.11 + 0.55);
		vec2 map_uv = vec2(atan(surface.x, surface.z) / TAU + 0.5,
			0.5 - asin(clamp(surface.y, -1.0, 1.0)) / PI);
		vec3 albedo = texture(surface_map, map_uv).rgb;
		float sunlight = max(dot(normal, light_direction), 0.0);
		float daylight = smoothstep(-0.12, 0.32, dot(normal, light_direction));
		vec3 clouds_domain = turn(tilted, animation_time * 0.135 + 0.55);
		// Clouds move independently of the continents; 3D noise avoids a longitude seam.
		float clouds = smoothstep(0.48, 0.69,
			cloud_noise(clouds_domain * vec3(5.0, 7.5, 5.0) + vec3(0, 0, 3.0)));
		float cloud_shadow = smoothstep(0.49, 0.68,
			cloud_noise((clouds_domain + vec3(0.018, -0.012, 0)) * vec3(5, 7.5, 5) + vec3(0, 0, 3)));
		albedo *= 1.0 - cloud_shadow * 0.22;
		color = albedo * (0.065 + 1.15 * sunlight);
		float ocean = smoothstep(0.02, 0.12, albedo.b - albedo.r) *
			(1.0 - smoothstep(0.26, 0.55, albedo.r + albedo.g));
		vec3 half_vector = normalize(light_direction + vec3(0, 0, 1));
		float glint = pow(max(dot(normal, half_vector), 0.0), 55.0);
		color += vec3(0.55, 0.75, 0.9) * glint * ocean * 0.42;
		color = mix(color, vec3(0.9, 0.94, 1.0) * (0.12 + sunlight), clouds * 0.82);
		float rim = pow(1.0 - normal.z, 3.5);
		color += vec3(0.13, 0.47, 0.96) * rim * (0.12 + daylight * 0.5);
		color += vec3(0.01, 0.018, 0.05) * (1.0 - daylight);
		alpha = 1.0 - smoothstep(0.992, 1.0, distance_from_center);
	} else {
		float atmosphere = exp(-(distance_from_center - 1.0) * 32.0);
		float lit_edge = 0.4 + 0.6 * max(dot(normalize(vec3(p.x, -p.y, 0.2)), light_direction), 0.0);
		color = vec3(0.11, 0.42, 1.0);
		alpha = atmosphere * lit_edge * 0.40;
	}
	COLOR = vec4(color, alpha);
}
