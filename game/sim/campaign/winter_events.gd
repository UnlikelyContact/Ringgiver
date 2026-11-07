class_name WinterEvents
extends RefCounted
## Visitors and troubles in the winter hall. Each fired event is a
## Dictionary {kind, text, ...effects}. Effects on silver, food, ship damage,
## rumors and healing are applied to the band here; fame, loyalty, bonds,
## recruits, marriages and fights are reported for the campaign loop:
##   silver, food, ship_damage: int deltas already applied
##   fame: int, for Leader (skald, envoy)
##   recruit_request: true (outlaw_shelter), the loop builds the man
##   marriage_offer: house name (marriage_offer)
##   sick: Array[int] of man ids given healing_turns (sickness)
##   quarrel: [id, id], holmgang: bool (quarrel), for Bonds
##   battle_required: {kind, attackers, tier, against} (feud_attack, hall_burning)

const FEUD_KINDS := ["feud_attack", "hall_burning"]


## Rolls rules.events_per_turn times against rules.winter_events. Feud
## attacks and hall-burnings are only in the draw while band.feuds has an
## unsettled entry, and then fire with their chance (halved when guarded).
static func roll(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, guarded: bool, log: PackedStringArray) -> Array[Dictionary]:
	var fired: Array[Dictionary] = []
	for i in rules.events_per_turn:
		var kind := pick_kind(rng, rules, band)
		if kind == "":
			continue
		var ev := fire(rng, rules, band, cal, kind, guarded, log)
		if not ev.is_empty():
			fired.append(ev)
	return fired


## Weighted draw over the kinds that can happen to this band now; "" if none.
static func pick_kind(rng: SimRng, rules: CampaignRules, band: Band) -> String:
	var feud := not band.unsettled_feuds().is_empty()
	var men := band.living_men().size()
	var kinds: Array[String] = []
	var weights: Array[int] = []
	var total := 0
	for k in rules.winter_events:
		var kind: String = k
		var w: int = rules.winter_events[k]
		if w <= 0:
			continue
		if FEUD_KINDS.has(kind) and not feud:
			continue
		if kind == "quarrel" and men < 2:
			continue
		if kind == "sickness" and men < 1:
			continue
		kinds.append(kind)
		weights.append(w)
		total += w
	if total <= 0:
		return ""
	var r := rng.randi_range(1, total)
	for i in kinds.size():
		r -= weights[i]
		if r <= 0:
			return kinds[i]
	return kinds[kinds.size() - 1]


## Applies one event of the given kind. Returns {} when it comes to nothing
## (a feud attack whose chance roll fails, or no feud to drive it).
static func fire(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, kind: String, guarded: bool, log: PackedStringArray) -> Dictionary:
	var ev := {"kind": kind, "text": ""}
	var when := cal.describe()
	match kind:
		"skald":
			if band.silver >= rules.skald_fee:
				band.silver -= rules.skald_fee
				ev.silver = -rules.skald_fee
				ev.fame = rules.skald_fame
				ev.text = "A skald came to the hall and was paid %d oz for a praise-poem." % rules.skald_fee
			else:
				ev.text = "A skald came to the hall, found no silver for him, and went on."
		"trader":
			if band.silver >= rules.trader_price:
				band.silver -= rules.trader_price
				band.food += rules.trader_food
				ev.silver = -rules.trader_price
				ev.food = rules.trader_food
				ev.text = "A trader sold %d rations of dried fish for %d oz." % [rules.trader_food, rules.trader_price]
			else:
				ev.text = "A trader came by, but there was no silver to buy with."
		"outlaw_shelter":
			ev.recruit_request = true
			ev.text = "An outlaw came through the snow asking shelter, and offered his sword."
		"marriage_offer":
			var house: String = rules.marriage_houses[rng.randi_range(0, rules.marriage_houses.size() - 1)] \
					if not rules.marriage_houses.is_empty() else "a neighbor"
			ev.marriage_offer = house
			ev.text = "Word came from %s: a daughter of the house might be given in marriage." % house
		"envoy":
			var rumor := _rumor(rng, rules)
			if rumor != "":
				band.rumors.append(rumor)
				ev.rumor = rumor
			ev.fame = rules.envoy_fame
			ev.text = "A jarl's envoy sat at the board and spoke of the spring: %s." % rumor
		"sickness":
			var pool := band.living_men()
			var sick: Array[int] = []
			for n in mini(rules.sickness_men, pool.size()):
				var m: Man = pool[rng.randi_range(0, pool.size() - 1)]
				pool.erase(m)
				m.healing_turns = maxi(m.healing_turns, rules.sickness_turns)
				sick.append(m.id)
			ev.sick = sick
			var names := PackedStringArray()
			for id in sick:
				names.append(band.man_by_id(id).display_name)
			ev.text = "A coughing sickness went through the hall; %s took to the benches." % ", ".join(names)
		"storm":
			band.ship_damage += rules.storm_ship_damage
			ev.ship_damage = rules.storm_ship_damage
			ev.text = "A storm tore at the boat-shed and stove in the ship's strakes."
		"thrall_unrest":
			var lost := mini(rules.thrall_unrest_food, band.food)
			band.food -= lost
			ev.food = -lost
			ev.text = "The thralls grew restless; %d rations went missing from the stores." % lost
		"quarrel":
			var pool := band.living_men()
			var a: Man = pool[rng.randi_range(0, pool.size() - 1)]
			pool.erase(a)
			var b: Man = pool[rng.randi_range(0, pool.size() - 1)]
			ev.quarrel = [a.id, b.id]
			ev.holmgang = rng.randf() < rules.quarrel_holmgang_chance
			if ev.holmgang:
				ev.text = "%s and %s quarreled over the ale, and %s challenged %s to holmgang." % [
					a.display_name, b.display_name, a.display_name, b.display_name]
			else:
				ev.text = "%s and %s quarreled over the ale until others pulled them apart." % [a.display_name, b.display_name]
		"feud_attack", "hall_burning":
			var feuds := band.unsettled_feuds()
			if feuds.is_empty():
				return {}
			var chance := rules.feud_attack_chance if kind == "feud_attack" else rules.hall_burning_chance
			if guarded:
				chance *= 0.5
			if rng.randf() >= chance:
				return {}
			var feud: Dictionary = feuds[rng.randi_range(0, feuds.size() - 1)]
			var against: String = feud.against
			var attackers: int
			var tier: CombatTypes.Tier
			if kind == "feud_attack":
				attackers = maxi(1, rules.feud_attack_men + rng.randi_range(-rules.feud_attack_spread, rules.feud_attack_spread))
				tier = CombatTypes.Tier.BLOODED
				ev.text = "%s's men came over the snow with spears to settle the feud." % against
			else:
				attackers = maxi(1, rules.hall_burning_men + rng.randi_range(-rules.hall_burning_spread, rules.hall_burning_spread))
				tier = CombatTypes.Tier.VETERAN
				ev.text = "In the night %s's men ringed the hall with fire, to burn all within." % against
			ev.against = against
			ev.battle_required = {"kind": kind, "attackers": attackers, "tier": tier, "against": against}
		_:
			ev.text = "Nothing of note happened."
	log.append("%s: %s" % [when, ev.text])
	if kind in ["outlaw_shelter", "marriage_offer", "sickness", "storm", "feud_attack", "hall_burning"] \
			or (kind == "quarrel" and ev.get("holmgang", false)):
		band.log(ev.text)
	return ev


static func _rumor(rng: SimRng, rules: CampaignRules) -> String:
	if rules.rumor_lines.is_empty():
		return ""
	return rules.rumor_lines[rng.randi_range(0, rules.rumor_lines.size() - 1)]
