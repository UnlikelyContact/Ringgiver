class_name UiOrnament
extends Control
## The interface's few drawn ornaments (docs/design/notes/ui.md), each drawn
## once when its size changes and never again on its own: a plain gold rule,
## a rule with a knot at its middle, a band of two-strand interlace, and
## the title's arm-ring, and pips (a way's steps). `corners` is for any
## panel's draw signal.

enum Kind { RULE, KNOT_RULE, INTERLACE, RING, PIPS }

var kind: Kind = Kind.RULE
var color := Palette.UI_RULE
## PIPS: `filled` of `count` small diamonds (a way's steps taken).
var count := 3
var filled := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	match kind:
		Kind.RULE:
			var y := floorf(size.y / 2.0) + 0.5
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(color, 0.7), 1.0)
		Kind.KNOT_RULE:
			_knot_rule()
		Kind.INTERLACE:
			_interlace(Rect2(Vector2.ZERO, size))
		Kind.RING:
			_ring()
		Kind.PIPS:
			_pips()


func _pips() -> void:
	var d := minf(size.y * 0.42, 7.0)
	var step := d * 2.6
	var x := size.x - step * count + step / 2.0
	var y := size.y / 2.0
	for i in count:
		var o := Vector2(x + i * step, y)
		var pts := PackedVector2Array([o + Vector2(-d, 0), o + Vector2(0, -d), o + Vector2(d, 0), o + Vector2(0, d)])
		if i < filled:
			draw_colored_polygon(pts, Palette.UI_GOLD)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Palette.UI_RULE, 1.3, true)


## A rule that thins toward its ends with a small diamond knot at its
## middle.
func _knot_rule() -> void:
	var y := floorf(size.y / 2.0) + 0.5
	var mid := size.x / 2.0
	var d := 5.0
	var c := Color(color, 0.85)
	draw_line(Vector2(0, y), Vector2(mid - d * 2.2, y), Color(color, 0.5), 1.0)
	draw_line(Vector2(mid + d * 2.2, y), Vector2(size.x, y), Color(color, 0.5), 1.0)
	var o := Vector2(mid, y)
	var pts := PackedVector2Array([o + Vector2(-d * 1.6, 0), o + Vector2(0, -d), o + Vector2(d * 1.6, 0), o + Vector2(0, d), o + Vector2(-d * 1.6, 0)])
	draw_polyline(pts, c, 1.2, true)
	draw_circle(o, 1.6, Palette.UI_GOLD)


## Two strands crossing over and under along the band.
func _interlace(r: Rect2) -> void:
	var amp := r.size.y * 0.32
	var mid := r.position.y + r.size.y / 2.0
	var period := r.size.y * 2.2
	var n := int(r.size.x / 3.0) + 1
	for strand in 2:
		var pts := PackedVector2Array()
		for i in n + 1:
			var x := r.position.x + r.size.x * i / n
			var ph := (x - r.position.x) / period * TAU + (PI if strand == 1 else 0.0)
			pts.append(Vector2(x, mid + sin(ph) * amp))
		draw_polyline(pts, Color("0d0a07"), 4.0, true)
		draw_polyline(pts, color, 2.0, true)


## The title's motif: an open arm-ring of two twisted gold strands, its ends
## two round knobs facing across the gap, like the rings a lord gave his men.
func _ring() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.38
	var amp := r * 0.075
	var twists := 14.0
	var gap := 0.42  # radians open at the bottom
	var a0 := PI / 2.0 + gap / 2.0
	var a1 := PI / 2.0 + TAU - gap / 2.0
	var n := 220
	var dark := Color("120d08")
	var gold := Palette.UI_GOLD
	var deep := Palette.UI_GOLD_DEEP
	# A faint halo, as of firelight on it.
	for i in 4:
		draw_arc(c, r, 0, TAU, 96, Color(Palette.UI_EMBER, 0.025), amp * 4.0 + i * 6.0, true)
	var strands: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		var tw := sin((a - a0) * twists)
		strands[0].append(c + Vector2(cos(a), sin(a)) * (r + amp * tw))
		strands[1].append(c + Vector2(cos(a), sin(a)) * (r - amp * tw))
	# Under-strokes, then each strand in pieces, the one on top changing at
	# every crossing: the twist.
	for s in strands:
		draw_polyline(s, dark, 9.0, true)
	var seg := n / int(twists * (a1 - a0) / PI)
	seg = maxi(seg, 2)
	for k in range(0, n, seg):
		var hi := mini(k + seg, n)
		var top := (k / seg) % 2
		for s_i in [1 - top, top]:
			var piece := strands[s_i].slice(k, hi + 1)
			draw_polyline(piece, dark, 7.5, true)
			draw_polyline(piece, deep if s_i != top else gold, 4.5, true)
			draw_polyline(piece, Color(1, 0.95, 0.8, 0.35), 1.2, true)
	# The ends: two round knobs facing across the gap.
	for a in [a0, a1]:
		var p := c + Vector2(cos(a), sin(a)) * r
		draw_circle(p, amp * 2.6, dark)
		draw_circle(p, amp * 1.9, gold)
		draw_circle(p + Vector2(-0.3, -0.4) * amp, amp * 0.8, Color(1, 0.95, 0.8, 0.45))


## Gold brackets at the four corners of `r` on `ci`: an L at each, `len`
## long.
static func corners(ci: CanvasItem, r: Rect2, color: Color, len := 14.0) -> void:
	var w := 2.0
	var i := 3.0
	var tl := r.position + Vector2(i, i)
	var br := r.end - Vector2(i, i)
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	for p in [[tl, Vector2(1, 0), Vector2(0, 1)], [tr, Vector2(-1, 0), Vector2(0, 1)], [bl, Vector2(1, 0), Vector2(0, -1)], [br, Vector2(-1, 0), Vector2(0, -1)]]:
		var o: Vector2 = p[0]
		ci.draw_polyline(PackedVector2Array([o + p[1] * len, o, o + p[2] * len]), color, w)
		ci.draw_circle(o + (p[1] + p[2]) * 4.0, 1.4, color)
