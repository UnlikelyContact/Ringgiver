// The overworld's ground and water, painted from MapArt's field texture.
// The node it is on draws in leagues (MapCanvas moves and scales it), so
// VERTEX is a point on the map. Plain GLSL ES 3.0: it must run under the
// compatibility renderer on a phone.
shader_type canvas_item;

uniform sampler2D field : filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec2 origin = vec2(-58.0, -14.0);
uniform vec2 cells = vec2(180.0, 140.0);
uniform float near_range = 4.0;
// 0 at midsummer, 1 when the summer is spent: the low land browns.
uniform float season = 0.0;

// The land: parchment greens to ochre, fell and bare stone above, snow.
const vec3 LOW_GREEN = vec3(0.573, 0.612, 0.408);
const vec3 LOW_OCHRE = vec3(0.757, 0.678, 0.455);
const vec3 AUTUMN = vec3(0.722, 0.553, 0.333);
const vec3 SAND = vec3(0.812, 0.749, 0.580);
const vec3 FELL = vec3(0.596, 0.553, 0.443);
const vec3 STONE = vec3(0.733, 0.710, 0.659);
const vec3 SNOW = vec3(0.945, 0.937, 0.910);
const vec3 WOOD = vec3(0.294, 0.384, 0.239);
// The water: pale shallows, cold blue-green, the deep.
const vec3 SHALLOW = vec3(0.388, 0.588, 0.584);
const vec3 SEA = vec3(0.157, 0.341, 0.396);
const vec3 DEEP = vec3(0.075, 0.176, 0.243);
const vec3 INK = vec3(0.165, 0.129, 0.094);
const vec3 BEYOND = vec3(0.090, 0.110, 0.125);

varying vec2 world;

void vertex() {
	world = VERTEX;
}

// A line `w` pixels wide at distance d (leagues) from it, `px` leagues a pixel.
float line(float d, float w, float px) {
	return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, abs(d) / px);
}

void fragment() {
	float px = max(fwidth(world.x), 1e-4);
	vec2 field_size = vec2(textureSize(field, 0));
	vec2 uv = ((world - origin) * 2.0 + 0.5) / field_size;
	vec4 f = texture(field, uv);
	vec4 broad = texture(noise, world / 61.0);
	vec4 mid = texture(noise, world / 9.0);
	vec4 fine = texture(noise, world / 1.7);
	// A slight wobble in the shore, well inside half a cell.
	float sd = (f.r - 0.5) * 2.0 * near_range + (mid.r - 0.5) * 0.16;
	float land_a = smoothstep(-0.6 * px, 0.6 * px, sd);

	// --- Land ---
	float h = f.g;
	vec3 low = mix(LOW_GREEN, LOW_OCHRE, smoothstep(0.3, 0.7, broad.r + (mid.b - 0.5) * 0.35));
	low *= 0.95 + 0.1 * smoothstep(0.3, 0.7, texture(noise, world / 3.3).r);
	low = mix(low, AUTUMN, season * 0.55);
	low = mix(low, SAND, (1.0 - smoothstep(0.0, 0.35, sd)) * 0.55);
	float hn = h + (mid.a - 0.5) * 0.18;
	vec3 land = mix(low, FELL, smoothstep(0.22, 0.48, hn));
	land = mix(land, STONE, smoothstep(0.62, 0.85, hn));
	land = mix(land, WOOD, f.b * (0.25 + 0.3 * fine.b));
	float relief = smoothstep(0.18, 0.6, h);
	float shade = (f.a - 0.5) * 2.0 + (mid.g - 0.5) * 1.6 * relief + (fine.g - 0.5) * 0.5 * relief;
	land *= 0.92 + 0.42 * shade;
	float snow = smoothstep(0.0, 0.025, h + (mid.a - 0.5) * 0.35 + (fine.a - 0.5) * 0.12 - 0.93);
	land = mix(land, SNOW * (0.96 + 0.12 * clamp(shade, -0.5, 0.5)), snow);
	land *= 0.93 + 0.11 * fine.b;

	// --- Water ---
	float off = max(-sd, 0.0);
	vec3 sea = mix(SHALLOW, SEA, smoothstep(0.0, 1.8, off));
	sea = mix(sea, DEEP, smoothstep(1.5, 8.0, off + (broad.g - 0.5) * 3.0));
	sea *= 0.94 + 0.10 * broad.b;
	// A slow shimmer drifting over the open water.
	float drift = texture(noise, world / 5.0 + vec2(TIME * 0.011, TIME * 0.004)).b;
	sea += vec3(0.03, 0.04, 0.04) * (drift - 0.5) * smoothstep(0.6, 2.0, off);
	// Inked water lines along the coast, as on a drawn chart; they fade
	// out when the map is far away and would only blur together.
	float near_fade = smoothstep(7.0, 13.0, 1.0 / px);
	float lines = line(off - 0.42, 1.0, px) * 0.32 + line(off - 0.95, 1.0, px) * 0.18 + line(off - 1.6, 1.0, px) * 0.09;
	sea = mix(sea, vec3(0.78, 0.86, 0.84), lines * near_fade * step(0.05, off));

	vec3 col = mix(sea, land, land_a);
	// The shore's ink.
	col = mix(col, INK, line(sd, 1.35, px) * 0.85);

	// --- The edge of the known world: a dark rope border round the map ---
	vec2 lo = origin;
	vec2 hi = origin + cells;
	vec2 outside = max(lo - world, world - hi);
	float e = max(outside.x, outside.y);
	if (e > -1.0) {
		float band = smoothstep(-0.2, 0.0, e) * (1.0 - smoothstep(2.4, 2.6, e));
		vec3 frame = vec3(0.20, 0.15, 0.10);
		// Two strands twisting round each other along the band.
		float along = (outside.x > outside.y) ? world.y : world.x;
		float mid_band = e - 1.1;
		float s1 = abs(mid_band - 0.55 * sin(along * 1.6));
		float s2 = abs(mid_band + 0.55 * sin(along * 1.6));
		float strand = max(1.0 - smoothstep(0.12, 0.12 + px * 1.5, s1), 1.0 - smoothstep(0.12, 0.12 + px * 1.5, s2));
		frame = mix(frame, vec3(0.76, 0.64, 0.38), strand * 0.85);
		frame = mix(frame, INK, line(e - 0.0, 1.5, px) + line(e - 2.3, 1.5, px));
		col = mix(col, frame, band);
		col = mix(col, BEYOND * (0.9 + 0.2 * broad.r), smoothstep(2.4, 2.6, e));
	}
	COLOR = vec4(col, 1.0);
}
