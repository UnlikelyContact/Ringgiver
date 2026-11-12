class_name Winter
extends RefCounted
## One winter turn in the hall: tasks, events, eating, seating, and at Yule
## the feast, vow and gifts. Loyalty and growth are not applied here; the
## WinterReport carries them to the campaign loop.
##
## Order within a turn: (EARLY) spoilage; tasks (food gathered, healing,
## repair, drill, travel); events; eating; (YULE) feast, vow, gifts;
## seating; (THAW) men_without_seat for the whole winter.


static func run_turn(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, plan: WinterPlan, log: PackedStringArray) -> WinterReport:
	var hall := Hall.ensure(band, rules)
	var rep := WinterReport.new()
	rep.turn = cal.winter_turn
	var when := cal.describe()
	var men := band.living_men()

	# Spoilage at the start of winter.
	if cal.winter_turn == CampaignTypes.WinterTurn.EARLY:
		hall.winter_unseated.clear()
		var cap := hall.food_capacity(rules)
		if band.food > cap:
			rep.food_spoiled = band.food - cap
			band.food = cap
			log.append("%s: %d rations spoiled; the stores hold only %d." % [when, rep.food_spoiled, cap])

	# Tasks.
	var guarded := false
	var food_before := band.food
	for m in men:
		var task := plan.task_for(m.id)
		match task:
			CampaignTypes.Task.DRILL:
				var s: CombatTypes.Stat = plan.drill_stat.get(m.id, lowest_stat(m))
				rep.drilled[m.id] = s
				if plan.drill_shape != "":
					m.learn(plan.drill_shape, rules.drill_points_full, cal.year)
					rep.drilled_shape = plan.drill_shape
			CampaignTypes.Task.REPAIR:
				rep.shields_mended = true
				var amount := 2 if hall.has(CampaignTypes.Building.SMITHY) else 1
				# The ship on the map carries her own hurt; the old field is
				# the hurt of a band with no Ship (the plain campaign).
				if band.ship != null:
					var done_ship := mini(amount, band.ship.damage)
					band.ship.damage -= done_ship
					rep.repaired += done_ship
				else:
					var done := mini(amount, band.ship_damage)
					band.ship_damage -= done
					rep.repaired += done
			CampaignTypes.Task.HUNT:
				var got := maxi(0, rules.hunt_rations + rng.randi_range(-rules.hunt_spread, rules.hunt_spread))
				if plan.cold:
					got += rules.camp_hunt_bonus
				band.food += got
				log.append("%s: %s hunted and brought in %d rations." % [when, m.display_name, got])
			CampaignTypes.Task.FISH:
				if hall.has(CampaignTypes.Building.BOATHOUSE):
					band.food += rules.fish_rations
					log.append("%s: %s fished and brought in %d rations." % [when, m.display_name, rules.fish_rations])
				else:
					log.append("%s: %s had no boat to fish from." % [when, m.display_name])
			CampaignTypes.Task.GUARD:
				guarded = true
			CampaignTypes.Task.TRAVEL:
				if not rules.rumor_lines.is_empty():
					var rumor: String = rules.rumor_lines[rng.randi_range(0, rules.rumor_lines.size() - 1)]
					band.rumors.append(rumor)
					log.append("%s: %s came back from %s travels saying %s." % [when, m.display_name, m.his(), rumor])
		# Healing: everyone mends a turn; a man set to HEAL mends two.
		if m.healing_turns > 0:
			var step := 2 if task == CampaignTypes.Task.HEAL else 1
			m.healing_turns = maxi(0, m.healing_turns - step)
			if m.healing_turns == 0:
				rep.healed.append(m.id)
				log.append("%s: %s is on %s feet again." % [when, m.display_name, m.his()])
	if hall.has(CampaignTypes.Building.BYRE):
		band.food += rules.byre_rations
	if rep.repaired > 0:
		log.append("%s: the ship was mended (%d damage restored, %d left)." % [when, rep.repaired,
				band.ship.damage if band.ship != null else band.ship_damage])
	rep.food_gained = band.food - food_before

	# Events (unless the hall's talk has had them already).
	if plan.events:
		rep.events = WinterEvents.roll(rng, rules, band, cal, guarded, log)
	for ev in rep.events:
		if ev.has("battle_required") and rep.battle_required.is_empty():
			rep.battle_required = ev.battle_required

	# Eating: the leader first, then the men in seating order. The household
	# saves household_skill rations per turn.
	var eaters: Array[Man] = []
	if band.leader != null and band.leader.alive:
		eaters.append(band.leader)
	for id in hall.seating:
		var m := band.man_by_id(id)
		if m != null and m.alive:
			eaters.append(m)
	var board := maxi(0, band.household_skill) + maxi(0, plan.host_rations)
	var budget := band.food + board
	var unfed := PackedStringArray()
	for m in eaters:
		var ok := budget > 0
		if ok:
			budget -= 1
		rep.fed[m.id] = ok
		if not ok:
			unfed.append(m.display_name)
	var fed_count := eaters.size() - unfed.size()
	rep.food_eaten = mini(band.food, maxi(0, fed_count - board))
	band.food -= rep.food_eaten
	if not unfed.is_empty():
		log.append("%s: the stores ran short; %s went hungry." % [when, ", ".join(unfed)])

	# Yule: feast, vow, gifts.
	if cal.winter_turn == CampaignTypes.WinterTurn.YULE:
		if plan.feast:
			var cost := rules.feast_rations_per_man * eaters.size()
			if band.food >= cost:
				band.food -= cost
				rep.feasted = true
				log.append("%s: a Yule feast was held; %d rations went to the boards." % [when, cost])
				band.log("held a Yule feast in the hall")
			else:
				log.append("%s: too little in the stores for a feast." % when)
		if plan.vow != "":
			band.vows.append({"year": cal.year, "text": plan.vow, "kept": null})
			rep.vow = plan.vow
			log.append("%s: over the cup, a vow: %s." % [when, plan.vow])
			band.log("vowed at Yule: %s" % plan.vow)
		for id in plan.gifts:
			var m := band.man_by_id(id)
			var want: int = plan.gifts[id]
			if m == null or not m.alive or want <= 0:
				continue
			var given := mini(want, band.silver)
			if given <= 0:
				continue
			band.silver -= given
			rep.gifts[id] = given
			log.append("%s: %s was given %d oz of silver." % [when, m.display_name, given])

	# Seating (in a camp there are no benches, and no one is shamed by it:
	# the cold is what the camp costs).
	rep.cold = plan.cold
	for m in men:
		var ok := plan.cold or hall.is_seated(m.id)
		rep.seated[m.id] = ok
		if not ok and not hall.winter_unseated.has(m.id):
			hall.winter_unseated.append(m.id)

	if cal.winter_turn == CampaignTypes.WinterTurn.THAW:
		rep.men_without_seat = hall.winter_unseated.duplicate()
	return rep


## A sensible AI plan: wounded men HEAL; if food will run short the two men
## first in line to go hungry (lowest seated, not wounded) HUNT, or FISH with
## a boathouse; one man GUARDs during an unsettled feud; the rest DRILL their
## lowest stat. Feast at Yule when the stores cover the rest of winter and
## the feast; gifts to the three lowest-loyalty men while silver allows.
static func default_plan(rules: CampaignRules, band: Band, cal: Calendar) -> WinterPlan:
	var hall := Hall.ensure(band, rules)
	var plan := WinterPlan.new()
	var men: Array[Man] = []
	for id in hall.seating:
		var m := band.man_by_id(id)
		if m != null and m.alive:
			men.append(m)
	var free: Array[Man] = []
	for m in men:
		if m.healing_turns > 0:
			plan.tasks[m.id] = CampaignTypes.Task.HEAL
		else:
			free.append(m)

	var need := food_needed(rules, band, cal)
	var gather_task := CampaignTypes.Task.FISH if hall.has(CampaignTypes.Building.BOATHOUSE) else CampaignTypes.Task.HUNT
	if band.food < need:
		for n in mini(2, free.size()):
			var m: Man = free.pop_back()
			plan.tasks[m.id] = gather_task
	if not band.unsettled_feuds().is_empty() and not free.is_empty():
		var g: Man = free.pop_front()
		plan.tasks[g.id] = CampaignTypes.Task.GUARD
	for m in free:
		plan.tasks[m.id] = CampaignTypes.Task.DRILL
		plan.drill_stat[m.id] = lowest_stat(m)
	plan.drill_shape = band.drilling

	if cal.winter_turn == CampaignTypes.WinterTurn.YULE:
		var eaters := men.size() + (1 if band.leader != null and band.leader.alive else 0)
		plan.feast = band.food >= need + rules.feast_rations_per_man * eaters
		var by_loyalty := men.duplicate()
		by_loyalty.sort_custom(func(a: Man, b: Man) -> bool:
			return a.loyalty < b.loyalty or (a.loyalty == b.loyalty and a.id < b.id))
		var silver := band.silver
		for i in mini(3, by_loyalty.size()):
			if silver < rules.default_gift_ounces:
				break
			plan.gifts[by_loyalty[i].id] = rules.default_gift_ounces
			silver -= rules.default_gift_ounces
	return plan


## Rations the band needs from now through the thaw, after the household's
## stretching and the byre.
static func food_needed(rules: CampaignRules, band: Band, cal: Calendar) -> int:
	var eaters := band.living_men().size() + (1 if band.leader != null and band.leader.alive else 0)
	var turns_left := CampaignTypes.WinterTurn.THAW - cal.winter_turn + 1
	var per_turn := maxi(0, eaters - maxi(0, band.household_skill))
	var hall: Hall = band.hall as Hall
	if hall != null and hall.has(CampaignTypes.Building.BYRE):
		per_turn = maxi(0, per_turn - rules.byre_rations)
	return per_turn * turns_left


static func lowest_stat(m: Man) -> CombatTypes.Stat:
	var best := 0
	for i in m.stats.size():
		if m.stats[i] < m.stats[best]:
			best = i
	return best as CombatTypes.Stat
