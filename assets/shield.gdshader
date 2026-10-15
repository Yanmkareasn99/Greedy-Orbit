shader_type canvas_item;
// Store straight-alpha color in the viewport. Blending it here and again
// over the planet would dim the glass and its glow twice.
render_mode unshaded, blend_disabled;

uniform float animation_time = 0.0;
uniform float energy : hint_range(0.0, 1.0) = 1.0;
uniform vec4 shield_tint : source_color = vec4(0.08, 0.5, 1.0, 1.0);
uniform vec2 impact_position = vec2(0.0, -0.9);
uniform float impact_age = 10.0;

float plate_hash(vec2 id) {
	return fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.24;
	float radius = length(p);
	// Project connected plates onto a sphere. Cells foreshorten naturally at
	// the silhouette instead of forming a flat honeycomb around the planet.
	float z = sqrt(max(0.0, 1.0 - dot(p, p)));
	vec3 normal = vec3(p.x, -p.y, z);
	vec3 tilted = vec3(normal.x * 0.98 - normal.y * 0.20,
		normal.x * 0.20 + normal.y * 0.98, normal.z);
	float longitude = atan(tilted.x, max(tilted.z, 0.0001)) + animation_time * 0.035;
	float latitude = asin(clamp(tilted.y, -0.995, 0.995));
	// Exactly 24 cells around the equator keeps the longitude seam connected.
	vec2 grid = vec2(longitude, latitude) * (24.0 / TAU);
	vec2 cell_size = vec2(1.0, 1.7320508);
	vec2 a = mod(grid, cell_size) - cell_size * 0.5;
	vec2 b = mod(grid - cell_size * 0.5, cell_size) - cell_size * 0.5;
	vec2 local = dot(a, a) < dot(b, b) ? a : b;
	vec2 cell_center = grid - local;
	// Integer cell IDs keep each plate solid as the sphere rotates. Hashing
	// unrounded coordinates creates glitter from tiny floating-point errors.
	vec2 cell = floor((grid - local) / vec2(0.5, 0.8660254) + vec2(0.5));
	cell.x = mod(cell.x, 48.0);
	float edge = 0.5 - max(abs(local.x), dot(abs(local), vec2(0.5, 0.8660254)));
	float antialias = max(fwidth(edge), 0.005);
	float seams = 1.0 - smoothstep(0.015, 0.040 + antialias, edge);
	float glow = 1.0 - smoothstep(0.025, 0.17, edge);
	// A soft pool of light fills the center of every hex, not just its edges.
	float interior_glow = smoothstep(0.025, 0.40, edge);
	// Blend the most compressed cells into the atmosphere to avoid shimmer.
	float surface_detail = smoothstep(0.02, 0.22, z) * (1.0 - smoothstep(0.9, 0.99, abs(tilted.y)));
	seams *= surface_detail;
	glow *= surface_detail;
	float cell_id = plate_hash(cell);
	// Each cell gets independent, changing activation times. Smooth ramps
	// reach full neon brightness, then fade without changing the glass tint.
	float period = mix(3.8, 8.0, plate_hash(cell + vec2(17.0, 3.0)));
	float clock = animation_time / period + cell_id;
	float cycle = floor(clock);
	float phase = fract(clock);
	float start = mix(0.12, 0.62, plate_hash(cell + vec2(cycle * 7.0, cycle * 11.0)));
	float enabled = step(0.3, plate_hash(cell + vec2(cycle * 13.0, 39.0)));
	float flare = smoothstep(start, start + 0.06, phase) *
		(1.0 - smoothstep(start + 0.12, start + 0.26, phase)) * enabled;
	float panel = 1.0 - seams;
	float strength = 0.35 + energy * 0.65;
	float instability = mix(0.82 + 0.18 * sin(animation_time * 1.4 + cell_id * TAU), 1.0, smoothstep(0.1, 0.5, energy));
	// Slightly faceted normals break reflections along the hexagonal plates.
	float plate_lon = cell_center.x * (TAU / 24.0) - animation_time * 0.035;
	float plate_lat = cell_center.y * (TAU / 24.0);
	vec3 face = vec3(sin(plate_lon) * cos(plate_lat), sin(plate_lat), cos(plate_lon) * cos(plate_lat));
	face = vec3(face.x * 0.98 + face.y * 0.20, -face.x * 0.20 + face.y * 0.98, face.z);
	vec3 reflection_normal = normalize(mix(normal, face, 0.30));
	vec3 view_direction = vec3(0.0, 0.0, 1.0);
	vec3 light_direction = normalize(vec3(-0.65, 0.55, 0.85));
	vec3 half_direction = normalize(light_direction + view_direction);
	float specular = pow(max(dot(reflection_normal, half_direction), 0.0), 90.0);
	vec3 reflected_view = reflect(-view_direction, reflection_normal);
	float environment = pow(max(dot(reflected_view, normalize(vec3(-0.75, 0.4, 0.5))), 0.0), 18.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - max(reflection_normal.z, 0.0), 5.0);
	float reflection = specular * 0.85 + environment * 0.35 + fresnel * 0.25;
	float hit_distance = length(p - impact_position);
	float hit_ring = exp(-abs(hit_distance - impact_age * 1.65) * 23.0) * exp(-impact_age * 3.3);
	float hit_core = exp(-hit_distance * 12.0) * exp(-impact_age * 6.0);
	float hit = clamp(hit_ring + hit_core, 0.0, 1.0);
	// Plate bodies remain about 80% transparent. Reflections and energized
	// seams brighten separately; there are no opaque white armor panels.
	float plate_alpha = 0.20 + reflection * 0.10 + interior_glow * flare * 0.06;
	float seam_alpha = seams * (0.52 + flare * 0.26 + fresnel * 0.13);
	float alpha = (plate_alpha * panel + seam_alpha + glow * (0.06 + flare * 0.13)) * strength * instability;
	alpha += hit * (0.55 + seams * 0.4);
	float inside = 1.0 - smoothstep(0.988, 1.0, radius);
	float rim = exp(-abs(radius - 0.993) * 100.0) * 0.55;
	float halo = exp(-max(0.0, radius - 1.0) * 25.0) * 0.28 * step(1.0, radius);
	alpha = clamp(alpha * inside + rim * strength + halo * strength, 0.0, 0.98);
	alpha *= step(0.001, energy);
	vec3 blue = mix(shield_tint.rgb, vec3(0.025, 0.40, 1.0), step(0.55, energy) * 0.7);
	vec3 neon = mix(blue, vec3(0.08, 0.76, 1.0), step(0.55, energy) * 0.8);
	vec3 plate_color = mix(blue * (0.60 + cell_id * 0.12), neon, 0.22 + flare * 0.78);
	plate_color += neon * interior_glow * (0.32 + flare * 0.55);
	vec3 reflection_color = mix(blue, vec3(0.42, 0.82, 1.0), step(0.55, energy) * 0.65);
	plate_color += reflection_color * reflection;
	vec3 color = mix(plate_color, neon * (0.7 + flare * 0.3), clamp(seams + glow * 0.3, 0.0, 1.0));
	color = mix(color, neon, hit * 0.9);
	color = mix(color, blue * 1.4, step(0.985, radius));
	COLOR = vec4(color, alpha);
}
