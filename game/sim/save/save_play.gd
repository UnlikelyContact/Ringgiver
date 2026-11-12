class_name SavePlay
extends RefCounted
## The proof that a save keeps everything (docs/design/notes/save.md, "The
## continuation test"): a saga is played by the stand-in player
## (JourneyBot), saved, loaded into a new graph, and both the original and
## the loaded copy are played on the same way; any difference afterwards
## is state the save did not carry. Nothing here knows a field of the sim:
## the comparison is the codec's own encoding of the whole graph, so a
## field another hand adds tomorrow is checked as soon as it exists.
## Used by tests/test_save.gd and tools/save_check.gd.


## One move of the stand-in player, as `JourneyBot.play_year` makes them:
## the winter kept, a decision answered, the road walked, points spent and
## a deed done. A fight left for the battle view is fought out by the
## leaders' AIs (the burned hall's escape as `skip_escape` tells it).
## Returns false when the saga is over or nothing more can be done.
static func step(j: Journey, bent: int) -> bool:
	j.quick = true
	j.stepped_winter = true
	j.played_succession = true
	if j.c.over:
		return false
	if not j.fight.is_empty():
		if j.escape_pending():
			j.skip_escape()
		else:
			var battle: Battle = j.fight.built.battle
			j.fight_done(battle.run())
		return true
	if j.in_winter():
		JourneyBot.winter(j, bent)
		return true
	if not j.decisions.is_empty():
		j.answer(JourneyBot._answer(j, j.current(), bent))
		return true
	if not j.can_act():
		return false
	if j.roam.moving():
		j.travel()
		return true
	JourneyBot._spend(j, bent)
	JourneyBot._act(j, bent)
	return true


## Plays `n` moves (fewer if the saga ends). Returns the moves made.
static func play_steps(j: Journey, bent: int, n: int) -> int:
	for i in n:
		if not step(j, bent):
			return i
	return n


## Plays until `years` more years have begun (or the saga ends, or the
## guard of moves runs out).
static func play_years(j: Journey, bent: int, years: int, guard := 4000) -> void:
	var until := j.c.cal.year + years
	while j.c.cal.year < until and guard > 0 and step(j, bent):
		guard -= 1


## Plays until `ok` (a Callable taking the journey) is true, at most
## `guard` moves. Returns whether it came true.
static func play_until(j: Journey, bent: int, ok: Callable, guard := 3000) -> bool:
	while guard > 0:
		if ok.call(j):
			return true
		if not step(j, bent):
			return ok.call(j)
		guard -= 1
	return false


## A copy made the way the game makes one: encoded, written out as text,
## read back and decoded. `report_out` gets the decoder's report.
static func reload(j: Journey, report_out: Dictionary = {}) -> Journey:
	var text := JSON.stringify(SaveCodec.encode(j), "", false)
	var data: Variant = JSON.parse_string(text)
	return SaveCodec.decode(data, report_out) as Journey


## The plain facts the brief names, for a reader of a divergence: the
## chronicles, the silver, the men, the standings, the houses' tidings,
## the parties' places and the saga's lines.
static func facts(j: Journey) -> Dictionary:
	var c := j.c
	var parties := []
	for p in j.roam.parties:
		parties.append(var_to_str(p.pos))
	var men := []
	for m in c.band.men:
		men.append("%s %d %d" % [m.display_name, m.loyalty, int(m.alive)])
	return {
		"year": c.cal.year, "day": c.cal.day, "silver": c.band.silver, "men": men,
		"standing": c.band.standing.duplicate(), "band_chronicle": c.band.chronicle.size(),
		"world_chronicle": c.world.chronicle.size(),
		"tidings": c.world.families.tidings.hash() if c.world.families != null else 0,
		"pos": var_to_str(j.roam.pos), "parties": parties, "said": j.said.size(),
		"said_tail": j.said.slice(maxi(0, j.said.size() - 3)),
	}


## Where two graphs differ, as paths ("root.c.band.men[3].loyalty: 52 /
## 53"), at most `limit` lines. Walks the two encodings side by side, so
## it knows no class; empty when they are the same.
static func compare(a: Variant, b: Variant, limit := 12) -> PackedStringArray:
	var ea := SaveCodec.encode(a)
	var eb := SaveCodec.encode(b)
	var out := PackedStringArray()
	_walk(ea, eb, ea.root, eb.root, "root", out, {}, limit)
	return out


static func _walk(ea: Dictionary, eb: Dictionary, va: Variant, vb: Variant, path: String, out: PackedStringArray,
		seen: Dictionary, limit: int) -> void:
	if out.size() >= limit:
		return
	if va is Dictionary and vb is Dictionary and (va as Dictionary).has("$r") and (vb as Dictionary).has("$r"):
		var key := "%d:%d" % [int(va["$r"]), int(vb["$r"])]
		if seen.has(key):
			return
		seen[key] = true
		var oa: Dictionary = ea.objects[int(va["$r"])]
		var ob: Dictionary = eb.objects[int(vb["$r"])]
		if str(oa.c) != str(ob.c):
			out.append("%s: a %s / a %s" % [path, oa.c, ob.c])
			return
		_walk(ea, eb, oa.get("p", {}), ob.get("p", {}), path, out, seen, limit)
		_walk(ea, eb, oa.get("m", {}), ob.get("m", {}), path + "@meta", out, seen, limit)
		return
	if va is Dictionary and vb is Dictionary:
		for k in va:
			if not (vb as Dictionary).has(k):
				out.append("%s.%s: only in the first" % [path, k])
			else:
				_walk(ea, eb, va[k], vb[k], "%s.%s" % [path, k], out, seen, limit)
			if out.size() >= limit:
				return
		for k in vb:
			if not (va as Dictionary).has(k):
				out.append("%s.%s: only in the second" % [path, k])
		if (va as Dictionary).keys() != (vb as Dictionary).keys() and out.size() < limit:
			var same := true
			for k in va:
				same = same and (vb as Dictionary).has(k)
			if same and (va as Dictionary).size() == (vb as Dictionary).size():
				out.append("%s: the same keys in another order" % path)
		return
	if va is Array and vb is Array:
		if (va as Array).size() != (vb as Array).size():
			out.append("%s: %d items / %d" % [path, (va as Array).size(), (vb as Array).size()])
		for i in mini((va as Array).size(), (vb as Array).size()):
			_walk(ea, eb, va[i], vb[i], "%s[%d]" % [path, i], out, seen, limit)
			if out.size() >= limit:
				return
		return
	if typeof(va) != typeof(vb) or va != vb:
		out.append("%s: %s / %s" % [path, _short(va), _short(vb)])


static func _short(v: Variant) -> String:
	var s := JSON.stringify(v, "", false)
	return s if s.length() <= 80 else s.left(77) + "..."


## The continuation check at one save point: `j` is saved and loaded, then
## the original and the copy are both played on by `bent` for `years`
## years (or `steps` moves when `years` is 0). Returns {ok, at_save (the
## copy differs at once: the codec), after (where they went apart, by the
## encoding), told (where they went apart by what the saga says, which
## does not trust the codec to see everything), report (the decoder's),
## digest}. `j` itself is played on.
static func continue_check(j: Journey, bent: int, years := 1, steps := 0) -> Dictionary:
	var rep := {}
	var k := reload(j, rep)
	var out := {"ok": true, "at_save": PackedStringArray(), "after": PackedStringArray(), "told": PackedStringArray(),
			"report": rep, "digest": ""}
	if SaveCodec.digest(j) != SaveCodec.digest(k):
		out.ok = false
		out.at_save = compare(j, k)
		return out
	if years > 0:
		play_years(j, bent, years)
		play_years(k, bent, years)
	else:
		play_steps(j, bent, steps)
		play_steps(k, bent, steps)
	var da := SaveCodec.digest(j)
	out.digest = da
	if da != SaveCodec.digest(k):
		out.ok = false
		out.after = compare(j, k)
	var fa := told(j)
	var fb := told(k)
	for key in fa:
		if var_to_str(fa[key]) != var_to_str(fb.get(key)):
			out.ok = false
			(out.told as PackedStringArray).append("%s: %s / %s" % [key, _short(fa[key]), _short(fb.get(key))])
	return out


## What the saga says of a journey through its own functions, not the
## codec: the facts, the status line, the saga as told (chapters and
## all), the household. A piece of state the codec never saw shows here.
static func told(j: Journey) -> Dictionary:
	var out := facts(j)
	out["status"] = j.status()
	out["saga"] = j.saga()
	out["chapters"] = Chronicle.chapters(j.c.band)
	out["household"] = j.household()
	out["decision"] = str(j.current().get("text", ""))
	return out


# --- Save points ----------------------------------------------------------------------

## The points in a saga where the continuation is checked (the tool runs
## them all; the test a few).
const POINTS := ["start", "road", "sea", "decision", "fight_offer", "battle", "winter:0", "winter:1", "winter:2",
		"winter:3", "winter:4", "grave_ale", "grave_ale:1", "ended", "years", "gen2", "year3"]


## A new saga brought to save point `point` by the stand-in player.
## Returns null when this saga never comes to it (no sea, no fight).
## Sets JourneyBot's statics the point needs; `reset_bot` puts them back.
static func reach(seed_in: int, origin: String, bent: int, point: String) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil", origin == "burned_hall")
	j.quick = true
	j.stepped_winter = true
	j.played_succession = true
	var parts := point.split(":")
	var ok := true
	match parts[0]:
		"start":
			pass
		"road":
			ok = play_until(j, bent, func(x: Journey) -> bool: return x.roam.moving() and not x.roam.afloat() and x.c.cal.day >= 20)
		"sea":
			ok = play_until(j, bent, func(x: Journey) -> bool: return x.roam.afloat())
		"decision":
			ok = play_until(j, bent, func(x: Journey) -> bool: return not x.decisions.is_empty() and str(x.current().kind) != "fight")
		"fight_offer":
			ok = play_until(j, bent, func(x: Journey) -> bool: return not x.decisions.is_empty() and str(x.current().kind) == "fight")
		"battle":
			ok = _into_battle(j, bent)
		"winter":
			ok = play_until(j, bent, func(x: Journey) -> bool: return x.in_winter())
			for i in int(parts[1]) if parts.size() > 1 else 0:
				if j.in_winter():
					j.winter_choose("next")
		"grave_ale":
			play_years(j, bent, 1)
			ok = _kill(j)
			for i in int(parts[1]) if parts.size() > 1 else 0:
				if not j.decisions.is_empty():
					j.answer(JourneyBot._answer(j, j.current(), bent))
		"ended":
			JourneyBot.ends = true
			play_years(j, bent, 1)
			ok = _kill(j, "old") and play_until(j, bent, func(x: Journey) -> bool: return x.c.over, 200)
		"years":
			JourneyBot.let_years = 3
			ok = play_until(j, bent, func(x: Journey) -> bool: return not x.years_told.is_empty())
		"gen2":
			play_years(j, bent, 1)
			var first := j.c.band.leader.display_name
			ok = _kill(j) and play_until(j, bent, func(x: Journey) -> bool:
				return x.decisions.is_empty() and not x.in_winter() and x.c.band.leader != null and x.c.band.leader.display_name != first and x.c.cal.day > 30)
		"year3":
			play_years(j, bent, 2)
			ok = play_until(j, bent, func(x: Journey) -> bool: return x.c.cal.day >= 40)
	return j if ok else null


static func reset_bot() -> void:
	JourneyBot.ends = false
	JourneyBot.let_years = 0


## A fight taken and fought for a few rounds on the battle screen's terms
## (not told quickly), so the save is made in the middle of the battle.
static func _into_battle(j: Journey, bent: int) -> bool:
	for tries in 6:
		if not play_until(j, bent, func(x: Journey) -> bool: return not x.decisions.is_empty() and str(x.current().kind) == "fight"):
			return false
		var d := j.current()
		var pick := str(d.options[0].id)
		for o in d.options:
			if str(o.id) == str(FightOffer.Choice.TAKE_THE_FIELD):
				pick = str(o.id)
		j.quick = false
		j.answer(pick)
		j.quick = true
		if not j.fight.is_empty():
			var battle: Battle = j.fight.built.battle
			for i in 4:
				battle.run_round()
			return not battle.is_over()
	return false


## The leader dies now (as the tests kill him): the death card and the
## grave-ale follow in `decisions`.
static func _kill(j: Journey, cause := "battle") -> bool:
	if j.c.over or j.c.band.leader == null or not j.c.band.leader.alive or not j.c.pending_death.is_empty():
		return false
	if j.in_winter():
		JourneyBot.winter(j, Way.Id.VIKING)
	j.c.band.leader.alive = false
	j.c.succession(cause)
	j._settle()
	return true
