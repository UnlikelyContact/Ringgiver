extends TestCase


func _band(n: int, food: int) -> Band:
	var b := Band.new()
	b.leader = Man.new()
	b.leader.display_name = "Hrafn"
	b.leader.is_leader = true
	b.leader.id = b.next_id()
	for i in n:
		var m := Man.new()
		m.display_name = "man%d" % i
		m.stats = [4, 4, 4, 4, 4]
		b.add_man(m)
	b.food = food
	return b


func _quiet_rules() -> CampaignRules:
	var r := CampaignRules.new()
	r.events_per_turn = 0
	r.hall_base_seats = 20
	return r


## Runs a whole winter; `plan_fn(band, cal) -> WinterPlan`. Returns reports.
func _winter(seed: int, r: CampaignRules, b: Band, plan_fn: Callable) -> Array[WinterReport]:
	var rng := SimRng.new(seed)
	var cal := Calendar.new(870)
	cal.start_winter()
	var out: Array[WinterReport] = []
	for t in 4:
		var plan: WinterPlan = plan_fn.call(b, cal)
		out.append(Winter.run_turn(rng, r, b, cal, plan, PackedStringArray()))
		if t < 3:
			cal.advance_turn()
	return out


func _hunters(n: int) -> Callable:
	return func(b: Band, _cal: Calendar) -> WinterPlan:
		var p := WinterPlan.new()
		for i in b.men.size():
			p.tasks[b.men[i].id] = CampaignTypes.Task.HUNT if i < n else CampaignTypes.Task.DRILL
		return p


## Gate: twelve men and the leader (thirteen mouths) with forty rations,
## enough for ten mouths through the four turns, and no hunting: the stores
## run dry and men go hungry at the end of winter. Two hunters keep everyone
## fed every turn, on every seed.
func test_gate_food_shortage_and_hunters() -> void:
	var r := _quiet_rules()
	for seed in 200:
		var b := _band(12, 40)
		var reps := _winter(seed, r, b, _hunters(0))
		assert_eq(reps[0].unfed_ids().size(), 0, "early winter everyone eats")
		assert_eq(reps[1].unfed_ids().size(), 0, "Yule everyone eats")
		assert_true(reps[3].unfed_ids().size() >= 10, "most go hungry at the thaw")
		assert_true(not reps[3].unfed_ids().has(b.leader.id), "the leader eats first")
		var b2 := _band(12, 40)
		var reps2 := _winter(seed, r, b2, _hunters(2))
		for rep in reps2:
			assert_eq(rep.unfed_ids().size(), 0, "two hunters feed the band (seed %d)" % seed)


func test_lowest_seated_go_hungry_first() -> void:
	var r := _quiet_rules()
	var b := _band(5, 4)
	var rng := SimRng.new(1)
	var cal := Calendar.new(870)
	cal.start_winter()
	var rep := Winter.run_turn(rng, r, b, cal, WinterPlan.new(), PackedStringArray())
	var h: Hall = b.hall
	assert_true(rep.fed[b.leader.id])
	assert_true(rep.fed[h.seating[2]])
	assert_true(not rep.fed[h.seating[3]] and not rep.fed[h.seating[4]])
	assert_eq(b.food, 0)
	assert_eq(rep.food_eaten, 4)


func test_household_skill_stretches_food() -> void:
	var r := _quiet_rules()
	var b := _band(5, 10)
	b.household_skill = 3
	var cal := Calendar.new(870)
	cal.start_winter()
	var rep := Winter.run_turn(SimRng.new(1), r, b, cal, WinterPlan.new(), PackedStringArray())
	assert_eq(rep.food_eaten, 3, "six mouths, three saved")
	assert_eq(b.food, 7)


func test_gate_storehouse_keeps_stores() -> void:
	var r := _quiet_rules()
	var cal := Calendar.new(870)
	cal.start_winter()
	var b := _band(2, 100)
	var rep := Winter.run_turn(SimRng.new(1), r, b, cal, WinterPlan.new(), PackedStringArray())
	assert_eq(rep.food_spoiled, 100 - r.food_base_capacity)
	assert_eq(b.food, r.food_base_capacity - 3)
	var b2 := _band(2, 100)
	b2.silver = 100
	Hall.ensure(b2, r).build(r, CampaignTypes.Building.STOREHOUSE, b2, PackedStringArray())
	var rep2 := Winter.run_turn(SimRng.new(1), r, b2, cal, WinterPlan.new(), PackedStringArray())
	assert_eq(rep2.food_spoiled, 0)
	assert_eq(b2.food, 97, "stores above the base capacity survive")


func test_seats_and_thaw_report() -> void:
	var r := _quiet_rules()
	r.hall_base_seats = 3
	var b := _band(5, 100)
	var reps := _winter(1, r, b, func(_b: Band, _c: Calendar) -> WinterPlan: return WinterPlan.new())
	var h: Hall = b.hall
	assert_true(reps[0].seated[h.seating[2]])
	assert_true(not reps[0].seated[h.seating[3]])
	assert_eq(reps[0].men_without_seat.size(), 0, "only reported at the thaw")
	assert_eq(reps[3].men_without_seat.size(), 2)
	assert_true(reps[3].men_without_seat.has(h.seating[4]))


func test_tasks() -> void:
	var r := _quiet_rules()
	var b := _band(6, 100)
	b.ship_damage = 3
	var cal := Calendar.new(870)
	cal.start_winter()
	var m := b.men
	m[0].healing_turns = 2
	m[1].healing_turns = 2
	m[2].stats = [5, 5, 2, 5, 5]
	var p := WinterPlan.new()
	p.tasks[m[0].id] = CampaignTypes.Task.HEAL
	p.tasks[m[2].id] = CampaignTypes.Task.DRILL
	p.drill_stat[m[2].id] = CombatTypes.Stat.GRIT
	p.tasks[m[3].id] = CampaignTypes.Task.REPAIR
	p.tasks[m[4].id] = CampaignTypes.Task.TRAVEL
	p.tasks[m[5].id] = CampaignTypes.Task.FISH
	var rep := Winter.run_turn(SimRng.new(3), r, b, cal, p, PackedStringArray())
	assert_eq(m[0].healing_turns, 0, "HEAL mends two")
	assert_eq(m[1].healing_turns, 1, "rest mends one")
	assert_true(rep.healed.size() == 1 and rep.healed[0] == m[0].id, "healed reported")
	assert_eq(rep.drilled[m[2].id], CombatTypes.Stat.GRIT)
	assert_eq(rep.repaired, 1)
	assert_true(rep.shields_mended)
	assert_eq(b.ship_damage, 2)
	assert_eq(b.rumors.size(), 1)
	assert_eq(rep.food_gained, 0, "no fishing without a boathouse")
	b.silver = 200
	var h: Hall = b.hall
	h.build(r, CampaignTypes.Building.SMITHY, b, PackedStringArray())
	h.build(r, CampaignTypes.Building.BOATHOUSE, b, PackedStringArray())
	h.build(r, CampaignTypes.Building.BYRE, b, PackedStringArray())
	cal.advance_turn()
	var rep2 := Winter.run_turn(SimRng.new(3), r, b, cal, p, PackedStringArray())
	assert_eq(rep2.repaired, 2, "smithy doubles repair")
	assert_eq(rep2.food_gained, r.fish_rations + r.byre_rations)


func test_yule_feast_vow_gifts() -> void:
	var r := _quiet_rules()
	var b := _band(4, 50)
	b.silver = 12
	var cal := Calendar.new(870)
	cal.start_winter()
	cal.advance_turn()
	var p := WinterPlan.new()
	p.feast = true
	p.vow = "to burn Thorir's hall"
	p.gifts[b.men[0].id] = 8
	p.gifts[b.men[1].id] = 8
	var rep := Winter.run_turn(SimRng.new(1), r, b, cal, p, PackedStringArray())
	assert_true(rep.feasted)
	assert_eq(b.food, 50 - 5 - 5 * r.feast_rations_per_man)
	assert_eq(rep.vow, p.vow)
	assert_eq(b.vows.size(), 1)
	assert_eq(b.vows[0].year, 870)
	assert_eq(rep.gifts[b.men[0].id], 8)
	assert_eq(rep.gifts[b.men[1].id], 4, "silver ran out")
	assert_eq(b.silver, 0)
	var b2 := _band(4, 6)
	var rep2 := Winter.run_turn(SimRng.new(1), r, b2, cal, p, PackedStringArray())
	assert_true(not rep2.feasted, "no feast from empty stores")


func test_default_plan_heals_and_hunts_when_short() -> void:
	var r := _quiet_rules()
	var b := _band(6, 5)
	b.men[0].healing_turns = 2
	var cal := Calendar.new(870)
	cal.start_winter()
	var p := Winter.default_plan(r, b, cal)
	assert_eq(p.tasks[b.men[0].id], CampaignTypes.Task.HEAL)
	var hunters := 0
	var drillers := 0
	for id in p.tasks:
		if p.tasks[id] == CampaignTypes.Task.HUNT:
			hunters += 1
		if p.tasks[id] == CampaignTypes.Task.DRILL:
			drillers += 1
			assert_true(p.drill_stat.has(id))
	assert_eq(hunters, 2)
	assert_eq(drillers, 3)
	var h: Hall = b.hall
	assert_eq(p.tasks[h.seating[5]], CampaignTypes.Task.HUNT, "the first to go hungry hunt")
	# Plenty of food: no hunting.
	b.food = 100
	var p2 := Winter.default_plan(r, b, cal)
	for id in p2.tasks:
		assert_ne(p2.tasks[id], CampaignTypes.Task.HUNT)
	# Boathouse: fish instead; feud: one guard.
	b.food = 5
	b.silver = 100
	h.build(r, CampaignTypes.Building.BOATHOUSE, b, PackedStringArray())
	b.add_feud("Thorir", "Egil slain")
	var p3 := Winter.default_plan(r, b, cal)
	var fishers := 0
	var guards := 0
	for id in p3.tasks:
		if p3.tasks[id] == CampaignTypes.Task.FISH:
			fishers += 1
		if p3.tasks[id] == CampaignTypes.Task.GUARD:
			guards += 1
	assert_eq(fishers, 2)
	assert_eq(guards, 1)


func test_default_plan_yule() -> void:
	var r := _quiet_rules()
	var b := _band(5, 100)
	b.silver = 100
	for i in b.men.size():
		b.men[i].loyalty = 60 - i * 10
	var cal := Calendar.new(870)
	cal.start_winter()
	cal.advance_turn()
	var p := Winter.default_plan(r, b, cal)
	assert_true(p.feast)
	assert_eq(p.gifts.size(), 3)
	assert_true(p.gifts.has(b.men[4].id) and p.gifts.has(b.men[3].id) and p.gifts.has(b.men[2].id))
	b.food = 15
	b.silver = 0
	var p2 := Winter.default_plan(r, b, cal)
	assert_true(not p2.feast, "no feast when it would starve the thaw")
	assert_eq(p2.gifts.size(), 0)


func test_default_plan_winter_runs_and_replays() -> void:
	var r := CampaignRules.new()
	var logs: Array[String] = []
	for k in 2:
		var b := _band(10, 30)
		b.add_feud("Thorir", "Egil slain")
		var log := PackedStringArray()
		var rng := SimRng.new(77)
		var cal := Calendar.new(870)
		cal.start_winter()
		for t in 4:
			Winter.run_turn(rng, r, b, cal, Winter.default_plan(r, b, cal), log)
			if t < 3:
				cal.advance_turn()
		logs.append("\n".join(log))
	assert_eq(logs[0], logs[1], "same seed, same winter")
