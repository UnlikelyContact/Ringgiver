## One stand-in saga traced year by year, for reading as a designer reads
## it (docs/design/notes/balance.md): what the bot did each summer, the
## decisions put to him and what he answered (marked when only one answer
## was open), the fights and how they ended, the winter's choices and
## cost, and the year's reckoning (silver, men, land, fame, honor, luck,
## standing, feuds) with anything odd flagged: an action taken that was
## not offered or greyed, a year with no income, a negative or absurd
## number, a standing pinned at the end of its scale. Usage:
##   godot --headless --path game -s tools/saga_trace.gd -- [seed] [bent] [origin] [years] [full|brief] [let_years] [escape]
## "full" prints every line the saga said; "brief" (the default) prints
## the acts, the decisions, the fights and the reckoning. "escape" begins
## the burned hall with its escape, told by the dice (Journey.skip_escape).
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_in := int(args[0]) if args.size() > 0 else 1
	var key := args[1] if args.size() > 1 else "viking"
	var origin := args[2] if args.size() > 2 else "burned_hall"
	var years := int(args[3]) if args.size() > 3 else 5
	var full := args.size() > 4 and args[4] == "full"
	var let := int(args[5]) if args.size() > 5 else 0
	var escape := args.size() > 6 and args[6] == "escape"
	var bent := Way.Id.VIKING
	for w in Way.Id.values():
		if str(Way.def(w).key) == key:
			bent = w
	JourneyBot.let_years = let
	var j := Journey.begin(seed_in, origin, "Egil", escape)
	j.trace_acts = true
	if j.escape_pending():
		print("  the escape (the dice): " + " ".join(j.skip_escape()))
	print("== the saga of seed %d, a %s from the %s, %d years%s" % [seed_in, key, origin, years, (", letting %d pass" % let) if let > 0 else ""])
	print(_state(j))
	var shown := not full
	var offered := {}  # action kind -> [times listed, times enabled]
	var y := 0
	while y < years and not j.c.over:
		var year := j.c.cal.year
		var snap := _snap(j)
		print("\n--- %d (%s, %d days of summer) ---" % [year, j.whereabouts(), j.days_left()])
		var said0 := j.said.size()
		var log0 := j.c.log.size()
		var steps := 0
		var odd := PackedStringArray()
		var acts_line := PackedStringArray()
		while not j.c.over and j.c.cal.year == year and steps < 900:
			steps += 1
			j.quick = true
			j.stepped_winter = true
			j.played_succession = true
			if j.in_winter():
				_flush_acts(acts_line)
				var w0 := _snap(j)
				var talk := PackedStringArray()
				for t in j.winter_hall.talk:
					talk.append(str(t.kind))
				JourneyBot.winter(j, bent)
				var w1 := _snap(j)
				print("  WINTER at %s (%s): talk [%s]; silver %d -> %d, food %d -> %d, men %d -> %d, luck %d -> %d%s" % [
						str(w0.where), str(j.c.band.home), ", ".join(talk), int(w0.silver), int(w1.silver), int(w0.food), int(w1.food),
						int(w0.men), int(w1.men), int(w0.luck), int(w1.luck),
						(", %d years let pass" % (int(j.c.tally.get("years_passed", 0)))) if let > 0 else ""])
				continue
			if not j.decisions.is_empty():
				_flush_acts(acts_line)
				var d := j.current()
				var choice := JourneyBot._answer(j, d, bent)
				var open := PackedStringArray()
				var shut := 0
				for o in d.get("options", []):
					if o.get("enabled", true):
						open.append(str(o.id))
					else:
						shut += 1
				var text := str(d.get("text", "")).replace("\n", " ")
				if text.length() > 150:
					text = text.substr(0, 147) + "..."
				var flag := ""
				if open.size() <= 1:
					flag = "  [ONE ANSWER]" if open.size() == 1 else "  [NO ANSWER OPEN]"
				print("  ? day %d %s%s: %s -> %s  (open: %s%s)%s" % [j.c.cal.day, str(d.kind), (":" + str(d.get("step", d.get("ask", d.get("what", ""))))) if d.has("step") or d.has("ask") or d.has("what") else "",
						text, choice, ", ".join(open), (", %d greyed" % shut) if shut > 0 else "", flag])
				if not open.has(choice):
					odd.append("answered %s, which was not open, to a %s" % [choice, str(d.kind)])
				var said_before := j.said.size()
				var log_before := j.c.log.size()
				j.answer(choice)
				_fights(j, log_before)
				if full:
					for line in j.said.slice(said_before):
						print("      " + line)
				continue
			if not j.can_act():
				break
			if j.roam.moving():
				var sb := j.said.size()
				var lb := j.c.log.size()
				j.travel()
				if full:
					for line in j.said.slice(sb):
						print("      " + line)
				_fights(j, lb)
				continue
			if not shown:
				shown = true
				print("  what he can do on the first free day (day %d at %s, %d oz, %d men, %d hurt):" % [j.c.cal.day, j.whereabouts(), j.c.band.silver,
						j.c.band.fighters(j.c.rules).size(), j.c.band.hurt(j.c.rules).size()])
				for a in j.actions():
					print("    %s%s: %s  (%s)" % ["" if a.get("enabled", true) else "[greyed] ", str(a.id), str(a.label), str(a.get("hint", ""))])
			for a in j.actions():
				var k := str(a.id).split(":")[0]
				var row: Array = offered.get(k, [0, 0])
				row[0] += 1
				row[1] += 1 if a.get("enabled", true) else 0
				offered[k] = row
			JourneyBot._spend(j, bent)
			var a0 := j.acts.size()
			var sb2 := j.said.size()
			var lb2 := j.c.log.size()
			var where := j.whereabouts()
			JourneyBot._act(j, bent)
			for a in j.acts.slice(a0):
				acts_line.append("d%d %s: %s" % [j.c.cal.day, where, a])
				if a.ends_with("(not offered)") or a.ends_with("(greyed)"):
					odd.append("day %d at %s: %s" % [j.c.cal.day, where, a])
			if full:
				_flush_acts(acts_line)
				for line in j.said.slice(sb2):
					print("      " + line)
			_fights(j, lb2)
		_flush_acts(acts_line)
		var now := _snap(j)
		print("  = %s" % _delta(snap, now))
		for k in ["silver", "food", "men"]:
			if int(now[k]) < 0:
				odd.append("%s is %d" % [k, int(now[k])])
		if int(now.silver) <= int(snap.silver) and not j.c.over:
			odd.append("no silver gained this year (%d -> %d)" % [int(snap.silver), int(now.silver)])
		for m in j.c.band.living_men():
			for s in 5:
				if m.stats[s] < 0 or m.stats[s] > 12:
					odd.append("%s has a stat of %d" % [m.display_name, m.stats[s]])
		var pinned := 0
		for h in j.c.band.standing:
			if absi(int(j.c.band.standing[h])) >= 100:
				pinned += 1
		if pinned >= 3:
			odd.append("%d houses at the end of the standing scale" % pinned)
		if steps >= 900:
			odd.append("STALL: 900 steps in the year")
		for o in odd:
			print("  ODD: " + o)
		y += 1
	print("\n" + _state(j))
	var st := PackedStringArray()
	var names: Array = j.c.band.standing.keys()
	names.sort_custom(func(a, b) -> bool: return int(j.c.band.standing[a]) > int(j.c.band.standing[b]))
	for h in names:
		st.append("%s %d" % [str(h), int(j.c.band.standing[h])])
	print("standing: " + ", ".join(st))
	var ks: Array = offered.keys()
	ks.sort()
	var never := PackedStringArray()
	var rows := PackedStringArray()
	for k in ks:
		rows.append("%s %d/%d" % [k, int(offered[k][1]), int(offered[k][0])])
		if int(offered[k][1]) == 0:
			never.append(k)
	print("actions enabled/listed: " + ", ".join(rows))
	if not never.is_empty():
		print("ODD: listed but never open: " + ", ".join(never))
	if j.c.over:
		print("ENDED: " + j.c.over_reason)
	quit(0)


static func _flush_acts(acts: PackedStringArray) -> void:
	if acts.is_empty():
		return
	# Runs of the same act are told once with a count.
	var out := PackedStringArray()
	var last := ""
	var n := 0
	for a in acts:
		var bare := a.substr(a.find(" ") + 1)
		if bare == last:
			n += 1
			continue
		if last != "":
			out.append(last + (" x%d" % n if n > 1 else ""))
		last = bare
		n = 1
	out.append(last + (" x%d" % n if n > 1 else ""))
	var line := "  > "
	for o in out:
		if line.length() + o.length() > 150:
			print(line)
			line = "    "
		line += o + "; "
	print(line)
	acts.clear()


## The fights the campaign told since `from` (its log lines with "against").
static func _fights(j: Journey, from: int) -> void:
	for line in j.c.log.slice(from):
		if line.contains(" against ") or line.contains("holmgang"):
			print("  ! " + line)


static func _snap(j: Journey) -> Dictionary:
	var b := j.c.band
	var wr := j.c.world_rules
	var friends := 0
	var foes := 0
	for h in b.standing:
		if Families.is_friend(wr, b, str(h)):
			friends += 1
		elif Families.is_foe(wr, b, str(h)):
			foes += 1
	return {"silver": b.silver, "food": b.food, "men": b.fighters().size(), "all": b.living_men().size(), "land": b.land,
		"fame": b.fame, "honor": b.honor, "luck": b.luck, "friends": friends, "foes": foes, "feuds": b.unsettled_feuds().size(),
		"captives": b.captives, "thralls": b.thralls.size(), "ship": WorldTypes.SHIP_NAMES[b.ship.kind] if b.ship != null else "none",
		"fights": int(j.c.tally.battles), "deaths": int(j.c.tally.deaths), "where": j.whereabouts(), "sold": int(b.law.get("sold_oz", 0)),
		"outlaw": Outlawry.is_outlawed(b, j.c.cal), "leader": b.leader.display_name if b.leader != null else "-",
		"age": b.leader.age if b.leader != null else 0, "vengeance": b.vengeance}


static func _delta(a: Dictionary, b: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ["silver", "food", "men", "land", "fame", "honor", "luck", "friends", "foes", "feuds", "captives", "thralls", "fights", "deaths", "sold"]:
		var d := int(b[k]) - int(a[k])
		parts.append("%s %d%s" % [k, int(b[k]), (" (%+d)" % d) if d != 0 else ""])
	parts.append("ship " + str(b.ship))
	if bool(b.outlaw):
		parts.append("OUTLAW")
	if str(a.leader) != str(b.leader):
		parts.append("new leader " + str(b.leader))
	if str(a.vengeance) != "" and str(b.vengeance) == "":
		parts.append("VENGEANCE TAKEN")
	return ", ".join(parts)


static func _state(j: Journey) -> String:
	var s := _snap(j)
	return "%s, %d winters, at %s: %d oz, %d food, %d men (%d in all), land %d, ship %s, fame %d, honor %d, luck %d, feuds %d, vengeance on %s" % [
			str(s.leader), int(s.age), str(s.where), int(s.silver), int(s.food), int(s.men), int(s.all), int(s.land), str(s.ship),
			int(s.fame), int(s.honor), int(s.luck), int(s.feuds), str(s.vengeance) if str(s.vengeance) != "" else "nobody"]
