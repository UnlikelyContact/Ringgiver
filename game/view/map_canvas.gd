class_name MapCanvas
extends Control
## The free-roam map as it is drawn: the land and the water, the places
## the band knows, the others abroad within sight, the ship where she lies
## and the band, under a camera that follows or is dragged. A tap is
## passed to the screen (MapScreen.tap_map). Everything here is for the
## eye: the sim's map is MapGrid, and what is drawn as land must be what
## MapGrid says is land.

const ZOOM_MIN := 4.0
const ZOOM_MAX := 34.0
## One colour a terrain (MapGrid.T): the deep, the sea, the shore, the low
## land, the mountain.
const TERRAIN_COLORS := [Color("1c2e42"), Color("2a4560"), Color("6b7560"), Color("58624f"), Color("8a8c86")]

var screen: MapScreen
var cam := Vector2(26, 52)
var zoom := 14.0
var follow := true
var _texture: ImageTexture = null
var _pressed := false
var _dragged := false
var _press_at := Vector2.ZERO

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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragged = false
				_press_at = event.position
			else:
				if _pressed and not _dragged:
					screen.tap_map(event.position)
				_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		if _dragged or event.position.distance_to(_press_at) > 8.0:
			_dragged = true
			follow = false
			cam -= event.relative / zoom
			queue_redraw()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor)

func _make_texture() -> void:
	var grid := screen.journey.roam.grid
	var img := Image.create(MapGrid.W, MapGrid.H, false, Image.FORMAT_RGB8)
	for y in MapGrid.H:
		for x in MapGrid.W:
			img.set_pixel(x, y, TERRAIN_COLORS[grid.cells[y * MapGrid.W + x]])
	_texture = ImageTexture.create_from_image(img)

func _boat(at: Vector2, sail: Color, big: bool) -> void:
	var k := 1.0 if big else 0.75
	draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 1) * k, at + Vector2(9, 1) * k, at + Vector2(6, 6) * k, at + Vector2(-6, 6) * k]), Palette.TIMBER)
	draw_line(at + Vector2(0, 1) * k, at + Vector2(0, -10) * k, Palette.BONE, 1.5)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -9) * k, at + Vector2(6, -9) * k, at + Vector2(6, -2) * k, at + Vector2(-6, -2) * k]), sail)

func _draw() -> void:
	if screen == null or screen.journey == null:
		return
	var j := screen.journey
	var band := j.c.band
	var world := j.c.world
	var roam := j.roam
	var font := ThemeDB.fallback_font
	if _texture == null:
		_make_texture()
	if follow:
		cam = roam.pos
	draw_rect(Rect2(Vector2.ZERO, size), TERRAIN_COLORS[0])
	draw_texture_rect(_texture, Rect2(to_px(Vector2(MapGrid.ORIGIN)), Vector2(MapGrid.W, MapGrid.H) * zoom), false)
	# The course set.
	if roam.moving():
		var pts := PackedVector2Array([to_px(roam.pos)])
		for i in range(roam.route_at, roam.route.size()):
			pts.append(to_px(MapGrid.centre(roam.route[i])))
		if pts.size() >= 2:
			draw_polyline(pts, Color(Palette.GOLD, 0.8), 2.0)
	# The places the band knows.
	var ids: Array = band.known_places.keys()
	ids.sort()
	for id in ids:
		var p := world.place(id)
		if p == null or not p.is_open(world.year):
			continue
		var at := to_px(MapGrid.centre(roam.grid.place_cell[id]))
		if at.x < -60 or at.y < -20 or at.x > size.x + 20 or at.y > size.y + 20:
			continue
		var picked: bool = id == screen.selected
		match p.kind:
			WorldTypes.PlaceKind.TOWN:
				draw_circle(at, 7.0, Palette.OUTLINE)
				draw_circle(at, 5.5, Palette.BONE)
			WorldTypes.PlaceKind.HALL:
				draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), Palette.OUTLINE)
				draw_rect(Rect2(at - Vector2(4.5, 4.5), Vector2(9, 9)), Palette.GOLD)
			WorldTypes.PlaceKind.THING_SITE:
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 6), at + Vector2(-7, 6)]), Palette.OUTLINE)
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4.5), at + Vector2(4.5, 4.5), at + Vector2(-4.5, 4.5)]), Palette.UNDYED)
			WorldTypes.PlaceKind.BAY:
				draw_arc(at, 4.0, 0.0, TAU, 16, Palette.UNDYED, 1.5)
			_:
				draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Palette.OUTLINE)
				draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Palette.UNDYED)
		if p.has_market:
			draw_circle(at + Vector2(0, -10), 2.5, Palette.WARN)
		if not Feud.find(band, p.family).is_empty():
			draw_circle(at + Vector2(-10, 0), 3.0, Palette.BLOOD)
		if id == band.home:
			draw_arc(at, 11.0, 0.0, TAU, 20, Palette.HEARD, 1.5)
		if picked:
			draw_arc(at, 14.0, 0.0, TAU, 24, Palette.GOLD, 2.0)
		var name := p.display_name.trim_prefix("the ")
		draw_string(font, at + Vector2(12, 4) + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.7))
		draw_string(font, at + Vector2(12, 4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.TEXT if picked or id == band.location else Color(Palette.TEXT, 0.8))
	# The others abroad, as far as the band can see.
	var sight: float = j.c.world_rules.sight_leagues
	for party in roam.parties:
		if party.pos.distance_to(roam.pos) > sight:
			continue
		var at := to_px(party.pos)
		var label := ""
		match party.kind:
			"merchant":
				_boat(at, Palette.BONE, false)
				label = "merchant"
			"raiders":
				_boat(at, Palette.WOAD, false)
				label = "raiders, %d" % party.men
			"levy":
				_boat(at, Palette.GOLD, false)
				label = "the levy, %d" % party.men
			_:
				draw_circle(at, 5.0, Palette.OUTLINE)
				draw_circle(at, 3.5, Palette.WALNUT)
				label = "outlaws, %d" % party.men
		if party.chasing:
			draw_arc(at, 10.0, 0.0, TAU, 16, Palette.BLOOD, 1.5)
		draw_string(font, at + Vector2(-20, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.TEXT)
	# The ship where she lies, and the band.
	if band.ship != null and not roam.aboard and roam.ship_at != Vector2.INF:
		_boat(to_px(roam.ship_at), Color(Palette.MADDER, 0.6), false)
	var me := to_px(roam.pos)
	if band.ship != null and roam.aboard and roam.afloat():
		_boat(me, Palette.MADDER, true)
	else:
		draw_circle(me, 7.0, Palette.OUTLINE)
		draw_circle(me, 5.5, Palette.MADDER)
		draw_line(me + Vector2(0, -5), me + Vector2(0, -16), Palette.BONE, 1.5)
		draw_colored_polygon(PackedVector2Array([me + Vector2(0, -16), me + Vector2(8, -13), me + Vector2(0, -10)]), Palette.GOLD)
