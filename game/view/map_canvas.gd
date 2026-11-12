class_name MapCanvas
extends Control
## The free-roam map as it is drawn: the land and the water, the places
## the band knows, the others abroad within sight, the ship where she lies
## and the band, under a camera that follows or is dragged. A tap is
## passed to the screen (MapScreen.tap_map). Everything here is for the
## eye: the sim's map is MapGrid, and what is drawn as land must be what
## MapGrid says is land.
##
## The ground is painted by a shader from MapArt's field texture, and the
## fells, woods and waves are meshes in leagues; all of these are built
## once and sit in layers behind this node that are only moved and scaled
## with the camera. What this node draws itself each time is what changes:
## the course, the places, the parties, the band, the compass.

const ZOOM_MIN := 4.0
const ZOOM_MAX := 34.0
## One colour a terrain (MapGrid.T): the deep, the sea, the shore, the low
## land, the mountain. Kept for anything that wants a flat swatch.
const TERRAIN_COLORS := [Color("1c2e42"), Color("2a4560"), Color("6b7560"), Color("58624f"), Color("8a8c86")]
## A tap this near a place or a party is a tap on it rather than on the
## ground: about a fingertip. In the canvas's own units, which the window
## stretches: the design is 540 high, a phone held sideways about 390 CSS
## pixels, so this is some 28 of those.
const TAP_RADIUS := 38.0
## A press that moves further than this (same units) is a drag.
const DRAG_DIST := 12.0
## Zooms (pixels a league) at which the drawn things come and go.
const PEAKS_FROM := 5.5
const PEAKS_NEAR_FROM := 12.0
const WOODS_FROM := 9.0
const WAVES_FROM := 6.0
const FARMS_FROM := 9.0
const TAGS_FROM := 18.0
## The seas named on the map, at points in leagues, and the zoom beyond
## which their names are no longer drawn (they would only cover the view).
const SEAS := [["The North Sea", Vector2(26, 92)], ["Skagerrak", Vector2(52, 88)], ["The Norway Sea", Vector2(6, 26)],
		["The Western Ocean", Vector2(-36, 46)], ["The Baltic", Vector2(96, 104)], ["Kattegat", Vector2(70, 98)]]
const SEA_NAMES_TO := 16.0
const REGION_NAMES_TO := 15.0
## Pixels beyond the view's edge that the places layer is drawn out to,
## so the camera can pan a way before it must be drawn again.
const STATIC_MARGIN := 220.0
const TERRAIN_SHADER := preload("res://view/map_terrain.gdshader")
const WAVES_SHADER := preload("res://view/map_waves.gdshader")

var screen: MapScreen
var cam := Vector2(26, 52)
var zoom := 14.0
var follow := true
## Microseconds the last _draw took (this node's own drawing only).
var draw_usec := 0
## Microseconds the places layer took the last time it was drawn.
var static_usec := 0

var _art: MapArt = null
var _terrain_mat: ShaderMaterial
var _terrain: _Layer
var _waves: Node2D
var _woods: Node2D
var _peaks: Node2D
var _peaks_far: Node2D
var _vignette: GradientTexture2D
var _sea_font: FontVariation
var _region_font: FontVariation
var _label_font: FontVariation
var _regions := []  # [name, centre in leagues] for the lands of Norway
var _pressed := false
var _dragged := false
var _press_at := Vector2.ZERO
var _touches := {}  # touch index -> position, for the pinch
var _pinch_d := 0.0
var _pinch_mid := Vector2.ZERO
var _tagged: Roam.Party = null  # a party tapped: its tag is shown
var _water_dir := {}  # place id -> unit vector toward its water
var _furniture: Control  # the compass and the scale, drawn again only on a zoom
var _furniture_zoom := -1.0
var _places: _Layer  # the places and the names: drawn again only on a change
var _shade: _Layer  # the vignette
var _static_seen := ""
var _static_cam := Vector2.ZERO
var _static_zoom := 0.0
var _marks: Array[Rect2] = []  # what is drawn this time, for labels to keep off


## A node that draws through a callable once (its content is in leagues).
class _Layer:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func centre_on(v: Vector2) -> void:
	cam = v
	queue_redraw()


func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


func to_px(leagues: Vector2) -> Vector2:
	return size / 2.0 + (leagues - cam) * zoom


func from_px(px: Vector2) -> Vector2:
	return cam + (px - size / 2.0) / zoom


## Zooms keeping the point under `px` where it is (unless the camera is
## following the band, which stays in the middle).
func _zoom_at(px: Vector2, f: float) -> void:
	var before := from_px(px)
	zoom = clampf(zoom * f, ZOOM_MIN, ZOOM_MAX)
	if not follow:
		cam += before - from_px(px)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Two fingers pinch and pan; one finger (or the mouse, or the first
	# finger as the mouse) drags and taps, as before.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_pressed = false
			_dragged = true
			_pinch_start()
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch_move()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = _touches.size() < 2
				_dragged = false
				_press_at = event.position
			else:
				if _pressed and not _dragged:
					_tap(event.position)
				_pressed = false
	elif event is InputEventMouseMotion and _pressed and _touches.size() < 2:
		if _dragged or event.position.distance_to(_press_at) > DRAG_DIST:
			_dragged = true
			follow = false
			cam -= event.relative / zoom
			queue_redraw()
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		follow = false
		cam += event.delta * 4.0 / zoom
		queue_redraw()


func _pinch_start() -> void:
	var p: Array = _touches.values()
	_pinch_d = maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	_pinch_mid = ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0


func _pinch_move() -> void:
	var p: Array = _touches.values()
	var d := maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	var mid := ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0
	if mid.distance_to(_pinch_mid) > 0.5:
		follow = false
		cam -= (mid - _pinch_mid) / zoom
	_zoom_at(mid, d / _pinch_d)
	_pinch_d = d
	_pinch_mid = mid


## A tap: on a place or a party within a fingertip it goes to the screen
## as a tap on that place (or the party's own ground); else as it fell.
func _tap(at: Vector2) -> void:
	if screen == null or screen.journey == null:
		return
	var j := screen.journey
	var best_d := TAP_RADIUS
	var target := Vector2.INF
	for id in j.c.band.known_places:
		var p := j.c.world.place(id)
		if p == null or not p.is_open(j.c.world.year):
			continue
		var d := _place_px(id).distance_to(at)
		if d < best_d:
			best_d = d
			target = to_px(p.pos)  # where the screen looks for it
	_tagged = null
	if target == Vector2.INF:
		for party in _seen_parties():
			var d := to_px(party.pos).distance_to(at)
			if d < best_d:
				best_d = d
				target = to_px(party.pos)
				_tagged = party
	screen.tap_map(target if target != Vector2.INF else at)


func _place_px(id: String) -> Vector2:
	return to_px(MapGrid.centre(screen.journey.roam.grid.place_cell[id]))


func _seen_parties() -> Array:
	var j := screen.journey
	var out := []
	var sight: float = j.c.world_rules.sight_leagues
	for party in j.roam.parties:
		if party.pos.distance_to(j.roam.pos) <= sight:
			out.append(party)
	return out


# --- The layers built once ------------------------------------------------------------

func _build_layers() -> void:
	var grid := screen.journey.roam.grid
	_art = MapArt.for_grid(grid)
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = TERRAIN_SHADER
	_terrain_mat.set_shader_parameter("field", _art.field)
	_terrain_mat.set_shader_parameter("noise", _art.noise)
	_terrain_mat.set_shader_parameter("origin", Vector2(MapGrid.ORIGIN))
	_terrain_mat.set_shader_parameter("cells", Vector2(MapGrid.W, MapGrid.H))
	_terrain_mat.set_shader_parameter("near_range", MapArt.NEAR)
	_terrain = _Layer.new()
	_terrain.material = _terrain_mat
	_terrain.paint = func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(Vector2(MapGrid.ORIGIN) - Vector2(4000, 4000), Vector2(MapGrid.W, MapGrid.H) + Vector2(8000, 8000)), Color.WHITE)
	_waves = _tile_root("waves")
	_waves.material = ShaderMaterial.new()
	(_waves.material as ShaderMaterial).shader = WAVES_SHADER
	_woods = _tile_root("woods")
	_peaks_far = _tile_root("peaks_far")
	_peaks = _tile_root("peaks")
	_shade = _Layer.new()
	_shade.paint = func(ci: CanvasItem) -> void: ci.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
	_places = _Layer.new()
	_places.paint = _paint_static
	for layer in [_terrain, _waves, _woods, _peaks_far, _peaks, _shade, _places]:
		layer.show_behind_parent = true
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(layer)
	_furniture = Control.new()
	_furniture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furniture.draw.connect(func() -> void: _draw_furniture(_furniture))
	add_child(_furniture)
	# Where each place's water lies, for the town's jetty.
	for id in grid.place_cell:
		var c: Vector2i = grid.place_cell[id]
		var dir := Vector2.ZERO
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if grid.is_sea(c + d):
				dir += Vector2(d)
		_water_dir[id] = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	_sea_font = FontVariation.new()
	_sea_font.base_font = ThemeDB.fallback_font
	_sea_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_sea_font.spacing_glyph = 3
	_label_font = FontVariation.new()
	_label_font.base_font = ThemeDB.fallback_font
	_label_font.variation_embolden = 0.55
	_region_font = FontVariation.new()
	_region_font.base_font = ThemeDB.fallback_font
	_region_font.spacing_glyph = 4
	var sums := {}
	for d in NorwayData.PLACES:
		if d.region > WorldTypes.Region.HALOGALAND:
			continue
		var e: Array = sums.get(d.region, [Vector2.ZERO, 0])
		sums[d.region] = [e[0] + d.pos, e[1] + 1]
	for r in sums:
		var e: Array = sums[r]
		# A little inland of its halls and farms, which stand on the shore.
		_regions.append([(WorldTypes.REGION_NAMES[r] as String).to_upper(), e[0] / float(e[1]) + Vector2(5, 1)])
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.04, 0.03, 0.0))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.55))
	g.add_point(0.62, Color(0.05, 0.04, 0.03, 0.0))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.08, 1.08)
	_vignette.width = 128
	_vignette.height = 128


## A layer of glyph tiles, one child a tile, so only those on screen draw.
func _tile_root(key: String) -> Node2D:
	var root := Node2D.new()
	for t in _art.tiles:
		var mesh: ArrayMesh = t[key]
		if mesh == null:
			continue
		var tile := _Layer.new()
		tile.paint = func(ci: CanvasItem) -> void: ci.draw_mesh(mesh, null)
		tile.use_parent_material = true
		root.add_child(tile)
	return root


func _place_layers() -> void:
	var xf := Transform2D(0.0, Vector2(zoom, zoom), 0.0, size / 2.0 - cam * zoom)
	for layer in [_terrain, _waves, _woods, _peaks_far, _peaks]:
		layer.transform = xf
	_waves.modulate.a = clampf((zoom - WAVES_FROM) / 3.0, 0.0, 1.0) * 0.55
	_woods.modulate.a = clampf((zoom - WOODS_FROM) / 4.0, 0.0, 1.0)
	_peaks_far.modulate.a = clampf((zoom - PEAKS_FROM) / 2.0, 0.0, 1.0) * clampf((PEAKS_NEAR_FROM + 2.0 - zoom) / 3.0, 0.0, 1.0)
	_peaks.modulate.a = clampf((zoom - PEAKS_NEAR_FROM) / 3.0, 0.0, 1.0)
	_peaks_far.visible = _peaks_far.modulate.a > 0.0
	_waves.visible = _waves.modulate.a > 0.0
	_woods.visible = _woods.modulate.a > 0.0
	_peaks.visible = _peaks.modulate.a > 0.0
	_place_static()
	var j := screen.journey
	var summer: float = maxf(1.0, j.c.world_rules.summer_days)
	var spent := 1.0 - clampf(float(j.days_left()) / summer, 0.0, 1.0)
	_terrain_mat.set_shader_parameter("season", smoothstep(0.45, 1.0, spent))


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	if screen == null or screen.journey == null:
		return
	var t0 := Time.get_ticks_usec()
	var j := screen.journey
	var roam := j.roam
	if _art == null:
		_build_layers()
	if follow:
		cam = roam.pos
	_place_layers()
	var font := ThemeDB.fallback_font
	var k := _scale()
	_draw_course(font, k)
	_draw_parties(font, k)
	_draw_band(k)
	if _furniture_zoom != zoom or _furniture.size != size:
		_furniture_zoom = zoom
		_furniture.size = size
		_furniture.queue_redraw()
		_shade.queue_redraw()
	draw_usec = Time.get_ticks_usec() - t0


## The size of the drawn marks at this zoom (1 at a middling zoom).
func _scale() -> float:
	return clampf(0.55 + zoom / 30.0, 0.62, 1.15)


## What the places layer shows, as a key: when it changes the layer is
## drawn again; else it is only moved with the camera.
func _static_key() -> String:
	var j := screen.journey
	var band := j.c.band
	var feuds := 0
	for f in band.feuds:
		feuds += 0 if f.settled else 1
	return "%.4f|%s|%d|%s|%s|%d|%d|%s|%s" % [zoom, screen.selected, band.known_places.size(), band.location, band.home,
			feuds, j.c.world.year, size, j.roam.afloat()]


## Moves the places layer with the camera, and has it drawn again when
## what it shows has changed or the camera has gone far from where it was
## drawn (it holds only what was near the view then).
func _place_static() -> void:
	var key := _static_key()
	var s := zoom / _static_zoom if _static_zoom > 0.0 else 1.0
	if key != _static_seen or (cam - _static_cam).length() * zoom > STATIC_MARGIN * 0.6:
		_static_seen = key
		_static_cam = cam
		_static_zoom = zoom
		s = 1.0
		_places.queue_redraw()
	_places.transform = Transform2D(0.0, Vector2(s, s), 0.0, size / 2.0 * (1.0 - s) + (_static_cam - cam) * zoom)


## The places layer: the places the band knows, their names, and the
## names of the seas and lands, set out so that none covers another.
func _paint_static(ci: CanvasItem) -> void:
	if screen == null or screen.journey == null:
		return
	var t0 := Time.get_ticks_usec()
	# Drawn as from where the camera was when it was asked for;
	# _place_static moves it with the camera after.
	var keep_cam := cam
	cam = _static_cam
	_marks.clear()
	_marks.append(Rect2(size.x - 106.0, 4.0, 102.0, 108.0))  # the compass
	for n in get_parent().get_children():
		# The screen's buttons laid over the map: names keep out from under them.
		if n is HBoxContainer and (n as Control).visible:
			var bar := n as Control
			_marks.append(Rect2(bar.position, bar.size.max(bar.get_combined_minimum_size())).grow(4.0))
	var k := _scale()
	_marks.append(Rect2(_band_px(k) + Vector2(-11, -34) * k * 1.25, Vector2(36, 44) * k * 1.25))
	var labels := _draw_places(ci, k)
	_name_lands(labels)
	_draw_labels(ci, labels)
	cam = keep_cam
	static_usec = Time.get_ticks_usec() - t0


func _on_screen(at: Vector2, margin: float) -> bool:
	return at.x > -margin and at.y > -margin and at.x < size.x + margin and at.y < size.y + margin


## The course set: footprints on land, a wake at sea, a tick for each
## day's going, and a flag where it ends.
func _draw_course(font: Font, k: float) -> void:
	var roam := screen.journey.roam
	if not roam.moving():
		return
	var j := screen.journey
	var grid := roam.grid
	var foot := maxf(j.foot_speed(), 0.1)
	var sail := maxf(j.sail_speed(), 0.1)
	var here := roam.pos
	var prev_cell := roam.last_cell if MapGrid.inside(roam.last_cell) else roam.cell()
	var days := 0.0
	var next_tick := 1.0
	var step := 0.0  # pixels walked since the last footprint
	var foot_side := 1.0
	for i in range(roam.route_at, roam.route.size()):
		var c := roam.route[i]
		var to := MapGrid.centre(c)
		var by_ship: bool = roam.route_aboard[i] and (grid.is_sea(c) or grid.is_sea(prev_cell))
		var len := here.distance_to(to)
		var seg_days := len / sail if by_ship else len * float(MapGrid.COST[grid.terrain(c)]) / foot
		var a := to_px(here)
		var b := to_px(to)
		if _on_screen(a, 40) or _on_screen(b, 40):
			var dir := (b - a).normalized() if b != a else Vector2.RIGHT
			var side := dir.orthogonal()
			if by_ship:
				draw_line(a + side * 2.0, b + side * 2.0, Color(0.85, 0.93, 0.92, 0.55), 1.3, true)
				draw_line(a - side * 2.0, b - side * 2.0, Color(0.85, 0.93, 0.92, 0.55), 1.3, true)
			else:
				var gap := 7.0
				var walked := gap - step
				var seg := a.distance_to(b)
				while walked < seg:
					var p := a + dir * walked + side * 2.2 * foot_side
					draw_circle(p, 1.9, Color(0.10, 0.07, 0.05, 0.75))
					draw_circle(p, 1.2, Color(Palette.GOLD, 0.95))
					foot_side = -foot_side
					walked += gap
				step = seg - (walked - gap)
			# A tick at each whole day.
			while days + seg_days >= next_tick:
				var t := (next_tick - days) / maxf(seg_days, 0.0001)
				var p := a.lerp(b, t)
				draw_line(p - side * 5.0, p + side * 5.0, Color(0.1, 0.07, 0.05, 0.85), 3.0)
				draw_line(p - side * 4.0, p + side * 4.0, Palette.BONE, 1.4)
				if zoom >= 12.0:
					var s := str(int(next_tick))
					draw_string_outline(font, p + side * 7.0 + Vector2(-3, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.08, 0.06, 0.04, 0.8))
					draw_string(font, p + side * 7.0 + Vector2(-3, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.BONE)
				next_tick += 1.0
		else:
			while days + seg_days >= next_tick:
				next_tick += 1.0
		days += seg_days
		here = to
		prev_cell = c
	MapIcons.flag(self, to_px(MapGrid.centre(roam.route[roam.route.size() - 1])), k)


## The places the band knows, as glyphs by kind; returns their labels to
## be set out once everything else is drawn: [at, text, size, rank, lit].
func _draw_places(ci: CanvasItem, k: float) -> Array:
	var j := screen.journey
	var band := j.c.band
	var world := j.c.world
	var out := []
	var ids: Array = band.known_places.keys()
	ids.sort()
	for id in ids:
		var p := world.place(id)
		if p == null or not p.is_open(world.year):
			continue
		var at := _place_px(id)
		if not _on_screen(at, STATIC_MARGIN):
			continue
		var picked: bool = id == screen.selected
		var key: bool = picked or id == band.location or id == band.home
		var rank := _rank(p)
		var small := zoom < FARMS_FROM and rank <= 1 and not key
		var pk := k * (0.7 if small else 1.0)
		if picked:
			ci.draw_circle(at, 17.0 * k, Color(Palette.GOLD, 0.16))
			ci.draw_arc(at, 17.0 * k, 0.0, TAU, 32, Color(0.08, 0.06, 0.04, 0.7), 4.0, true)
			ci.draw_arc(at, 17.0 * k, 0.0, TAU, 32, Palette.GOLD, 2.2, true)
		if id == band.home:
			ci.draw_arc(at, 20.5 * k, 0.0, TAU, 32, Palette.HEARD, 1.6, true)
		match p.kind:
			WorldTypes.PlaceKind.TOWN:
				MapIcons.town(ci, at, pk * 1.2, _water_dir.get(id, Vector2.ZERO))
			WorldTypes.PlaceKind.HALL:
				MapIcons.hall(ci, at, pk)
			WorldTypes.PlaceKind.THING_SITE:
				MapIcons.thing(ci, at, pk)
			WorldTypes.PlaceKind.BAY:
				MapIcons.bay(ci, at, pk)
			WorldTypes.PlaceKind.FORT:
				MapIcons.fort(ci, at, pk)
			_:
				if p.faction_id == "" and p.region == WorldTypes.Region.WEST:
					MapIcons.church(ci, at, pk, id == "iona")
				else:
					MapIcons.hamlet(ci, at, pk)
		_marks.append(Rect2(at - Vector2(11, 11) * pk, Vector2(22, 18) * pk))
		if p.has_market:
			# A silver penny: there is a market here.
			var m := at + Vector2(11, -11) * pk
			ci.draw_circle(m, 4.2 * pk, Color(0.08, 0.06, 0.04, 0.8))
			ci.draw_circle(m, 3.2 * pk, Color("d8d4c8"))
			ci.draw_arc(m, 1.8 * pk, 0, TAU, 10, Color("8e9398"), 1.0)
		if not Feud.find(band, p.family).is_empty():
			# Blood owed: a red drop.
			var m := at + Vector2(-12, -10) * pk
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5) * pk, m + Vector2(3, 0) * pk, m + Vector2(-3, 0) * pk]), Palette.BLOOD)
			ci.draw_circle(m, 3.0 * pk, Palette.BLOOD)
		var show: bool = key or (zoom >= FARMS_FROM) or rank >= 2 or (zoom >= 6.5 and rank >= 1)
		if show:
			var name := p.display_name.trim_prefix("the ")
			var fs := 16 if rank >= 3 else (15 if rank == 2 else 14)
			if zoom < 7.0:
				fs -= 2
			var span := (17.0 if p.kind == WorldTypes.PlaceKind.TOWN else 14.0) * pk
			var water: Vector2 = _water_dir.get(id, Vector2.ZERO)
			out.append([at, name, fs, rank + (10 if key else 0), key, span, null, null, true, water.x > 0.3])
	return out


## How much a place matters on the map, for its label: halls and towns
## first, then Thing-steads, then farms, then bays.
func _rank(p: Place) -> int:
	match p.kind:
		WorldTypes.PlaceKind.TOWN, WorldTypes.PlaceKind.HALL:
			return 3
		WorldTypes.PlaceKind.THING_SITE, WorldTypes.PlaceKind.FORT:
			return 2
		WorldTypes.PlaceKind.BAY:
			return 0
	return 1


## Others abroad as far as the band can see: ships by their sails, men on
## foot by their shields, those who would harm the band ringed in red.
func _draw_parties(font: Font, k: float) -> void:
	var grid := screen.journey.roam.grid
	for party in _seen_parties():
		var at := to_px(party.pos)
		if not _on_screen(at, 40):
			continue
		var pk := k * 0.9
		var afloat := grid.is_sea(MapGrid.cell_of(party.pos))
		var hostile: bool = party.kind in ["raiders", "levy", "outlaws"]
		var on_ship: bool = party.sails and afloat
		if hostile:
			MapIcons.hostile(self, at + (Vector2(0, -6) * pk if on_ship else Vector2.ZERO), (15.0 if on_ship else 8.0) * pk, party.chasing, on_ship)
		var tag := ""
		var facing := 1.0
		if party.at < party.route.size():
			facing = -1.0 if MapGrid.centre(party.route[party.at]).x < party.pos.x else 1.0
		match party.kind:
			"merchant":
				tag = "a trader"
				MapIcons.ship(self, at, pk, facing, Color("6b5034"), Color("e4dccb"), Color("8a6a46"))
			"raiders":
				tag = "raiders, %d" % party.men
				MapIcons.ship(self, at, pk, facing, Color("2e2620"), Color("3a3330"), Palette.BLOOD, Color("5d5f62"))
			"levy":
				tag = "the king's ships, %d" % party.men
				MapIcons.ship(self, at, pk, facing, Color("4a3a2a"), Palette.GOLD, Palette.WOAD, Palette.WOAD)
			"outlaws":
				tag = "outlaws, %d" % party.men
				MapIcons.token(self, at, pk, Color("3a3330"), Color("6b4a2e"))
			_:
				tag = party.name if party.name != "" else party.kind
				if party.sails and afloat:
					MapIcons.ship(self, at, pk, facing, Color("6b5034"), Palette.UNDYED, Color(0, 0, 0, 0))
				else:
					MapIcons.token(self, at, pk, Color("7a6a40"), Palette.UNDYED)
		if zoom >= TAGS_FROM or party == _tagged or party.chasing:
			var tw := _label_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var tp := at + Vector2(-tw / 2.0, 10.0 * pk + 15.0)
			draw_string_outline(_label_font, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 6, Color(0.06, 0.045, 0.03, 0.5))
			draw_string_outline(_label_font, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0.06, 0.045, 0.03, 0.95))
			draw_string(_label_font, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2b8a8") if hostile else Palette.BONE)


## The names of the seas and the lands, faint and lowest in the order:
## they give way to everything else.
func _name_lands(labels: Array) -> void:
	if zoom <= SEA_NAMES_TO:
		for e in SEAS:
			labels.append([to_px(e[1]), e[0], 17 if zoom < 8.0 else 19, -2, false, -1.0, Color(0.80, 0.90, 0.88, 0.5), _sea_font, false])
	if zoom <= REGION_NAMES_TO:
		for e in _regions:
			labels.append([to_px(e[1]), e[0], 12 if zoom < 8.0 else 14, -1, false, -1.0, Color(0.22, 0.16, 0.09, 0.62), _region_font, false])


## The band: its ship under sail when aboard, its banner when on foot,
## and the ship where she lies beached.
func _draw_band(k: float) -> void:
	var j := screen.journey
	var band := j.c.band
	var roam := j.roam
	var facing := 1.0
	if roam.moving():
		facing = -1.0 if MapGrid.centre(roam.route[roam.route_at]).x < roam.pos.x - 0.01 else 1.0
	var none := Color(0, 0, 0, 0)
	if band.ship != null and not roam.aboard and roam.ship_at != Vector2.INF:
		MapIcons.ship(self, to_px(roam.ship_at), k * 0.95, 1.0, Color("5a3e26"), none, none, Palette.MADDER)
	elif band.ship != null and roam.aboard and not roam.afloat():
		# Drawn up on the strand beside the band.
		MapIcons.ship(self, to_px(roam.pos) + Vector2(-20, 10) * k, k * 0.95, 1.0, Color("5a3e26"), none, none, Palette.MADDER)
	var me := _band_px(k)
	if band.ship != null and roam.aboard and roam.afloat():
		if roam.moving():
			# The wake behind her.
			var back := Vector2(-facing, 0)
			for s in [-1.0, 1.0]:
				draw_line(me + Vector2(-14 * facing, 2) * k, me + (back * 44.0 + Vector2(0, s * 9.0)) * k, Color(0.88, 0.95, 0.94, 0.45), 1.6, true)
		MapIcons.ship(self, me, k * 1.3, facing, Color("5a3e26"), Palette.MADDER, Palette.BONE, Palette.MADDER)
	else:
		MapIcons.banner(self, me, k * 1.25, Palette.MADDER)


## Where the band is drawn: beside the place's own mark when it is at one.
func _band_px(k: float) -> Vector2:
	var j := screen.journey
	var me := to_px(j.roam.pos)
	if j.c.band.location != "" and not j.roam.afloat():
		me += Vector2(23, -2) * k
	return me


## Sets out the labels, the most important first; a label that would
## overlap one already set tries the other sides of its mark, then is
## left out. Each reads on any ground through a soft dark halo.
func _draw_labels(ci: CanvasItem, labels: Array) -> void:
	labels.sort_custom(func(a, b) -> bool: return a[3] > b[3])
	var taken: Array[Rect2] = _marks.duplicate()
	for l in labels:
		var at: Vector2 = l[0]
		var text: String = l[1]
		var fs: int = l[2]
		var key: bool = l[4]
		var off: float = l[5]
		var f: Font = l[7] if l.size() > 7 and l[7] != null else _label_font
		var halo: bool = l[8] if l.size() > 8 else true
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var th := float(fs)
		var tries: Array[Vector2]
		if off < 0.0:
			if not _on_screen(at, tw + STATIC_MARGIN):
				continue
			tries = [at + Vector2(-tw / 2.0, th / 2.0)]  # a name centred on its sea or land
		elif off == 0.0:
			tries = [at + Vector2(-tw / 2.0, th + 2.0)]  # a tag, under its token
		else:
			tries = [at + Vector2(off, th * 0.35), at + Vector2(-off - tw, th * 0.35), at + Vector2(-tw / 2.0, off + th), at + Vector2(-tw / 2.0, -off - 4.0)]
			if l.size() > 9 and l[9]:
				tries = [tries[1], tries[0], tries[2], tries[3]]  # keep off the water side, where the jetty is
		for raw in tries:
			var pos := Vector2(clampf(raw.x, 4.0, size.x - tw - 4.0), raw.y)
			var r := Rect2(pos + Vector2(-2, -th), Vector2(tw + 4, th + 4))
			var clear := true
			for o in taken:
				if o.intersects(r):
					clear = false
					break
			if clear or (key and raw == tries[tries.size() - 1]):
				taken.append(r)
				var col: Color = l[6] if l.size() > 6 and l[6] != null else (Color("fff6e0") if key else Color("efe6d0"))
				if halo:
					ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.06, 0.045, 0.03, 0.45))
					ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.06, 0.045, 0.03, 0.95))
				ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				break


## The compass in the top right corner and the scale beneath it.
func _draw_furniture(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	var right_x: float = ci.size.x
	var plate := Rect2(right_x - 104.0, 6.0, 98.0, 104.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.07, 0.55)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.85, 0.78, 0.62, 0.35)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, plate)
	var c := Vector2(right_x - 55.0, 44.0)
	MapIcons.compass(ci, c, 24.0, font)
	# A bar a round number of leagues long, near 70 pixels.
	var leagues := 1.0
	for l in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]:
		if l * zoom <= 80.0:
			leagues = l
	var w := leagues * zoom
	var right := Vector2(right_x - 55.0 + w / 2.0, 86.0)
	var left := right - Vector2(w, 0)
	var ink := Color(0.08, 0.06, 0.04, 0.8)
	ci.draw_line(left, right, ink, 5.0)
	ci.draw_line(left, left.lerp(right, 0.5), Palette.BONE, 2.6)
	ci.draw_line(left.lerp(right, 0.5), right, Color("8b2a24"), 2.6)
	for p in [left, right]:
		ci.draw_line(p + Vector2(0, -4), p + Vector2(0, 4), ink, 2.0)
	var text := "%d league%s" % [int(leagues), "" if leagues == 1.0 else "s"]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var tp := Vector2(right_x - 55.0 - tw / 2.0, 104.0)
	ci.draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.BONE)
