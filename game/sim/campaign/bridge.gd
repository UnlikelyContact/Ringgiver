class_name BattleBridge
extends RefCounted
## Applies what a battle did to the band's men: effort, survival, death,
## maims, flight, growth, tiers and bonds of men who fought together.
##
## Pass only the band's own warriors: a warrior maps to a man when
## `Warrior.id == Man.id` (Band.man_by_id, the leader included).


## Returns what it did, by name, for the chronicle and the screen:
## {dead, maimed, wounded, grievous, fled, broke, deeds, tiers}, each an
## Array of lines.
static func after_battle(rules: CampaignRules, band: Band, warriors: Array[Warrior], result: BattleResult, log: PackedStringArray) -> Dictionary:
	var told := {"dead": [], "maimed": [], "wounded": [], "grievous": [], "fled": [], "broke": [], "deeds": [], "tiers": []}
	var stood: Array[Man] = []  # alive afterwards and did not flee
	# The shape the band fought in: standing in a learned one teaches it.
	var fought: FormationTemplate = null
	for w in warriors:
		if w.is_leader and w.formation != null and w.formation.learned:
			fought = w.formation
	for w in warriors:
		var m := band.man_by_id(w.id)
		if m == null or not m.alive:
			continue
		m.kills += w.kills
		if w.kills >= rules.deed_kills:
			var deed := "put down %d men in one fight" % w.kills
			m.deeds.append(deed)
			told.deeds.append("%s %s" % [m.display_name, deed])
		var keys := w.effort.keys()
		keys.sort()
		for k in keys:
			Growth.add_effort(rules, m, k as CombatTypes.Stat, int(w.effort[k]), log)
		var dead := w.is_down() and w.fate == CombatTypes.Fate.DEAD
		if not w.is_down() or w.fate == CombatTypes.Fate.RECOVERED:
			m.battles_survived += 1
		if dead:
			m.alive = false
			band.log("%s fell in battle" % m.display_name)
			log.append("%s is dead" % m.display_name)
			told.dead.append(m.display_name)
			continue
		if w.is_down() and w.fate == CombatTypes.Fate.MAIMED:
			told.maimed.append(_maim(rules, band, m, result, log))
		# The wound he leaves with is healing to do: a man carried off the
		# field has the most; the rest fight the next one hurt, if at all.
		var turns: int = rules.wound_turns[mini(int(w.wound), rules.wound_turns.size() - 1)]
		if turns > m.healing_turns:
			m.healing_turns = turns
			if m.too_hurt_to_fight(rules):
				told.grievous.append(m.display_name)
			elif turns >= rules.wound_turns[CombatTypes.Wound.WOUNDED]:
				told.wounded.append(m.display_name)
		if w.fled:
			m.loyalty = clampi(m.loyalty - rules.loyalty_fled_penalty, 0, 100)
			log.append("%s fled the field (loyalty %d)" % [m.display_name, m.loyalty])
			told.fled.append(m.display_name)
		else:
			if w.broken:
				# He broke, but did not get away: it is remembered all the same.
				m.broke_count += 1
				m.loyalty = clampi(m.loyalty - rules.loyalty_broke_penalty, 0, 100)
				if m.broke_count == 1:
					m.traits.append("broke and ran once")
				told.broke.append(m.display_name)
			stood.append(m)
		Growth.apply_growth(rules, m, log)
		var t := Growth.tier_for(rules, m)
		if t != m.tier:
			m.tier = t
			log.append("%s is now %s" % [m.display_name, CombatTypes.TIER_NAMES[t]])
			told.tiers.append("%s %s now %s" % [m.display_name, "are" if m.display_name == "You" else "is", CombatTypes.TIER_NAMES[t]])
	for i in stood.size():
		for j in range(i + 1, stood.size()):
			band.set_bond(stood[i], stood[j], band.bond(stood[i], stood[j]) + rules.bond_fought_together)
	if fought != null:
		for m in stood:
			m.learn(fought.name, rules.drill_points_full)
	return told


## A random maim he does not already have, chosen from a stream forked from
## the battle's seed and his id, so the outcome replays with the battle.
## Returns the line for it.
static func _maim(rules: CampaignRules, band: Band, m: Man, result: BattleResult, log: PackedStringArray) -> String:
	var options: Array[CampaignTypes.Maim] = []
	for i in CampaignTypes.Maim.size():
		var mm := i as CampaignTypes.Maim
		if not m.has_maim(mm):
			options.append(mm)
	if options.is_empty():
		log.append("%s is maimed again, but has nothing left to lose" % m.display_name)
		return "%s is maimed again, but has nothing left to lose" % m.display_name
	var rng := SimRng.new(result.seed_value).fork("maim:%d" % m.id)
	var maim := options[rng.randi_range(0, options.size() - 1)]
	m.maims.append(maim)
	var pen: Array = rules.maim_penalties.get(maim, [CombatTypes.Stat.MIGHT, 0])
	var s: int = pen[0]
	var amount: int = pen[1]
	m.stats[s] = maxi(1, m.stats[s] - amount)
	if rules.maim_lowers_cap:
		m.potential[s] = maxi(m.stats[s], m.potential[s] - amount)
	band.log("%s lived, but with %s" % [m.display_name, CampaignTypes.MAIM_NAMES[maim]])
	log.append("%s is maimed: %s (%s -%d)" % [m.display_name, CampaignTypes.MAIM_NAMES[maim], CombatTypes.STAT_NAMES[s], amount])
	return "%s lived, but with %s" % [m.display_name, CampaignTypes.MAIM_NAMES[maim]]
