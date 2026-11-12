// The waves on the open sea: each stroke rises and fades on its own slow
// beat (its phase in UV.x) and drifts a little, so the water lives without
// the map being drawn again.
shader_type canvas_item;

varying float glow;

void vertex() {
	float ph = UV.x * 6.2832;
	glow = 0.35 + 0.65 * (0.5 + 0.5 * sin(TIME * 0.7 + ph));
	VERTEX.x += sin(TIME * 0.35 + ph) * 0.08;
	VERTEX.y += cos(TIME * 0.5 + ph) * 0.03;
}

void fragment() {
	COLOR.a *= glow;
}
