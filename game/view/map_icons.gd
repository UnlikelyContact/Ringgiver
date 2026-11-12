class_name MapIcons
extends RefCounted
## The small drawn things on the overworld, in screen pixels about a
## point: the places by their kind, ships, the band's banner, the tokens
## of others abroad, the compass. Each takes the CanvasItem to draw on and
## a scale `k` (1 is the size at a middling zoom). Ink outlines, flat
## colour, light from the north-west, as the rest of the map.

const INK := Color("2a2118")
const SHADOW := Color(0.08, 0.06, 0.04, 0.35)
const TURF := Color("8a8f52")
const TURF_DARK := Color("4f5531")
const THATCH := Color("b39058")
const STONE := Color("c9c2b0")
const STONE_DARK := Color("8d8676")
const WALL := Color("5c4330")


static func _poly(ci: CanvasItem, at: Vector2, k: float, pts: Array, fill: Color, ink := INK, ink_w := 1.2) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(at + v * k)
	ci.draw_colored_polygon(p, fill)
	if ink.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, ink, ink_w, true)


static func _ellipse(ci: CanvasItem, at: Vector2, r: Vector2, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		p.append(at + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(p, col)


## A soft shadow on the ground under a glyph.
static func ground(ci: CanvasItem, at: Vector2, k: float, w := 11.0) -> void:
	_ellipse(ci, at + Vector2(1.5, 3.5) * k, Vector2(w, w * 0.42) * k, SHADOW)


## A small turf-roofed house, its gable toward the viewer's left.
static func house(ci: CanvasItem, at: Vector2, k: float, roof := TURF, wall := WALL) -> void:
	var ink := Color(INK, 0.8)
	_poly(ci, at, k, [Vector2(-4, 0), Vector2(4, 0), Vector2(4, -3), Vector2(-4, -3)], wall, ink, 0.9)
	_poly(ci, at, k, [Vector2(-5, -2.5), Vector2(5, -2.5), Vector2(3.5, -6.5), Vector2(-3.5, -6.5)], roof, ink, 0.9)
	ci.draw_line(at + Vector2(-3.5, -6.2) * k, at + Vector2(3.5, -6.2) * k, Color(1, 0.95, 0.8, 0.35), 1.0)


## The hall: a long, boat-backed house with crossed gable boards.
static func hall(ci: CanvasItem, at: Vector2, k: float) -> void:
	ground(ci, at, k, 13.0)
	_poly(ci, at, k, [Vector2(-10, 3), Vector2(10, 3), Vector2(10, -2), Vector2(-10, -2)], WALL)
	ci.draw_rect(Rect2(at + Vector2(-1.5, -1) * k, Vector2(3, 4) * k), INK)
	var roof := [Vector2(-12, -1), Vector2(-9, -8), Vector2(-4, -9.2), Vector2(0, -9.5), Vector2(4, -9.2),
			Vector2(9, -8), Vector2(12, -1), Vector2(0, -1.5)]
	_poly(ci, at, k, roof, THATCH)
	ci.draw_line(at + Vector2(-8, -6) * k, at + Vector2(8, -6) * k, Color(INK, 0.35), 1.0)
	ci.draw_line(at + Vector2(-9, -8) * k, at + Vector2(-12, -12) * k, INK, 1.6)
	ci.draw_line(at + Vector2(-9, -8) * k, at + Vector2(-6, -12) * k, INK, 1.6)
	ci.draw_line(at + Vector2(9, -8) * k, at + Vector2(12, -12) * k, INK, 1.6)
	ci.draw_line(at + Vector2(9, -8) * k, at + Vector2(6, -12) * k, INK, 1.6)


## A farm hamlet: three small houses.
static func hamlet(ci: CanvasItem, at: Vector2, k: float) -> void:
	ground(ci, at, k, 10.0)
	house(ci, at + Vector2(-5, -1.5) * k, k * 1.1, THATCH, Color("8a6a46"))
	house(ci, at + Vector2(5.5, -3) * k, k * 0.95, TURF, Color("8a6a46"))
	house(ci, at + Vector2(1, 5) * k, k * 1.0, Color("c29d62"), Color("8a6a46"))


## A market town: roofs close together within a palisade, a jetty out to
## the water at `water` (a unit vector, or zero).
static func town(ci: CanvasItem, at: Vector2, k: float, water: Vector2) -> void:
	if water != Vector2.ZERO:
		var a := at + water * 7.0 * k
		var b := at + water * 17.0 * k
		ci.draw_line(a, b, INK, 4.2 * k)
		ci.draw_line(a, b, Color("9b7b52"), 2.6 * k)
		var side := water.orthogonal() * 2.6 * k
		for t in [0.45, 1.0]:
			var p := a.lerp(b, t)
			ci.draw_circle(p + side, 1.1 * k, INK)
			ci.draw_circle(p - side, 1.1 * k, INK)
	ground(ci, at, k, 13.0)
	_ellipse(ci, at + Vector2(0, 1) * k, Vector2(12, 9) * k, Color("a99a6c"))
	for i in 22:
		var a := TAU * i / 22.0
		var p := at + Vector2(cos(a) * 12.0, sin(a) * 9.0 + 1.0) * k
		ci.draw_line(p + Vector2(0, 1) * k, p + Vector2(0, -2.5) * k, INK, 2.4 * k)
		ci.draw_line(p + Vector2(0, 0.5) * k, p + Vector2(0, -2.0) * k, Color("9b7b52"), 1.2 * k)
	house(ci, at + Vector2(-5, -2) * k, k * 0.95, THATCH)
	house(ci, at + Vector2(4, -4) * k, k * 0.85, THATCH)
	house(ci, at + Vector2(5, 4) * k, k * 0.9, TURF)
	house(ci, at + Vector2(-3, 5) * k, k * 0.85, THATCH)


## A Thing-stead: a ring of standing stones on the green.
static func thing(ci: CanvasItem, at: Vector2, k: float) -> void:
	ground(ci, at, k, 12.0)
	_ellipse(ci, at + Vector2(0, 1) * k, Vector2(12, 7.5) * k, Color("9aa060"))
	_ellipse(ci, at + Vector2(0, 1) * k, Vector2(3.5, 2.2) * k, STONE)
	for i in 7:
		var a := TAU * i / 7.0 - PI / 2.0
		var p := at + Vector2(cos(a) * 10.0, sin(a) * 6.0 + 1.0) * k
		_poly(ci, p, k, [Vector2(-1.8, 1.2), Vector2(1.8, 1.2), Vector2(1.4, -4.2), Vector2(-1.4, -4.8)], Color("e2dccb"), INK, 1.1)


## A bay where ships lie: an anchor.
static func bay(ci: CanvasItem, at: Vector2, k: float) -> void:
	var col := Color("d9d1bd")
	for pass_i in 2:
		var c := INK if pass_i == 0 else col
		var w := (3.4 if pass_i == 0 else 1.6) * k
		ci.draw_line(at + Vector2(0, -6) * k, at + Vector2(0, 6) * k, c, w)
		ci.draw_line(at + Vector2(-3.5, -3) * k, at + Vector2(3.5, -3) * k, c, w)
		ci.draw_arc(at + Vector2(0, 1) * k, 5.5 * k, 0.15 * PI, 0.85 * PI, 10, c, w)
		ci.draw_arc(at + Vector2(0, -7.5) * k, 1.8 * k, 0, TAU, 10, c, w * 0.8)


## A stronghold: a stake-ring with a tower.
static func fort(ci: CanvasItem, at: Vector2, k: float) -> void:
	ground(ci, at, k, 11.0)
	for i in 14:
		var a := TAU * i / 14.0
		var p := at + Vector2(cos(a) * 9.0, sin(a) * 6.0) * k
		ci.draw_line(p, p + Vector2(0, -4) * k, WALL, 2.2 * k)
	house(ci, at, k, THATCH)


## A church of the Christ-folk: stone nave, a tower and its cross. With
## `cloister` it stands alone in a walled close (a monastery); otherwise
## among small houses (a foreign town).
static func church(ci: CanvasItem, at: Vector2, k: float, cloister: bool) -> void:
	ground(ci, at, k, 12.0)
	if cloister:
		ci.draw_arc(at + Vector2(0, 1) * k, 11.0 * k, 0, TAU, 24, Color(STONE_DARK, 0.9), 2.0 * k)
	else:
		house(ci, at + Vector2(-8, 3) * k, k * 0.7, THATCH)
		house(ci, at + Vector2(8, 4) * k, k * 0.7, THATCH)
	_poly(ci, at, k, [Vector2(-6, 3), Vector2(4, 3), Vector2(4, -3), Vector2(-6, -3)], STONE)
	_poly(ci, at, k, [Vector2(-7, -2.5), Vector2(4.5, -2.5), Vector2(3, -6), Vector2(-5.5, -6)], Color("8a5a40"))
	_poly(ci, at, k, [Vector2(3, 3), Vector2(8, 3), Vector2(8, -8), Vector2(3, -8)], STONE)
	_poly(ci, at, k, [Vector2(2.5, -7.5), Vector2(8.5, -7.5), Vector2(5.5, -11)], Color("8a5a40"))
	ci.draw_line(at + Vector2(5.5, -11) * k, at + Vector2(5.5, -16) * k, INK, 1.4)
	ci.draw_line(at + Vector2(3.5, -14.3) * k, at + Vector2(7.5, -14.3) * k, INK, 1.4)


## A longship side-on, prow toward `facing` (+1 east, -1 west). `sail`
## null-coloured (alpha 0) draws her with the sail furled and the mast
## down, as she lies beached.
static func ship(ci: CanvasItem, at: Vector2, k: float, facing: float, hull: Color, sail: Color, stripe: Color, shields := Color(0, 0, 0, 0)) -> void:
	var f := Vector2(facing, 1.0)
	# The hull without her stems: the thin spikes of prow and stern made the
	# outline fail to fill at about one size in three, so they are drawn as
	# strokes after it.
	var hp := [Vector2(-13, -4), Vector2(-9, -1), Vector2(9, -1), Vector2(13.5, -4), Vector2(10, 2), Vector2(4, 3.6),
			Vector2(-4, 3.6), Vector2(-10, 2)]
	var pts := []
	for v in hp:
		pts.append(v * f)
	_ellipse(ci, at + Vector2(0, 3.5) * k, Vector2(14, 2.2) * k, Color(0.03, 0.06, 0.08, 0.35))
	if sail.a > 0.0:
		ci.draw_line(at + Vector2(0, -1) * k, at + Vector2(0, -21) * k, INK, 2.0 * k)
		var sp := [Vector2(-8, -19), Vector2(8, -19), Vector2(8.5, -8), Vector2(0, -6.2), Vector2(-8.5, -8)]
		var sv := []
		for v in sp:
			sv.append(v * f + Vector2(1.0 * facing, 0))
		_poly(ci, at, k, sv, sail, INK, 1.2)
		if stripe.a > 0.0:
			for x in [-4.5, 0.0, 4.5]:
				var top := at + (Vector2(x, -18.6) * f + Vector2(facing, 0)) * k
				var bot := at + (Vector2(x * 1.05, -7.2 + absf(x) * -0.2) * f + Vector2(facing, 0)) * k
				ci.draw_line(top, bot, stripe, 2.2 * k)
		ci.draw_line(at + Vector2(-9, -19.5) * k, at + Vector2(9, -19.5) * k, INK, 1.6 * k)
	else:
		ci.draw_line(at + Vector2(-9, -3) * k, at + Vector2(9, -4) * k, INK, 1.8 * k)
	_poly(ci, at, k, pts, hull, INK, 1.3)
	ci.draw_line(at + Vector2(12.6, -3.2) * f * k, at + Vector2(15, -8.5) * f * k, INK, 2.2 * k, true)
	ci.draw_line(at + Vector2(-12.4, -3.2) * f * k, at + Vector2(-14, -7) * f * k, INK, 2.0 * k, true)
	ci.draw_line(at + Vector2(-11, 0.5) * k, at + Vector2(11, 0.5) * k, Color(hull.lightened(0.3), 0.8), 1.0)
	if shields.a > 0.0:
		for i in 5:
			var p := at + Vector2((-7.0 + i * 3.5) * facing, -1.2) * k
			ci.draw_circle(p, 1.6 * k, shields if i % 2 == 0 else Palette.BONE)
	# The beast at the prow.
	ci.draw_circle(at + Vector2(15.0 * facing, -8.8) * k, 1.4 * k, INK)


## The band on land: a round shield and a raven banner on its staff.
static func banner(ci: CanvasItem, at: Vector2, k: float, field: Color) -> void:
	ground(ci, at, k, 9.0)
	ci.draw_line(at + Vector2(4, 2) * k, at + Vector2(4, -27) * k, INK, 2.4 * k)
	ci.draw_line(at + Vector2(4, 2) * k, at + Vector2(4, -27) * k, Color("8a6a46"), 1.2 * k)
	var flag := [Vector2(4, -26.5), Vector2(19, -24.5), Vector2(16, -21), Vector2(19, -17), Vector2(4, -15)]
	_poly(ci, at, k, flag, Palette.BONE, INK, 1.2)
	# The raven on it, a dark wedge.
	_poly(ci, at, k, [Vector2(7, -22), Vector2(12, -23.5), Vector2(14, -21), Vector2(11, -19.5), Vector2(8, -19.5)], INK, Color(0, 0, 0, 0))
	ci.draw_circle(at, 8.6 * k, INK)
	ci.draw_circle(at, 7.4 * k, Palette.BONE)
	ci.draw_circle(at, 6.2 * k, field)
	ci.draw_line(at + Vector2(-6, 0) * k, at + Vector2(6, 0) * k, Color(Palette.BONE, 0.7), 1.4 * k)
	ci.draw_line(at + Vector2(0, -6) * k, at + Vector2(0, 6) * k, Color(Palette.BONE, 0.7), 1.4 * k)
	ci.draw_circle(at, 2.2 * k, Palette.IRON)
	ci.draw_arc(at, 2.2 * k, 0, TAU, 10, INK, 1.0)


## Men on foot, not the band's: a smaller shield token.
static func token(ci: CanvasItem, at: Vector2, k: float, field: Color, rim: Color) -> void:
	ground(ci, at, k, 6.0)
	ci.draw_circle(at, 6.2 * k, INK)
	ci.draw_circle(at, 5.2 * k, rim)
	ci.draw_circle(at, 4.0 * k, field)
	ci.draw_circle(at, 1.5 * k, Palette.IRON)


## The mark of those who mean the band harm, drawn under their token: a
## red stain on the ground or the water with a red ring (an ellipse at the
## waterline for a ship), notched when they are coming for the band.
static func hostile(ci: CanvasItem, at: Vector2, r: float, chasing: bool, ship_shape := false) -> void:
	var rr := Vector2(r * 1.15, r * 0.75) if ship_shape else Vector2(r, r)
	var c := at + (Vector2(0, r * 0.45) if ship_shape else Vector2.ZERO)
	_ellipse(ci, c, rr + Vector2(3, 3), Color(Palette.BLOOD, 0.28))
	var p := PackedVector2Array()
	for i in 29:
		var a := TAU * i / 28.0
		p.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	ci.draw_polyline(p, Color(INK, 0.6), 4.0, true)
	ci.draw_polyline(p, Palette.BLOOD, 2.2, true)
	if chasing:
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			var d := Vector2(cos(a) * rr.x, sin(a) * rr.y)
			ci.draw_line(c + d * 1.15, c + d * 1.6, Color(INK, 0.6), 4.0)
			ci.draw_line(c + d * 1.15, c + d * 1.6, Palette.BLOOD, 2.2)


## A flag on a pole: where the band is going.
static func flag(ci: CanvasItem, at: Vector2, k: float) -> void:
	_ellipse(ci, at + Vector2(0, 1) * k, Vector2(4, 1.6) * k, SHADOW)
	ci.draw_line(at, at + Vector2(0, -18) * k, INK, 2.0 * k)
	_poly(ci, at, k, [Vector2(0, -18), Vector2(11, -15), Vector2(0, -11)], Palette.GOLD, INK, 1.1)


## A compass rose, north up, `r` pixels across the points.
static func compass(ci: CanvasItem, at: Vector2, r: float, font: Font) -> void:
	var paper := Color("e4dccb")
	ci.draw_circle(at, r * 0.72, Color(0.08, 0.07, 0.06, 0.45))
	ci.draw_arc(at, r * 0.62, 0, TAU, 32, Color(paper, 0.8), 1.2, true)
	ci.draw_arc(at, r * 0.5, 0, TAU, 32, Color(paper, 0.45), 1.0, true)
	for i in 8:
		var a := TAU * i / 8.0 - PI / 2.0
		var long := i % 2 == 0
		var len := r if long else r * 0.62
		var d := Vector2(cos(a), sin(a))
		var side := d.orthogonal() * (r * (0.17 if long else 0.12))
		var tip := at + d * len
		ci.draw_colored_polygon(PackedVector2Array([at, tip, at + side]), paper if long else Color(paper, 0.8))
		ci.draw_colored_polygon(PackedVector2Array([at, tip, at - side]), Color("8b2a24") if i == 0 else Color(INK, 0.95))
		ci.draw_polyline(PackedVector2Array([at + side, tip, at - side]), INK, 1.0, true)
	ci.draw_string_outline(font, at + Vector2(-4, -r - 3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.08, 0.06, 0.04, 0.8))
	ci.draw_string(font, at + Vector2(-4, -r - 3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, paper)
