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
		# Unrest among thralls needs thralls: captives kept, or land worked.
		if kind == "thrall_unrest" and band.captives <= 0 and band.land <= 0:
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
			if band.ship != null:
				band.ship.damage += rules.storm_ship_damage
			else:
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


# --- The hall's talk (the winter the player plays, WinterHall) -------------------
#
# The same visitors and troubles, met as choices instead of told: `draw`
# picks the kinds for a winter, `card` makes one a choice the player reads
# ({kind, text, options: [{id, label, hint, silver, food}], ...}) and
# `resolve` does what was chosen. Silver and food on an option are what it
# costs (negative) or brings, so the hall's tally can show them before
# anything is spent.

## The kinds met this winter: `n` draws, no kind twice. Feud attacks and
## hall-burnings come with their chance (halved for a guarded hall); a
## storm only troubles a band with a ship, a marriage offer an unmarried
## leader.
static func draw(rng: SimRng, rules: CampaignRules, band: Band, n: int, has_ship: bool, guarded: bool) -> Array[String]:
	var out: Array[String] = []
	var tries := 0
	while out.size() < n and tries < n * 6:
		tries += 1
		var kind := pick_kind(rng, rules, band)
		if kind == "" or out.has(kind):
			continue
		if kind == "storm" and not has_ship:
			continue
		if kind == "marriage_offer" and band.wife != "":
			continue
		if FEUD_KINDS.has(kind):
			var chance := rules.feud_attack_chance if kind == "feud_attack" else rules.hall_burning_chance
			if guarded:
				chance *= 0.5
			if rng.randf() >= chance:
				continue
		out.append(kind)
	return out


## One of the hall's troubles as a choice. Who is sick, who quarrels and who
## comes over the snow are drawn here, so the card says it before it is
## answered.
static func card(rng: SimRng, rules: CampaignRules, band: Band, kind: String) -> Dictionary:
	var c := {"kind": kind, "text": "", "options": []}
	var opts: Array[Dictionary] = []
	match kind:
		"skald":
			c.text = "A skald comes in out of the snow and asks a hearing. For %d oz he will make a praise-poem of your summer." % rules.skald_fee
			opts.append({"id": "pay", "label": "Hear him and pay him", "silver": -rules.skald_fee, "hint": "Fame %+d." % rules.skald_fame})
			opts.append({"id": "send", "label": "Give him a meal and send him on"})
		"trader":
			c.text = "A trader with a sledge of dried fish asks if the hall will buy: %d rations for %d oz." % [rules.trader_food, rules.trader_price]
			opts.append({"id": "buy", "label": "Buy the fish", "silver": -rules.trader_price, "food": rules.trader_food})
			opts.append({"id": "send", "label": "Send him on"})
		"outlaw_shelter":
			c.text = "An outlaw comes through the snow asking shelter, and offers his sword for it."
			opts.append({"id": "take", "label": "Take him in", "hint": "A man for the band; it is spoken of. Honor %+d." % -rules.honor_outlaw_taken})
			opts.append({"id": "send", "label": "Turn him from the door"})
		"marriage_offer":
			var house: String = rules.marriage_houses[rng.randi_range(0, rules.marriage_houses.size() - 1)] \
					if not rules.marriage_houses.is_empty() else "a neighbor"
			c.house = house
			c.text = "Word comes from %s: a daughter of the house might be given in marriage." % house
			opts.append({"id": "accept", "label": "Take her to wife", "hint": "A wife runs the household and stretches the stores; sons may come."})
			opts.append({"id": "decline", "label": "Decline with thanks"})
		"envoy":
			c.rumor = _rumor(rng, rules)
			c.text = "A jarl's envoy sits at the board and speaks of the spring: %s." % c.rumor
			opts.append({"id": "hear", "label": "Hear him out", "hint": "Fame %+d." % rules.envoy_fame})
		"sickness":
			var pool := band.living_men()
			var sick: Array[int] = []
			for n in mini(rules.sickness_men, pool.size()):
				var m: Man = pool[rng.randi_range(0, pool.size() - 1)]
				pool.erase(m)
				sick.append(m.id)
			c.sick = sick
			c.text = "A coughing sickness goes through the hall; %s take to the benches." % _names_of(band, sick)
			opts.append({"id": "tend", "label": "Tend them in the hall", "hint": "%d turns abed." % rules.sickness_turns})
			opts.append({"id": "wise", "label": "Send for a wise-woman", "silver": -rules.wise_woman_fee,
					"hint": "They are up %d turns sooner." % rules.wise_woman_turns})
		"storm":
			c.text = "A storm tears at the boat-shed and stoves in the ship's strakes."
			opts.append({"id": "mend", "label": "Buy timber and mend her", "silver": -rules.storm_mend_ounces})
			opts.append({"id": "leave", "label": "Leave her till spring", "hint": "She is hurt %d." % rules.storm_ship_damage})
		"thrall_unrest":
			c.text = "Rations go missing from the stores, %d of them, and the thralls look at the ground." % rules.thrall_unrest_food
			opts.append({"id": "press", "label": "Have it out of them", "food": -rules.thrall_unrest_food / 2, "hint": "Half is found. Men think you hard: honor -1."})
			opts.append({"id": "let", "label": "Let it lie", "food": -rules.thrall_unrest_food})
		"quarrel":
			var pool2 := band.living_men()
			if pool2.size() < 2:
				return {}
			var a: Man = pool2[rng.randi_range(0, pool2.size() - 1)]
			pool2.erase(a)
			var b: Man = pool2[rng.randi_range(0, pool2.size() - 1)]
			c.quarrel = [a.id, b.id]
			c.holmgang = rng.randf() < rules.quarrel_holmgang_chance
			if c.holmgang:
				c.text = "%s and %s quarrel over the ale, and %s challenges %s to the island. It is for you to judge between them." % [
						a.display_name, b.display_name, a.display_name, b.display_name]
			else:
				c.text = "%s and %s quarrel over the ale until others pull them apart. It is for you to judge between them." % [a.display_name, b.display_name]
			opts.append({"id": "for_a", "label": "Find for %s" % a.display_name, "hint": "He is the warmer for it, %s the colder." % b.display_name})
			opts.append({"id": "for_b", "label": "Find for %s" % b.display_name, "hint": "He is the warmer for it, %s the colder." % a.display_name})
			opts.append({"id": "settle", "label": "Make them drink together", "silver": -2 * rules.settle_quarrel_ounces,
					"hint": "A gift to each from you, and the matter is let lie."})
			if c.holmgang:
				opts.append({"id": "island", "label": "Let them go to the island", "hint": "One comes back hurt; they are rivals after."})
		"feud_attack", "hall_burning":
			var feuds := band.unsettled_feuds()
			if feuds.is_empty():
				return {}
			var feud: Dictionary = feuds[rng.randi_range(0, feuds.size() - 1)]
			var against: String = feud.against
			var attackers: int
			var tier: CombatTypes.Tier
			if kind == "feud_attack":
				attackers = maxi(1, rules.feud_attack_men + rng.randi_range(-rules.feud_attack_spread, rules.feud_attack_spread))
				tier = CombatTypes.Tier.BLOODED
				c.text = "%s's men come over the snow with spears to settle the feud, %d of them." % [against, attackers]
			else:
				attackers = maxi(1, rules.hall_burning_men + rng.randi_range(-rules.hall_burning_spread, rules.hall_burning_spread))
				tier = CombatTypes.Tier.VETERAN
				c.text = "In the night %s's men ring the hall with fire, %d of them, to burn all within." % [against, attackers]
			c.against = against
			c.battle_required = {"kind": kind, "attackers": attackers, "tier": tier, "against": against}
			opts.append({"id": "meet", "label": "Out, and meet them", "hint": "The fight is told by the saga."})
		_:
			return {}
	c.options = opts
	return c


## Does what was chosen on a card. Silver, food, healing, the ship, bonds,
## loyalty and honor are applied here; the rest is reported for the loop
## as in `fire`: fame, recruit_request, marriage_offer (a house name),
## battle_required. `ship` is the band's Ship on the map, or null to use
## the old `band.ship_damage`.
static func resolve(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, c: Dictionary, choice: String, ship: Variant,
		log: PackedStringArray) -> Dictionary:
	var ev := {"kind": c.kind, "text": c.text, "choice": choice}
	var when := cal.describe()
	var said := ""
	match str(c.kind):
		"skald":
			if choice == "pay" and band.silver >= rules.skald_fee:
				band.silver -= rules.skald_fee
				ev.fame = rules.skald_fame
				said = "A skald was paid %d oz for a praise-poem, and it goes round the halls." % rules.skald_fee
			else:
				said = "A skald came to the hall, ate, and went on."
		"trader":
			if choice == "buy" and band.silver >= rules.trader_price:
				band.silver -= rules.trader_price
				band.food += rules.trader_food
				said = "A trader sold %d rations of dried fish for %d oz." % [rules.trader_food, rules.trader_price]
			else:
				said = "A trader came by with dried fish and was sent on."
		"outlaw_shelter":
			if choice == "take":
				ev.recruit_request = true
				ev.honor = -rules.honor_outlaw_taken
				said = "An outlaw came through the snow asking shelter, and was taken in."
			else:
				said = "An outlaw came asking shelter and was turned from the door."
		"marriage_offer":
			if choice == "accept":
				ev.marriage_offer = c.house
				said = "Word came from %s of a daughter to marry, and the match was made." % c.house
			else:
				said = "Word came from %s of a daughter to marry; the match was declined with thanks." % c.house
		"envoy":
			if str(c.get("rumor", "")) != "":
				band.rumors.append(str(c.rumor))
			ev.fame = rules.envoy_fame
			said = "A jarl's envoy sat at the board and spoke of the spring: %s." % c.get("rumor", "")
		"sickness":
			var turns := rules.sickness_turns
			if choice == "wise" and band.silver >= rules.wise_woman_fee:
				band.silver -= rules.wise_woman_fee
				turns = maxi(0, turns - rules.wise_woman_turns)
			var sick: Array[int] = []
			for id in c.get("sick", []):
				var m := band.man_by_id(int(id))
				if m != null and m.alive:
					m.healing_turns = maxi(m.healing_turns, turns)
					sick.append(m.id)
			ev.sick = sick
			said = "A coughing sickness went through the hall; %s took to the benches%s." % [_names_of(band, sick),
					", and a wise-woman was sent for" if choice == "wise" else ""]
		"storm":
			if choice == "mend" and band.silver >= rules.storm_mend_ounces:
				band.silver -= rules.storm_mend_ounces
				said = "A storm stove in the ship's strakes; timber was bought and she was mended."
			else:
				if ship != null:
					(ship as Ship).damage += rules.storm_ship_damage
				else:
					band.ship_damage += rules.storm_ship_damage
				ev.ship_damage = rules.storm_ship_damage
				said = "A storm stove in the ship's strakes, and she lies hurt till spring."
		"thrall_unrest":
			var lost := rules.thrall_unrest_food / 2 if choice == "press" else rules.thrall_unrest_food
			lost = mini(lost, band.food)
			band.food -= lost
			ev.food = -lost
			if choice == "press":
				ev.honor = -1
			said = "Rations went missing from the stores; %d were not found again." % lost
		"quarrel":
			var ids: Array = c.get("quarrel", [])
			var a := band.man_by_id(int(ids[0])) if ids.size() > 1 else null
			var b := band.man_by_id(int(ids[1])) if ids.size() > 1 else null
			if a == null or b == null or not a.alive or not b.alive:
				return {}
			ev.quarrel = [a.id, b.id]
			match choice:
				"for_a", "for_b":
					var won := a if choice == "for_a" else b
					var lost := b if choice == "for_a" else a
					Loyalty.adjust(won, rules.judge_loyalty)
					Loyalty.adjust(lost, -rules.judge_loyalty)
					band.add_bond(a, b, -rules.bond_quarrel / 2)
					said = "%s and %s quarreled over the ale; %s found for %s, and %s took it ill." % [a.display_name, b.display_name,
							_leader_name(band), won.display_name, lost.display_name]
				"settle":
					var each := mini(rules.settle_quarrel_ounces, band.silver / 2)
					band.silver -= 2 * each
					Loyalty.adjust(a, rules.settle_quarrel_loyalty)
					Loyalty.adjust(b, rules.settle_quarrel_loyalty)
					band.add_bond(a, b, rules.settle_quarrel_bond)
					ev.lawful = true
					said = "%s and %s quarreled over the ale; %s gave each a gift and made them drink together." % [a.display_name, b.display_name, _leader_name(band)]
				"island":
					# The better blade is the likelier to walk off whole.
					var sa := a.stat(CombatTypes.Stat.SKILL)
					var sb := b.stat(CombatTypes.Stat.SKILL)
					var loser := a if rng.randi_range(1, sa + sb) > sa else b
					loser.healing_turns = maxi(loser.healing_turns, rules.quarrel_island_turns)
					band.add_bond(a, b, -rules.quarrel_island_bond)
					Bonds.update_kind(rules, band, a, b, log)
					said = "%s and %s went to the island over a quarrel; %s came back with his blood let." % [a.display_name, b.display_name, loser.display_name]
				_:
					said = "%s and %s quarreled over the ale until others pulled them apart." % [a.display_name, b.display_name]
		"feud_attack", "hall_burning":
			ev.battle_required = c.battle_required
			ev.against = c.get("against", "")
			said = str(c.text)
		_:
			said = str(c.get("text", ""))
	ev.text = said
	log.append("%s: %s" % [when, said])
	if str(c.kind) in ["outlaw_shelter", "marriage_offer", "feud_attack", "hall_burning"] and choice != "send" and choice != "decline":
		band.log(said)
	elif str(c.kind) == "quarrel" and choice == "island":
		band.log(said)
	return ev


static func _names_of(band: Band, ids: Array) -> String:
	var names := PackedStringArray()
	for id in ids:
		var m := band.man_by_id(int(id))
		if m != null:
			names.append(m.display_name)
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


static func _leader_name(band: Band) -> String:
	return band.leader.display_name if band.leader != null else "the leader"
