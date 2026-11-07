extends TestCase

const HARALD_EVENTS := ["harald_vow", "harald_takes_trondelag", "harald_takes_west", "hafrsfjord",
	"rollo_outlawed", "eric_bloodaxe", "haakon_the_good"]


func _world(r: WorldRules) -> World:
	var w := World.build_norway(r)
	Faction.load_all(w)
	return w


func _ids(events: Array[Dictionary]) -> Array:
	return events.map(func(e): return e.id)


## Runs years first..last: faction AI, then every due spine event. `choices`
## maps event id -> choice (default "ignore"); `wins` maps event id -> the
## battle outcome to report. Returns event id -> year fired.
func _run(seed_value: int, r: WorldRules, w: World, b: Band, first: int, last: int, choices := {}, wins := {}) -> Dictionary:
	var fired := {}
	var rng := SimRng.new(seed_value)
	var log := PackedStringArray()
	for y in range(first, last + 1):
		w.year = y
		FactionAI.yearly(rng.fork("ai%d" % y), r, w, b, log)
		for ev in Timeline.pending(r, w, y):
			var choice: String = choices.get(ev.id, "ignore")
			var res := Timeline.fire(rng.fork("tl%d" % y), r, w, b, ev, choice, log)
			fired[ev.id] = y
			if res.has("battle_required"):
				Timeline.resolve(r, w, b, ev, choice, wins.get(ev.id, false), log)
	return fired


func _absorbed_by_harald(w: World) -> int:
	var n := 0
	for f in w.factions.values():
		if not f.alive and f.absorbed_by == "harald":
			n += 1
	return n


func test_events_due_by_year_and_fire_once() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	assert_eq(_ids(Timeline.pending(r, w, 866)), ["harald_vow"])
	assert_eq(Timeline.pending(r, w, 867).size(), 0)
	var ev: Dictionary = Timeline.pending(r, w, 866)[0]
	assert_eq(Timeline.outcome_options(ev), ["serve", "resist", "ignore"] as Array[String])
	Timeline.fire(SimRng.new(1), r, w, Band.new(), ev, "ignore", PackedStringArray())
	assert_true(w.timeline_state["harald_vow"])
	assert_eq(Timeline.pending(r, w, 866).size(), 0, "fires once")


func test_gate_harald_unifies_by_880() -> void:
	var r := WorldRules.new()
	var min_h := 999
	var max_h := 0
	var min_a := 999
	var max_a := 0
	for s in 20:
		var w := _world(r)
		_run(s, r, w, Band.new(), 866, 880)
		var h: Faction = w.factions["harald"]
		assert_true(h.alive, "seed %d" % s)
		min_h = mini(min_h, h.holdings.size())
		max_h = maxi(max_h, h.holdings.size())
		var absorbed := _absorbed_by_harald(w)
		min_a = mini(min_a, absorbed)
		max_a = maxi(max_a, absorbed)
		assert_between(absorbed, 2, 9, "petty factions absorbed, seed %d" % s)
		for id in h.holdings:
			assert_eq(w.place(id).faction_id, "harald")
		assert_true(w.timeline_state.get("harald_line", false))
		assert_true(not w.timeline_state.has("rival_bid"), "no fallback when history runs true")
	assert_between(min_h, r.harald_min_holdings, 22, "fewest holdings over seeds")
	assert_between(max_h, r.harald_min_holdings, 22, "most holdings over seeds")
	print("    gate: by 880 over 20 seeds Harald holds %d-%d places (min %d), has absorbed %d-%d factions" % [
			min_h, max_h, r.harald_min_holdings, min_a, max_a])


func test_gate_harald_falls_at_hafrsfjord() -> void:
	var r := WorldRules.new()
	for s in 5:
		var w := _world(r)
		var b := Band.new()
		var before := _run(s, r, w, b, 866, 871)
		assert_true(before.has("harald_takes_west"))
		w.year = 872
		var due := Timeline.pending(r, w, 872)
		assert_eq(_ids(due), ["hafrsfjord"])
		var log := PackedStringArray()
		var res := Timeline.fire(SimRng.new(s), r, w, b, due[0], "fight_against", log)
		assert_true(res.has("battle_required"))
		var br: Dictionary = res.battle_required
		assert_eq(br.side, "against")
		assert_eq(br.tier, CombatTypes.Tier.VETERAN)
		assert_true(br.attackers > 0 and br.text != "")
		assert_true(w.factions["harald"].alive, "nothing happens until the battle is reported")
		var fame := b.fame
		var out := Timeline.resolve(r, w, b, due[0], "fight_against", true, log)
		assert_true(out.get("harald_fell", false))
		assert_true(not w.factions["harald"].alive)
		assert_true(w.factions["harald"].holdings.is_empty())
		assert_eq(b.fame, fame + r.spine_battle_fame)
		var rival: Faction = w.factions[w.timeline_state["rival"]]
		assert_eq(rival.ambition, "expand", "a rival jarl takes up the bid")
		assert_eq(rival.kind, WorldTypes.FactionKind.JARL)
		var after := _run(s + 100, r, w, b, 873, 940)
		for id in HARALD_EVENTS:
			assert_true(not after.has(id), "%s fired after 872" % id)
		assert_true(after.has("rival_bid"), "fallback fired")
		assert_eq(after["rival_bid"], 873)
		assert_true(after.has("iceland_opens") and after.has("orkney_earldom"), "others still fire")
		var again := 0
		for y in range(873, 941):
			for ev in Timeline.pending(r, w, y):
				if ev.id == "rival_bid":
					again += 1
		assert_eq(again, 0, "fallback fires once")


func test_fight_for_harald_and_losing_against_both_let_history_run() -> void:
	var r := WorldRules.new()
	for choice in ["fight_for_harald", "fight_against"]:
		var w := _world(r)
		var b := Band.new()
		_run(1, r, w, b, 866, 871)
		w.year = 872
		var ev: Dictionary = Timeline.pending(r, w, 872)[0]
		var res := Timeline.fire(SimRng.new(1), r, w, b, ev, choice, PackedStringArray())
		assert_eq(res.battle_required.side, "harald" if choice == "fight_for_harald" else "against")
		var rel := FactionAI.relation(w, "harald", "band")
		Timeline.resolve(r, w, b, ev, choice, choice == "fight_for_harald", PackedStringArray())
		assert_true(w.factions["harald"].alive, choice)
		assert_true(not w.factions["rogaland"].alive, choice)
		assert_true(w.timeline_state["harald_line"])
		if choice == "fight_for_harald":
			assert_eq(FactionAI.relation(w, "harald", "band"), rel + r.spine_serve_relation)
			assert_true(b.rank_progress >= r.spine_serve_rank_progress + r.spine_battle_rank_progress)
		else:
			assert_eq(FactionAI.relation(w, "harald", "band"), rel + r.spine_oppose_relation)


func test_resisting_at_lade_and_winning_keeps_lade_free() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	w.year = 868
	var ev: Dictionary = Timeline.pending(r, w, 868)[0]
	assert_eq(ev.id, "harald_takes_trondelag")
	var res := Timeline.fire(SimRng.new(1), r, w, b, ev, "resist", PackedStringArray())
	assert_eq(res.battle_required.side, "against")
	Timeline.resolve(r, w, b, ev, "resist", true, PackedStringArray())
	assert_eq(w.place("lade").faction_id, "lade")
	# Ignoring lets Harald take it.
	var w2 := _world(r)
	w2.year = 868
	var res2 := Timeline.fire(SimRng.new(1), r, w2, b, Timeline.pending(r, w2, 868)[0], "ignore", PackedStringArray())
	assert_eq(res2.conquests, ["lade"])
	assert_eq(w2.place("lade").faction_id, "harald")


func test_serve_rewards_band() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	var fame := b.fame
	Timeline.fire(SimRng.new(1), r, w, b, Timeline.pending(r, w, 866)[0], "serve", PackedStringArray())
	assert_eq(FactionAI.relation(w, "harald", "band"), r.spine_serve_relation)
	assert_eq(b.fame, fame + r.spine_serve_fame)
	assert_eq(b.rank_progress, r.spine_serve_rank_progress)


func test_iceland_opens_and_place_events_need_open_place() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	w.year = 874
	var due := Timeline.pending(r, w, 874)
	assert_eq(_ids(due), ["iceland_opens"])
	var res := Timeline.fire(SimRng.new(1), r, w, Band.new(), due[0], "ignore", PackedStringArray())
	assert_eq(res.place_opened, "iceland")
	# A spine event whose place is not open does not fire.
	var r2 := WorldRules.new()
	r2.spine = [{"year": 870, "id": "early", "precondition": "always", "place": "iceland", "options": ["ignore"], "text": "x", "effects": {}}]
	var w2 := _world(r2)
	assert_eq(Timeline.pending(r2, w2, 870).size(), 0)


func test_harald_line_events_fire_when_history_runs_true() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var fired := _run(7, r, w, Band.new(), 866, 935)
	for id in HARALD_EVENTS:
		assert_true(fired.has(id), "%s fired" % id)
	assert_eq(w.factions["harald"].leader, "Haakon the Good")
	assert_true(not fired.has("rival_bid"))


func test_failed_precondition_brings_fallback() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	FactionAI.absorb(w, w.factions["harald"], w.factions["danes"], PackedStringArray())
	var due := Timeline.pending(r, w, 868)
	assert_eq(_ids(due), ["rival_bid"])
	var res := Timeline.fire(SimRng.new(1), r, w, Band.new(), due[0], "serve", PackedStringArray())
	assert_true(res.text != "")
	var rival: String = w.timeline_state["rival"]
	assert_eq(w.factions[rival].ambition, "expand")
	assert_eq(FactionAI.relation(w, rival, "band"), r.spine_serve_relation)
	assert_eq(Timeline.pending(r, w, 870).size(), 0)
