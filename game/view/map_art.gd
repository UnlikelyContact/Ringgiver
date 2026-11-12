class_name MapArt
extends RefCounted
## The overworld's painted look, built once from MapGrid and a fixed seed
## and kept for every map screen after (`for_grid`). Nothing here is drawn
## per frame: it makes the data the terrain shader (map_terrain.gdshader)
## paints from, and the meshes of the mountains, the woods and the waves,
## all in leagues so that the canvas only moves and scales them.
##
## The field texture holds, at every cell centre and every cell edge and
## corner between (2W+1 by 2H+1 samples, so that a coast that steps from
## cell to cell is cut across its corners instead):
##   R  signed distance to the shore in leagues, land positive (+-NEAR)
##   G  height of the land, or depth of the sea, 0..1
##   B  how thick the woods stand, 0..1
##   A  hill-shade lit from the north-west, 0.5 for flat ground
## A cell centre always keeps the sign of its own terrain, so what is
## painted as land is land the band can walk and what is painted as water
## is water a ship can take (test_map_art.gd holds this).

## Leagues of signed distance either side of the shore that R can hold.
const NEAR := 4.0
## Leagues from the shore at which the sea is as deep as the map shows it.
const DEPTH_FULL := 10.0
## How far in from the shore the land starts to rise, and over how many
## leagues it reaches the highest fells.
const RISE_FROM := 1.5
const RISE_OVER := 13.0
## No centre is painted nearer the shore than this, in leagues, so a fjord
## a cell wide stays open water and an isthmus a cell wide stays land.
const CENTRE_KEEP := 0.32
const ISLE_KEEP := 1.1
## Glyphs: mountains stand where the land is at least this high; woods grow
## between these heights, at least WOOD_INLAND leagues from the sea.
const PEAK_FROM := 0.40
## Fells stand on a lattice this many leagues apart: the near set for the
## close views, and a sparser set of bigger ones for the whole coast.
const PEAK_STEP := 2.0
const PEAK_STEP_FAR := 4.2
const WOOD_HIGH := 0.42
const WOOD_INLAND := 1.6
## The flats (MapGrid.flat, the Rus' forests and the steppe): the land is
## held below this, gently rolling, so no fells stand there; the forest is
## thicker than elsewhere and the steppe bare.
const FLAT_HIGH := 0.2
const FLAT_WOOD_FROM := 0.3
## The glyph meshes are cut into square tiles this many leagues across, so
## that only the tiles on screen are drawn.
const TILE := 30
const SEED := 866

const INK := Color("2a2118")

static var _cached: MapArt = null

var field: ImageTexture
## The field as an image, kept for reading back (shore_distance).
var field_image: Image
var noise: ImageTexture
## One entry a tile: {rect: Rect2 (leagues), peaks: ArrayMesh or null,
## woods: ArrayMesh or null, waves: ArrayMesh or null}.
var tiles: Array[Dictionary] = []
## Microseconds the whole build took, for the notes.
var build_usec := 0

var _grid: MapGrid
var _place_cells := {}  # cell index -> true, kept clear of glyphs
var _h := PackedFloat32Array()  # land height 0..1 at cell centres
var _wood := PackedFloat32Array()
var _dsea := PackedFloat32Array()  # land: leagues to the nearest sea centre
var _dland := PackedFloat32Array()  # sea: leagues to the nearest land centre


static func for_grid(grid: MapGrid) -> MapArt:
	if _cached == null or _cached._grid != grid:
		_cached = MapArt.new()
		_cached._build(grid)
	return _cached


func _build(grid: MapGrid) -> void:
	var t0 := Time.get_ticks_usec()
	_grid = grid
	for id in grid.place_cell:
		_place_cells[MapGrid.index(grid.place_cell[id])] = true
	_fields()
	field_image = _field_image()
	field = ImageTexture.create_from_image(field_image)
	noise = ImageTexture.create_from_image(_noise_image())
	_glyphs()
	build_usec = Time.get_ticks_usec() - t0


# --- The fields at cell centres -------------------------------------------------------

func _fields() -> void:
	var n := MapGrid.W * MapGrid.H
	var land := PackedByteArray()
	land.resize(n)
	for i in n:
		land[i] = 1 if _grid.cells[i] >= MapGrid.T.SHORE else 0
	_dsea = _chamfer(land, 0)
	_dland = _chamfer(land, 1)
	var lf := FastNoiseLite.new()
	lf.seed = SEED
	lf.frequency = 0.07
	lf.fractal_octaves = 3
	var wf := FastNoiseLite.new()
	wf.seed = SEED + 1
	wf.frequency = 0.16
	wf.fractal_octaves = 2
	_h.resize(n)
	_wood.resize(n)
	for y in MapGrid.H:
		for x in MapGrid.W:
			var i := y * MapGrid.W + x
			if land[i] == 0:
				continue
			var d: float = _dsea[i]
			var rise := clampf((d - RISE_FROM) / RISE_OVER, 0.0, 1.0)
			var wobble := lf.get_noise_2d(x, y)  # -1..1
			var h := clampf(rise * (0.74 + 0.36 * wobble) + 0.05 * wobble, 0.0, 1.0)
			# The grid's mountains are never painted as low land.
			if _grid.cells[i] == MapGrid.T.MOUNTAIN:
				h = maxf(h, 0.36 + 0.06 * wobble)
			var flat := int(_grid.flat[i])
			if flat != 0:
				h = minf(h, FLAT_HIGH + 0.06 * wobble)
			_h[i] = h
			if flat == 2:
				continue  # the steppe: grass to the sky
			if d >= WOOD_INLAND and h < WOOD_HIGH:
				var w := wf.get_noise_2d(x, y) * 0.5 + 0.5
				var from := FLAT_WOOD_FROM if flat == 1 else 0.42
				_wood[i] = clampf((w - from) * 3.2, 0.0, 1.0) * clampf((WOOD_HIGH - h) * 6.0, 0.0, 1.0)


## Leagues from every cell centre to the nearest centre of a cell whose
## `land` value is `target` (two chamfer passes, near enough to Euclid).
func _chamfer(land: PackedByteArray, target: int) -> PackedFloat32Array:
	var w := MapGrid.W
	var h := MapGrid.H
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if land[i] == target else 1.0e6
	const D := 1.41421
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - w] + 1.0)
				if x > 0:
					v = minf(v, d[i - w - 1] + D)
				if x < w - 1:
					v = minf(v, d[i - w + 1] + D)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x < w - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[i + w] + 1.0)
				if x < w - 1:
					v = minf(v, d[i + w + 1] + D)
				if x > 0:
					v = minf(v, d[i + w - 1] + D)
			d[i] = v
	return d


# --- The field texture ------------------------------------------------------------------

func _field_image() -> Image:
	var w := MapGrid.W
	var h := MapGrid.H
	var n := w * h
	# Per cell: signed distance, height-or-depth, woods; then hill-shade
	# from the height, smoothed first so the light falls on slopes, not cells.
	var sd := PackedFloat32Array()
	var g := PackedFloat32Array()
	sd.resize(n)
	g.resize(n)
	for i in n:
		if _grid.cells[i] >= MapGrid.T.SHORE:
			sd[i] = _dsea[i] - 0.5
			g[i] = _h[i]
		else:
			sd[i] = -(_dland[i] - 0.5)
			g[i] = clampf((_dland[i] - 0.5) / DEPTH_FULL, 0.0, 1.0)
	var smooth := _blur(_blur(_h, w, h), w, h)
	var shade := PackedFloat32Array()
	shade.resize(n)
	var light := Vector3(-1.0, -1.0, 1.4).normalized()
	for y in h:
		for x in w:
			var i := y * w + x
			if _grid.cells[i] < MapGrid.T.SHORE:
				shade[i] = 0.5
				continue
			var dx := smooth[mini(x + 1, w - 1) + y * w] - smooth[maxi(x - 1, 0) + y * w]
			var dy := smooth[x + mini(y + 1, h - 1) * w] - smooth[x + maxi(y - 1, 0) * w]
			var nrm := Vector3(-dx * 6.0, -dy * 6.0, 1.0).normalized()
			var flat := light.z
			shade[i] = clampf(0.5 + (nrm.dot(light) - flat) * 1.6, 0.0, 1.0)
	# Up to the half-league lattice: centres as they are, edges and corners
	# the mean of the cells they touch. A corner where land meets land only
	# across the diagonal is land: a band walks that way, and a ship may not.
	var sw := 2 * w + 1
	var sh := 2 * h + 1
	var fr := PackedFloat32Array()
	fr.resize(sw * sh)
	var fg := fr.duplicate()
	var fb := fr.duplicate()
	var fa := fr.duplicate()
	for sy in sh:
		for sx in sw:
			var x0 := clampi((sx - 1) >> 1, 0, w - 1)
			var x1 := clampi(sx >> 1, 0, w - 1)
			var y0 := clampi((sy - 1) >> 1, 0, h - 1)
			var y1 := clampi(sy >> 1, 0, h - 1)
			var a := y0 * w + x0
			var b := y0 * w + x1
			var c := y1 * w + x0
			var d := y1 * w + x1
			var j := sy * sw + sx
			var v := (sd[a] + sd[b] + sd[c] + sd[d]) * 0.25
			if (sx & 1) == 0 and (sy & 1) == 0 and x0 != x1 and y0 != y1:
				var la := sd[a] > 0.0
				var ld := sd[d] > 0.0
				var lb := sd[b] > 0.0
				var lc := sd[c] > 0.0
				if (la and ld and not lb and not lc) or (lb and lc and not la and not ld):
					v = maxf(v, 0.12)
			fr[j] = v
			fg[j] = (g[a] + g[b] + g[c] + g[d]) * 0.25
			fb[j] = (_wood[a] + _wood[b] + _wood[c] + _wood[d]) * 0.25
			fa[j] = (shade[a] + shade[b] + shade[c] + shade[d]) * 0.25
	fr = _blur(fr, sw, sh)
	fb = _blur(fb, sw, sh)
	var bytes := PackedByteArray()
	bytes.resize(sw * sh * 4)
	for cy in h:
		for cx in w:
			# Keep every centre on its own side of the shore.
			var j := (2 * cy + 1) * sw + 2 * cx + 1
			if _grid.cells[cy * w + cx] >= MapGrid.T.SHORE:
				# A lone cell of land (an isle, a skerry) is drawn a little
				# fuller than its cell, so that it reads as an island at all.
				fr[j] = maxf(fr[j], ISLE_KEEP if _dsea[cy * w + cx] <= 1.0 and _lone(cx, cy) else CENTRE_KEEP)
			else:
				fr[j] = minf(fr[j], -CENTRE_KEEP)
	for j in sw * sh:
		var k := j * 4
		bytes[k] = clampi(int(round((clampf(fr[j], -NEAR, NEAR) / (2.0 * NEAR) + 0.5) * 255.0)), 0, 255)
		bytes[k + 1] = clampi(int(fg[j] * 255.0), 0, 255)
		bytes[k + 2] = clampi(int(fb[j] * 255.0), 0, 255)
		bytes[k + 3] = clampi(int(fa[j] * 255.0), 0, 255)
	return Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, bytes)


## Whether the land cell has at most one land neighbour of eight.
func _lone(cx: int, cy: int) -> bool:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _grid.is_land(Vector2i(cx + dx, cy + dy)):
				n += 1
	return n <= 1


## A 3x3 binomial blur, edges clamped.
static func _blur(src: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		var row := y * w
		for x in w:
			tmp[row + x] = (src[row + maxi(x - 1, 0)] + 2.0 * src[row + x] + src[row + mini(x + 1, w - 1)]) * 0.25
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		var up := maxi(y - 1, 0) * w
		var dn := mini(y + 1, h - 1) * w
		var row := y * w
		for x in w:
			out[row + x] = (tmp[up + x] + 2.0 * tmp[row + x] + tmp[dn + x]) * 0.25
	return out


## The sampled signed distance (leagues, land positive) at a point, read
## back from the field the way the shader reads it (bilinear). For tests.
func shore_distance(v: Vector2) -> float:
	var img := field_image
	var p := (v - Vector2(MapGrid.ORIGIN)) * 2.0
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	var fx := p.x - x0
	var fy := p.y - y0
	var s := func(x: int, y: int) -> float:
		var c := img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))
		return (c.r - 0.5) * 2.0 * NEAR
	var top: float = lerpf(s.call(x0, y0), s.call(x0 + 1, y0), fx)
	var bot: float = lerpf(s.call(x0, y0 + 1), s.call(x0 + 1, y0 + 1), fx)
	return lerpf(top, bot, fy)


# --- The noise tile ---------------------------------------------------------------------

## One seamless 256-pixel tile: R a broad wash (the lowland's green to
## ochre), G the hill-shade of a ridged noise (the crags in the fells), B a
## fine paper grain, A the ridged noise itself (where the snow lies).
func _noise_image() -> Image:
	const S := 256
	var broad := FastNoiseLite.new()
	broad.seed = SEED + 2
	broad.frequency = 0.012
	broad.fractal_octaves = 3
	var ridge := FastNoiseLite.new()
	ridge.seed = SEED + 3
	ridge.frequency = 0.03
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 4
	var grain := FastNoiseLite.new()
	grain.seed = SEED + 4
	grain.noise_type = FastNoiseLite.TYPE_VALUE
	grain.frequency = 0.35
	grain.fractal_octaves = 2
	var r := broad.get_seamless_image(S, S).get_data()
	var a := ridge.get_seamless_image(S, S).get_data()
	var b := grain.get_seamless_image(S, S).get_data()
	var light := Vector2(-1, -1).normalized()
	var bytes := PackedByteArray()
	bytes.resize(S * S * 4)
	for y in S:
		for x in S:
			var i := y * S + x
			var dx := float(a[y * S + ((x + 1) & (S - 1))]) - float(a[y * S + ((x - 1) & (S - 1))])
			var dy := float(a[((y + 1) & (S - 1)) * S + x]) - float(a[((y - 1) & (S - 1)) * S + x])
			# Slopes facing the light are bright: the ground rises toward it.
			var lit := -(dx * light.x + dy * light.y) / 255.0
			var k := i * 4
			bytes[k] = r[i]
			bytes[k + 1] = clampi(int(128.0 + lit * 300.0), 0, 255)
			bytes[k + 2] = b[i]
			bytes[k + 3] = a[i]
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, bytes)
	img.generate_mipmaps()
	return img


# --- Glyphs: the fells, the woods and the waves --------------------------------------------

static func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 374761393 + y * 668265263 + salt * 2147483 + SEED) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


func _glyphs() -> void:
	var cols := ceili(float(MapGrid.W) / TILE)
	var rows := ceili(float(MapGrid.H) / TILE)
	# Every glyph is put in the tile its foot stands in; within a tile they
	# are drawn north to south so the nearer overlaps the farther.
	var peaks: Array = []
	var far: Array = []
	var woods: Array = []
	var waves: Array = []
	for i in cols * rows:
		peaks.append([])
		far.append([])
		woods.append([])
		waves.append([])
	_lattice(peaks, cols, PEAK_STEP, 1.15, 11, PEAK_FROM)
	_lattice(far, cols, PEAK_STEP_FAR, 2.3, 41, 0.5)
	for cy in MapGrid.H:
		for cx in MapGrid.W:
			var i := cy * MapGrid.W + cx
			var t := (cy / TILE) * cols + cx / TILE
			var at := MapGrid.centre(Vector2i(cx, cy))
			if _grid.cells[i] >= MapGrid.T.SHORE:
				if _near_place(cx, cy, 1):
					continue
				var w: float = _wood[i]
				if w > 0.15:
					var n := 1 + int(w * 4.0)
					for k in n:
						var j := Vector2(_hash(cx, cy, 10 + k) - 0.5, _hash(cx, cy, 20 + k) - 0.5) * 0.9
						woods[t].append([at + j, w, _hash(cx, cy, 30 + k)])
			else:
				var d: float = _dland[i]
				if d >= 1.5 and d <= 7.0 and _hash(cx, cy, 5) < 0.10:
					var j := Vector2(_hash(cx, cy, 6) - 0.5, _hash(cx, cy, 7) - 0.5) * 0.5
					waves[t].append([at + j, _hash(cx, cy, 8)])
	for ty in rows:
		for tx in cols:
			var t := ty * cols + tx
			var rect := Rect2(Vector2(MapGrid.ORIGIN) + Vector2(tx, ty) * TILE, Vector2(TILE, TILE))
			for list in [peaks[t], far[t], woods[t]]:
				list.sort_custom(func(a, b) -> bool: return a[0].y < b[0].y)
			tiles.append({"rect": rect, "peaks": _peak_mesh(peaks[t]), "peaks_far": _peak_mesh(far[t]),
					"woods": _wood_mesh(woods[t]), "waves": _wave_mesh(waves[t])})


## Fells on a staggered lattice `step` cells apart, each jittered within
## its spot, standing wherever the land there is high enough; `size` is a
## fell's breadth in leagues at middling height. Some have a lesser
## shoulder beside them, so they stand in clumps rather than rows.
func _lattice(out: Array, cols: int, step: float, size: float, salt: int, from: float) -> void:
	var rows := int(MapGrid.H / (step * 0.8)) + 1
	var per_row := int(MapGrid.W / step) + 1
	for r in rows:
		for q in per_row:
			var base := Vector2(q * step + (step * 0.5 if r % 2 == 1 else 0.0), r * step * 0.8)
			var j := Vector2(_hash(q, r, salt) - 0.5, _hash(q, r, salt + 1) - 0.5) * step * 0.7
			var p := base + j
			var c := Vector2i(floori(p.x), floori(p.y))
			if not MapGrid.inside(c) or _grid.cells[MapGrid.index(c)] < MapGrid.T.SHORE:
				continue
			var h: float = _h[MapGrid.index(c)]
			if h < from or _near_place(c.x, c.y, int(ceil(size))) or _dsea[MapGrid.index(c)] < size * 0.9:
				continue
			var at := Vector2(MapGrid.ORIGIN) + p
			var t := (c.y / TILE) * cols + c.x / TILE
			var r0 := _hash(q, r, salt + 2)
			var w := size * (0.75 + 0.55 * h + 0.25 * r0)
			if _hash(q, r, salt + 3) < 0.55:
				var side := -1.0 if r0 < 0.5 else 1.0
				out[t].append([at + Vector2(side * w * 0.45, -w * 0.05), h * 0.8, _hash(q, r, salt + 4), w * 0.62])
			out[t].append([at, h, r0, w])


func _near_place(cx: int, cy: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _place_cells.has((cy + dy) * MapGrid.W + cx + dx):
				return true
	return false


## Appends a triangle to the arrays.
static func _tri(v: PackedVector2Array, c: PackedColorArray, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	v.append(a)
	v.append(b)
	v.append(d)
	c.append(col)
	c.append(col)
	c.append(col)


## A stroke from a to b, `w` leagues wide, as two triangles.
static func _stroke(v: PackedVector2Array, c: PackedColorArray, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := (b - a).orthogonal().normalized() * w * 0.5
	_tri(v, c, a - n, a + n, b + n, col)
	_tri(v, c, a - n, b + n, b - n, col)


static func _mesh(v: PackedVector2Array, c: PackedColorArray, uv := PackedVector2Array()) -> ArrayMesh:
	if v.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A drawn fell: a lit west face and a shadowed east face split by a
## crooked ridge, inked round its skyline, a cast shadow to the south-east,
## and snow on the highest. Entries are [foot, height, chance, breadth].
func _peak_mesh(list: Array) -> ArrayMesh:
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var shadow := Color(0.16, 0.12, 0.08, 0.2)
	var ink := Color(INK, 0.85)
	for e in list:
		var at: Vector2 = e[0]
		var h: float = e[1]
		var r: float = e[2]
		var w: float = e[3]
		var lit := Color("d9cdb0").lerp(Color("cfc8b8"), h)
		var dark := Color("8f8068").lerp(Color("7d7a76"), h)
		var tall := w * (0.55 + 0.3 * h + 0.1 * r)
		var top := at + Vector2((r - 0.5) * 0.25 * w, -tall)
		var left := at + Vector2(-w * 0.5, 0)
		var right := at + Vector2(w * 0.5, 0)
		# Shoulders part way down each side, so the skyline is not a ruler's.
		var ls := left.lerp(top, 0.55) + Vector2(-0.06 * w, 0.04 * w * (r - 0.3))
		var rs := right.lerp(top, 0.5 + 0.2 * r) + Vector2(0.07 * w, -0.03 * w)
		var foot := at + Vector2(w * (0.06 + 0.16 * r), 0)
		var mid := foot.lerp(top, 0.5) + Vector2(-0.05 * w, 0)
		_tri(v, c, left + Vector2(0.3, 0.05) * w, right + Vector2(0.55, 0.12) * w, top + Vector2(0.8 * w, tall * 0.95), shadow)
		_tri(v, c, left, ls, mid, lit)
		_tri(v, c, ls, top, mid, lit)
		_tri(v, c, left, mid, foot, lit)
		_tri(v, c, top, rs, mid, dark)
		_tri(v, c, rs, right, mid, dark)
		_tri(v, c, mid, right, foot, dark)
		if h > 0.74:
			var k := clampf((h - 0.74) * 2.2 + 0.28, 0.28, 0.5)
			var sl := top.lerp(ls, k * 1.4)
			var sr := top.lerp(rs, k * 1.3)
			var sm := top.lerp(mid, k * 1.2)
			var notch := sl.lerp(sm, 0.5) + Vector2(0, -0.06 * w)
			_tri(v, c, sl, notch, top, Color("f3efe4"))
			_tri(v, c, notch, sm, top, Color("f3efe4"))
			_tri(v, c, sm, sr, top, Color("c3c6ca"))
		var lw := 0.03 * w + 0.012
		_stroke(v, c, left, ls, lw, ink)
		_stroke(v, c, ls, top, lw, ink)
		_stroke(v, c, top, rs, lw, ink)
		_stroke(v, c, rs, right, lw, ink)
		_stroke(v, c, top, mid, lw * 0.6, Color(INK, 0.5))
		# Hatching down the shadowed face.
		for k in 2:
			var t := 0.35 + 0.3 * k
			_stroke(v, c, top.lerp(rs, t), mid.lerp(right, t * 0.9), lw * 0.5, Color(INK, 0.35))
	return _mesh(v, c)


## A wood: small dark firs, each two tiers with a lit and a shaded half,
## on a short stem, with a shadow to the south-east.
func _wood_mesh(list: Array) -> ArrayMesh:
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var shadow := Color(0.1, 0.12, 0.06, 0.28)
	for e in list:
		var at: Vector2 = e[0]
		var r: float = e[2]
		var s := 0.24 + 0.12 * r
		var green := Color("35502c").lerp(Color("4c5a2c"), r)
		var lit := green.lightened(0.2)
		var dark := green.darkened(0.3)
		var top := at + Vector2(0, -s * 1.7)
		_tri(v, c, at + Vector2(-s * 0.3, 0.02), at + Vector2(s * 0.8, 0.06), top + Vector2(s * 0.7, s * 1.4), shadow)
		_stroke(v, c, at, at + Vector2(0, s * 0.3), s * 0.2, Color("3a2a1c"))
		var b0 := at + Vector2(0, -s * 0.05)
		_tri(v, c, b0 + Vector2(-s * 0.7, 0), b0, b0 + Vector2(0, -s * 1.1), lit)
		_tri(v, c, b0, b0 + Vector2(s * 0.7, 0), b0 + Vector2(0, -s * 1.1), dark)
		var b1 := at + Vector2(0, -s * 0.65)
		_tri(v, c, b1 + Vector2(-s * 0.52, 0), b1, top, lit)
		_tri(v, c, b1, b1 + Vector2(s * 0.52, 0), top, dark)
	return _mesh(v, c)


## Waves: a shallow double arc each, whose phase (UV.x) the wave shader
## turns into a slow rise and fall.
func _wave_mesh(list: Array) -> ArrayMesh:
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var col := Color("b4d0cf")
	for e in list:
		var at: Vector2 = e[0]
		var r: float = e[1]
		var len := 0.45 + 0.35 * r
		var pts := PackedVector2Array()
		for k in 7:
			var t := float(k) / 6.0
			var x := (t - 0.5) * len * 2.0
			pts.append(at + Vector2(x, -absf(sin(t * TAU)) * len * 0.22))
		var before := v.size()
		for k in 6:
			_stroke(v, c, pts[k], pts[k + 1], 0.05, col)
		for k in v.size() - before:
			uv.append(Vector2(r, 0))
	return _mesh(v, c, uv)
