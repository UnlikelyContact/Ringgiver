extends TestCase
## The painted map (MapArt) keeps faith with the grid: what is painted as
## land the band can walk, what is painted as water a ship can take.

## The shader's wobble of the shore moves it by at most this, in leagues.
const WOBBLE := 0.08


func test_every_cell_centre_is_painted_as_what_it_is() -> void:
	var g := MapGrid.norway()
	var art := MapArt.for_grid(g)
	var wrong := PackedStringArray()
	for cy in MapGrid.H:
		for cx in MapGrid.W:
			var c := Vector2i(cx, cy)
			var sd := art.shore_distance(MapGrid.centre(c))
			var ok := sd > WOBBLE if g.is_land(c) else sd < -WOBBLE
			if not ok and wrong.size() < 8:
				wrong.append("%s %.2f" % [c, sd])
	assert_true(wrong.is_empty(), "centres painted wrong: %s" % ", ".join(wrong))


func test_a_step_between_two_cells_of_a_kind_stays_on_that_kind() -> void:
	# Halfway between two side-by-side cells of land is land (the band
	# walks there); halfway between two of water is water (a ship sails).
	var g := MapGrid.norway()
	var art := MapArt.for_grid(g)
	var wrong := PackedStringArray()
	for cy in MapGrid.H - 1:
		for cx in MapGrid.W - 1:
			var c := Vector2i(cx, cy)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if g.is_land(c) != g.is_land(n):
					continue
				var sd := art.shore_distance((MapGrid.centre(c) + MapGrid.centre(n)) / 2.0)
				var ok := sd > 0.0 if g.is_land(c) else sd < 0.0
				if not ok and wrong.size() < 8:
					wrong.append("%s-%s %.2f" % [c, n, sd])
	assert_true(wrong.is_empty(), "steps painted wrong: %s" % ", ".join(wrong))


func test_the_art_is_the_same_every_time() -> void:
	var art := MapArt.for_grid(MapGrid.norway())
	var again := MapArt.new()
	again._build(MapGrid.norway())
	assert_eq(art.field_image.get_data(), again.field_image.get_data())
	assert_eq(art.tiles.size(), again.tiles.size())
