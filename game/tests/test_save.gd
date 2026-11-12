extends TestCase
## The save (docs/design/notes/save.md): the codec keeps every value
## exactly and every shared object as one, tolerates an older build's
## save, refuses what cannot be saved; a saga saved anywhere and loaded
## goes on exactly as the one never saved (the continuation test, a few
## save points here; the whole matrix is tools/save_check.gd); and the
## files on disk are checked, rolled and carried as text.


func _back(v: Variant, rep: Dictionary = {}) -> Variant:
	var text := JSON.stringify(SaveCodec.encode(v), "", false)
	return SaveCodec.decode(JSON.parse_string(text), rep)


func test_values_round_trip_exactly() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, -4), Vector2i(170, 139)]
	var ints: Array[int] = [1, 2, 3]
	var names := PackedStringArray(["plain", "~tilde", "$dollar", ""])
	var v := {
		"big": 9007199254740993, "neg": -9223372036854775807, "small": -3, "zero_f": 0.0, "f": 0.1 + 0.2,
		"third": 1.0 / 3.0, "inf": INF, "huge": 1e300, "tiny": 5e-324, "s": "~starts with a tilde", "$k": "dollar key",
		"~k": "tilde key", "sn": &"a_name", "nil": null, "yes": true, "v2": Vector2(0.1, 1.0 / 3.0), "inf2": Vector2.INF,
		"v2i": Vector2i(-1, 7), "col": Color(0.2, 0.4, 0.6, 0.8), "rect": Rect2(1.5, 2, 3, 4), "cells": cells, "ints": ints,
		"names": names, "bytes": PackedByteArray([0, 1, 254, 255]), "pi": PackedInt32Array([5, -6]),
		"pf": PackedFloat32Array([0.1, 2.5]), "pd": PackedFloat64Array([0.1, 1.0 / 7.0]),
		"fn": Callable(Sandbox, "choose_fight"), "nested": [{"a": [1, 2.5, "x"]}, []],
		7: "an int key", Vector2i(2, 3): "a cell key", 2.5: "a float key",
	}
	var b: Dictionary = _back(v)
	assert_eq(b.keys().size(), v.keys().size())
	for k in v:
		assert_true(b.has(k), "key %s comes back" % var_to_str(k))
		assert_eq(typeof(b.get(k)), typeof(v[k]), "the type of %s" % var_to_str(k))
		if typeof(v[k]) != TYPE_CALLABLE:
			assert_eq(var_to_str(b.get(k)), var_to_str(v[k]), "the value of %s" % var_to_str(k))
	assert_eq(b.keys(), v.keys(), "the keys in the order they were put in")
	assert_true((b.cells as Array).is_typed() and (b.cells as Array).get_typed_builtin() == TYPE_VECTOR2I, "a typed array stays typed")
	assert_true((b.ints as Array).is_typed(), "Array[int] stays typed")
	assert_eq((b.fn as Callable).call(FightOffer.new()), Sandbox.choose_fight(FightOffer.new()), "a static function is found again")


func test_shared_objects_come_back_as_one() -> void:
	var band := Band.new()
	var m := Man.new()
	m.id = 4
	m.display_name = "Grim"
	band.men.append(m)
	band.leader = m
	var root := {"band": band, "decision": {"man": m}, "by_man": {m: "a man as a key"}}
	root["self"] = root.duplicate()  # a second dictionary holding the same objects
	var b: Dictionary = _back(root)
	var bb: Band = b.band
	assert_true(bb.leader == bb.men[0], "the leader is the man in the band")
	assert_true(b.decision.man == bb.leader, "and the man in the decision")
	assert_true((b.by_man as Dictionary).has(bb.leader), "and the dictionary's key")
	assert_eq(bb.men.get_typed_script(), Man, "Array[Man] stays Array[Man]")
	assert_eq(bb.leader.display_name, "Grim")


func test_rng_goes_on_exactly() -> void:
	var r := SimRng.new(12345)
	for i in 17:
		r.randf()
	var b: SimRng = _back(r)
	for i in 50:
		assert_eq(b.randi_range(0, 1 << 30), r.randi_range(0, 1 << 30), "draw %d" % i)
	assert_eq(b.fork("x").d6(), r.fork("x").d6())


func test_inner_class_and_constructor_arguments() -> void:
	var p := Roam.Party.new()
	p.kind = "raiders"
	p.pos = Vector2(10.25, 3.5)
	var o := Objective.new(Objective.Kind.THE_HALL, 1, 77)  # _init takes arguments
	var b: Array = _back([p, o])
	assert_true(b[0] is Roam.Party, "Roam.Party is made again")
	assert_eq(b[0].pos, p.pos)
	assert_true(b[1] is Objective and b[1].kind == Objective.Kind.THE_HALL and b[1].attacker == 1)


func test_an_older_save_loads_with_the_defaults() -> void:
	var data := SaveCodec.encode(Calendar.new(870))
	var e: Dictionary = data.objects[0]
	(e.p as Dictionary).erase("day")  # a field this save did not know
	e.p["gone_field"] = 5  # a field since removed
	e.p["year"] = "not a year"  # a field whose type changed
	e.p["season"] = "~f1.0"  # an int field met as a float: converted
	var rep := {}
	var c: Calendar = SaveCodec.decode(JSON.parse_string(JSON.stringify(data, "", false)), rep)
	assert_eq(c.day, Calendar.new().day, "a missing field keeps its default")
	assert_eq(c.year, Calendar.new().year, "a mistyped field keeps its default")
	assert_eq(int(c.season), 1)
	assert_eq(int(rep.unknown_props), 1)
	assert_eq(int(rep.missing_props), 1)
	assert_eq(int(rep.mismatched), 1)
	assert_eq(int(rep.converted), 1)
	# An untyped list from an old save fits a typed property when its items do.
	var m := SaveCodec.encode(Man.new())
	m.objects[0].p["stats"] = [4, 5, 6, 7, 8]
	var back: Man = SaveCodec.decode(m)
	assert_eq(back.stats[4], 8)
	assert_true(back.stats.is_typed())
	# A class that no longer exists becomes null, counted.
	var gone := {"root": {"$r": 0}, "objects": [{"c": "NoSuchClassAnyMore", "p": {}}]}
	var rep2 := {}
	assert_eq(SaveCodec.decode(gone, rep2), null)
	assert_eq(int(rep2.unknown_classes), 1)


func test_rules_are_saved_as_their_difference() -> void:
	var c := Campaign.new(3)
	var data := SaveCodec.encode(c.rules)
	assert_eq((data.objects[0].p as Dictionary).size(), 0, "default rules save nothing")
	c.rules.start_year = 900
	data = SaveCodec.encode(c.rules)
	assert_eq((data.objects[0].p as Dictionary).keys(), ["start_year"])
	var back: CampaignRules = SaveCodec.decode(JSON.parse_string(JSON.stringify(data, "", false)))
	assert_eq(back.start_year, 900)


func test_what_cannot_be_saved_is_named() -> void:
	var errs := PackedStringArray()
	var n := Node.new()
	SaveCodec.encode({"f": func() -> int: return 1, "node": n}, true, errs)
	n.free()
	assert_eq(errs.size(), 2, str(errs))
	# The campaign's own default policy is a lambda its new() sets again.
	errs = PackedStringArray()
	SaveCodec.encode(Campaign.new(1), true, errs)
	assert_eq(errs.size(), 0, str(errs))


## The whole of a played saga saves without an error in strict mode, and
## a saga's map grid is the shared one, saved as a token.
func test_a_saga_encodes_strictly() -> void:
	var j := Journey.begin(2, "burned_hall", "Egil", true)
	var errs := PackedStringArray()
	var data := SaveCodec.encode(j, true, errs)
	assert_eq(errs.size(), 0, str(errs))
	var grids := 0
	for e in data.objects:
		if str(e.c) == "MapGrid":
			grids += 1
			assert_eq(str(e.get("s", "")), "norway")
	assert_eq(grids, 1)
	var k: Journey = _back(j)
	assert_true(k.roam.grid == MapGrid.norway(), "the loaded saga walks the one grid")
	assert_eq(SaveCodec.digest(k), SaveCodec.digest(j))


## The continuation test at a few save points (the matrix is in
## tools/save_check.gd): saved, loaded, and both played on a year by the
## stand-in player, they must end the same in every field and every word.
func test_continuation_at_save_points() -> void:
	var cases := [
		["younger_son", Way.Id.VIKING, 1, "road"],
		["burned_hall", Way.Id.TRADER, 2, "start"],  # the escape's fight waiting
		["freedman", Way.Id.LAWMAN, 3, "battle"],  # in the middle of a fight
		["younger_son", Way.Id.KINGS_MAN, 4, "winter:2"],
		["burned_hall", Way.Id.SKALD, 5, "grave_ale:1"],
		["freedman", Way.Id.BERSERK, 1, "years"],
		["younger_son", Way.Id.TRADER, 2, "gen2"],
	]
	var checked := 0
	for cs in cases:
		var j := SavePlay.reach(int(cs[2]), str(cs[0]), int(cs[1]), str(cs[3]))
		if j == null:
			SavePlay.reset_bot()
			continue
		var r := SavePlay.continue_check(j, int(cs[1]), 1)
		SavePlay.reset_bot()
		checked += 1
		assert_true(r.ok, "%s %s seed %d at %s: %s %s %s" % [cs[0], Way.def(int(cs[1])).key, cs[2], cs[3], r.at_save, r.after, r.told])
		var rep: Dictionary = r.report
		assert_eq(int(rep.mismatched) + int(rep.unknown_props) + int(rep.unknown_classes), 0, str(rep))
	assert_true(checked >= 6, "the save points were reached: %d" % checked)


func test_store_writes_reads_and_refuses_the_bad() -> void:
	SaveStore.dir = "user://test_saves/"
	for slot in [SaveStore.AUTO, SaveStore.BACKUP] + SaveStore.SLOTS:
		SaveStore.remove(slot)
	var j := Journey.begin(6, "younger_son", "Egil")
	SavePlay.play_steps(j, Way.Id.VIKING, 30)
	assert_eq(SaveStore.write(SaveStore.AUTO, j, {"hints": ["where"]}), "")
	var h := SaveStore.head(SaveStore.AUTO)
	assert_eq(int(h.format), SaveStore.FORMAT)
	assert_eq(int(h.summary.year), j.c.cal.year)
	assert_true(SaveStore.summary_line(h.summary).begins_with("Egil"), SaveStore.summary_line(h.summary))
	var r := SaveStore.read(SaveStore.AUTO)
	assert_false_err(r)
	assert_eq(SaveCodec.digest(r.journey), SaveCodec.digest(j))
	assert_eq(r.view.hints, ["where"])
	# The autosave keeps the one before it.
	SavePlay.play_steps(j, Way.Id.VIKING, 10)
	assert_eq(SaveStore.write(SaveStore.AUTO, j), "")
	assert_true(SaveStore.exists(SaveStore.BACKUP), "the one before is kept")
	assert_eq(int(SaveStore.head(SaveStore.BACKUP).summary.day), int(h.summary.day))
	# Carried as text to another slot.
	var text := SaveStore.export_text(SaveStore.AUTO)
	assert_true(text.begins_with(SaveStore.TEXT_PREFIX))
	assert_eq(SaveStore.import_text("\n" + text.substr(0, 40) + "\n" + text.substr(40) + " ", "slot2"), "", "line breaks and spaces are forgiven")
	assert_eq(SaveCodec.digest(SaveStore.read("slot2").journey), SaveCodec.digest(j))
	assert_ne(SaveStore.import_text("hello", "slot3"), "", "not a save")
	assert_ne(SaveStore.import_text(text.substr(0, text.length() - 20), "slot3"), "", "cut short")
	assert_true(not SaveStore.exists("slot3"))
	# A damaged file, a newer one and a stranger are reported, never loaded.
	var bytes := FileAccess.get_file_as_bytes(SaveStore.path_of("slot2"))
	bytes[bytes.size() - 30] = bytes[bytes.size() - 30] ^ 0x5a
	_put("slot3", bytes)
	assert_true(SaveStore.head("slot3").has("error"), "damaged: the head says so")
	assert_true(SaveStore.read("slot3").has("error"))
	var newer := ("%s\n%s\n" % [SaveStore.MAGIC, JSON.stringify({"format": SaveStore.FORMAT + 1})]).to_utf8_buffer()
	_put("slot3", newer)
	assert_true(str(SaveStore.head("slot3").get("error", "")).contains("newer"))
	_put("slot3", "not a save at all".to_utf8_buffer())
	assert_true(SaveStore.read("slot3").has("error"))
	_put("slot3", PackedByteArray())
	assert_true(SaveStore.head("slot3").has("error"))
	for slot in [SaveStore.AUTO, SaveStore.BACKUP] + SaveStore.SLOTS:
		SaveStore.remove(slot)
	SaveStore.dir = SaveStore.DIR


func assert_false_err(r: Dictionary) -> void:
	assert_true(not r.has("error"), str(r.get("error", "")))


func _put(slot: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(SaveStore.path_of(slot), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Every static variable in sim/ is named in SaveCodec.STATICS with why it
## needs no saving: a new one that holds a saga's state would slip past
## the continuation test (the copy shares it in one process).
func test_every_static_in_the_sim_is_accounted_for() -> void:
	var re := RegEx.create_from_string("(?m)^static var (\\w+)")
	var cls_re := RegEx.create_from_string("(?m)^class_name (\\w+)")
	for path in _scripts("res://sim"):
		var text := FileAccess.get_file_as_string(path)
		var cm := cls_re.search(text)
		var cls := cm.get_string(1) if cm != null else path
		for m in re.search_all(text):
			var key := "%s.%s" % [cls, m.get_string(1)]
			assert_true(SaveCodec.STATICS.has(key), "%s is a static the save does not know: name it in SaveCodec.STATICS, or move it into an object" % key)


func _scripts(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for name in dir.get_directories():
		out.append_array(_scripts(dir_path + "/" + name))
	for name in dir.get_files():
		if name.ends_with(".gd"):
			out.append(dir_path + "/" + name)
	return out
