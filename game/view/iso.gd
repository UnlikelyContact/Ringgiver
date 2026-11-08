class_name Iso
extends RefCounted
## Hex projection: pointy-top hexes seen a little from above, so a line
## along a hex row reads as a line. Kept under the old class name.

const SIZE := 30.0  # hex outer radius in pixels
const SQUASH := 0.82  # vertical foreshortening for the "from above" look


static func to_screen_f(p: Vector2) -> Vector2:
	var c := BattleGrid.to_cart(p) * SIZE
	return Vector2(c.x, c.y * SQUASH)


static func to_screen(cell: Vector2i) -> Vector2:
	return to_screen_f(Vector2(cell))


## A small, fixed offset per man inside his hex, so a line stands like men
## rather than pegs.
static func jitter(id: int) -> Vector2:
	var h := (id * 2654435761) & 0xffff
	return Vector2(float(h % 9) - 4.0, float((h / 9) % 7) - 3.0) * 0.9


static func to_cell(screen: Vector2) -> Vector2i:
	var x := screen.x / SIZE
	var y := screen.y / SQUASH / SIZE
	var q := (sqrt(3.0) / 3.0 * x - 1.0 / 3.0 * y)
	var r := (2.0 / 3.0 * y)
	return _round_axial(q, r)


static func _round_axial(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## The six corners of a cell's hexagon, optionally inset.
static func hexagon(cell: Vector2i, inset := 0.0) -> PackedVector2Array:
	var c := to_screen(cell)
	var out := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)
		out.append(c + Vector2(cos(a) * (SIZE - inset), sin(a) * (SIZE - inset) * SQUASH))
	return out


## Alias kept for callers written against the square grid.
static func diamond(cell: Vector2i, inset := 0.0) -> PackedVector2Array:
	return hexagon(cell, inset)
