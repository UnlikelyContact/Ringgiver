extends TestCase
## The free-roam map's ground and water (MapGrid): every place on the
## coast, all of them joined by sea, a band that walks the land and needs
## a ship for the water.


func test_every_place_stands_on_land_with_water_at_its_door() -> void:
	var g := MapGrid.norway()
	for d in NorwayData.PLACES:
		var c: Vector2i = g.place_cell[d.id]
		assert_true(g.is_land(c), "%s stands on land" % d.id)
		var wet := false
		for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			wet = wet or g.is_sea(c + s)
		assert_true(wet, "%s has water at its door" % d.id)
		assert_eq(g.place_at(d.pos), d.id)


func test_all_the_places_are_joined_by_sea() -> void:
	var g := MapGrid.norway()
	var home: Vector2i = g.place_cell["hardanger"]
	var unreached := PackedStringArray()
	for d in NorwayData.PLACES:
		if d.id == "hardanger":
			continue
		var p := g.find_path(home, g.place_cell[d.id], 2.0, 7.0, true)
		if (p.cells as Array).is_empty():
			unreached.append(d.id)
	assert_true(unreached.is_empty(), "no way by sea to: %s" % ", ".join(unreached))


func test_a_band_on_foot_cannot_cross_water_and_a_ship_is_quicker() -> void:
	var g := MapGrid.norway()
	var hardanger: Vector2i = g.place_cell["hardanger"]
	var fitjar: Vector2i = g.place_cell["fitjar"]
	var orkney: Vector2i = g.place_cell["orkney"]
	var on_foot := g.find_path(hardanger, fitjar, 2.0, 0.0, false)
	var by_ship := g.find_path(hardanger, fitjar, 2.0, 7.0, true)
	assert_true(not (on_foot.cells as Array).is_empty(), "the neighbours can be walked to")
	assert_true(not (by_ship.cells as Array).is_empty())
	assert_true(by_ship.days < on_foot.days, "by ship %.1f days, on foot %.1f" % [by_ship.days, on_foot.days])
	for i in (on_foot.cells as Array).size():
		assert_true(g.is_land(on_foot.cells[i]), "a walker stays on land")
		assert_true(not on_foot.aboard[i])
	assert_true((g.find_path(hardanger, orkney, 2.0, 0.0, false).cells as Array).is_empty(), "nobody walks to Orkney")
	assert_true(not (g.find_path(hardanger, orkney, 2.0, 7.0, true).cells as Array).is_empty(), "a ship gets there")
	# A small boat keeps out of the deep, so it does not cross: since the
	# wider world gave the Baltic a southern shore it can creep round by
	# the Wendish, Frisian and English coasts, many times as long.
	var creep := g.find_path(hardanger, orkney, 2.0, 5.0, true, Vector2i(-1, -1), false)
	assert_true((creep.cells as Array).is_empty() or creep.days > 4.0 * g.find_path(hardanger, orkney, 2.0, 7.0, true).days, "not across in a færing")
	print("    gate: Hardanger to Fitjar: %.1f days on foot, %.1f by ship; to Orkney %.1f by ship" % [
			on_foot.days, by_ship.days, g.find_path(hardanger, orkney, 2.0, 7.0, true).days])


func test_a_ship_left_on_the_beach_must_be_gone_back_to() -> void:
	var g := MapGrid.norway()
	var hardanger: Vector2i = g.place_cell["hardanger"]
	var fitjar: Vector2i = g.place_cell["fitjar"]
	var orkney: Vector2i = g.place_cell["orkney"]
	# The band is at Hardanger, its ship beached at Fitjar: to reach Orkney
	# it must walk to her first.
	var p := g.find_path(hardanger, orkney, 2.0, 7.0, false, fitjar)
	assert_true(not (p.cells as Array).is_empty())
	assert_true((p.cells as Array).has(fitjar), "by way of the ship")
	var boarded := (p.cells as Array).find(fitjar)
	assert_true(p.aboard[boarded], "aboard from there")
	for i in boarded:
		assert_true(not p.aboard[i] and g.is_land(p.cells[i]), "on foot until then")
