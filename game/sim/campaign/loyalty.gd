class_name Loyalty
extends RefCounted
## Module F: a man's oath to the leader. Gifts, plunder shares, ambitions,
## winter hardship, seating honor, and who walks away at the thaw.
## See campaign-architecture.md > Module F. Loyalty is always clamped 0-100.


## Changes a man's loyalty by delta, clamped to 0-100. Returns the new value.
static func adjust(m: Man, delta: int) -> int:
	m.loyalty = clampi(m.loyalty + delta, 0, 100)
	return m.loyalty


## A gift of silver. Does not move silver: the caller (the winter hall or the
## campaign loop) has already taken it from the band's chest.
static func gift(rules: CampaignRules, band: Band, m: Man, silver: int, log: PackedStringArray) -> void:
	if silver <= 0:
		return
	var gain := mini(silver * rules.loyalty_per_ounce, rules.gift_cap)
	var ring := silver >= rules.ring_gift_ounces
	if ring:
		gain += rules.loyalty_ring_bonus
	if m.ambition == CampaignTypes.Ambition.SILVER:
		gain += rules.ambition_gift_bonus
	adjust(m, gain)
	log.append("%s is given %d oz of silver: loyalty +%d (%d)" % [m.display_name, silver, gain, m.loyalty])
	if ring:
		band.log("%s gave %s an arm-ring of %d ounces." % [_giver(band), m.display_name, silver])


## A gift of gear: sets the man's gear by item name ("sword", "axe", "spear",
## "long axe", "bow", "mail", "leather", "helmet", "shield") and raises
## loyalty. Unknown items are logged and ignored.
static func gift_gear(rules: CampaignRules, band: Band, m: Man, item: String, log: PackedStringArray) -> void:
	match item:
		"sword":
			m.weapon = CombatTypes.Weapon.SWORD
		"axe":
			m.weapon = CombatTypes.Weapon.BEARDED_AXE
		"spear":
			m.weapon = CombatTypes.Weapon.SPEAR
		"long axe":
			m.weapon = CombatTypes.Weapon.LONG_AXE
		"bow":
			m.weapon = CombatTypes.Weapon.BOW
		"mail":
			m.armor = CombatTypes.Armor.MAIL
		"leather":
			if m.armor == CombatTypes.Armor.NONE:
				m.armor = CombatTypes.Armor.LEATHER
		"helmet":
			m.helmet = true
		"shield":
			m.has_shield = true
		_:
			log.append("%s cannot be given '%s': no such gear" % [m.display_name, item])
			return
	adjust(m, rules.loyalty_gear_gift)
	log.append("%s is given a %s: loyalty +%d (%d)" % [m.display_name, item, rules.loyalty_gear_gift, m.loyalty])
	if item == "sword" or item == "mail":
		band.log("%s gave %s a %s." % [_giver(band), m.display_name, "mail shirt" if item == "mail" else item])


## Splits plunder: the leader takes leader_share (0-1) into the band's chest,
## the rest goes evenly to the living men (odd ounces stay with the leader).
## A leader's share above fair_leader_share angers every man; a fair one
## pleases them. Greedy men feel both twice as hard.
static func share_plunder(rules: CampaignRules, band: Band, total_silver: int, leader_share: float, log: PackedStringArray) -> void:
	if total_silver <= 0:
		return
	var share := clampf(leader_share, 0.0, 1.0)
	var men := band.living_men()
	if men.is_empty():
		band.silver += total_silver
		log.append("%d oz of plunder go to the leader's chest; there is no one to share with" % total_silver)
		return
	var leader_part := roundi(total_silver * share)
	var each := (total_silver - leader_part) / men.size()
	var kept := total_silver - each * men.size()
	band.silver += kept
	var unfair := share > rules.fair_leader_share
	var delta := -rules.loyalty_unfair_share if unfair else rules.loyalty_fair_share
	log.append("plunder of %d oz shared: the leader keeps %d, each man gets %d (%s)" % [
		total_silver, kept, each, "grudged" if unfair else "fair"])
	for m in men:
		var d := delta * 2 if m.has_personality(CombatTypes.Personality.GREEDY) else delta
		adjust(m, d)
		log.append("  %s: loyalty %+d (%d)" % [m.display_name, d, m.loyalty])
	if unfair:
		band.log("The men grumbled at the sharing of the plunder.")


## Moves a man toward his ambition. When it is fulfilled his loyalty jumps,
## once. VENGEANCE is advanced only by the campaign loop through feuds.
static func ambition_progress(rules: CampaignRules, band: Band, m: Man, amount: int, log: PackedStringArray) -> void:
	if m.ambition_met or amount <= 0:
		return
	m.ambition_progress += amount
	if m.ambition_progress < rules.ambition_fulfilled:
		return
	m.ambition_progress = rules.ambition_fulfilled
	m.ambition_met = true
	adjust(m, rules.loyalty_ambition_met)
	var want: String = CampaignTypes.AMBITION_NAMES[m.ambition]
	log.append("%s has what he wanted (%s): loyalty +%d (%d)" % [
		m.display_name, want, rules.loyalty_ambition_met, m.loyalty])
	band.log("%s won %s in %s's service." % [m.display_name, want, _giver(band)])


## One winter turn. Hunger and a missing bench each cost loyalty; a fed,
## seated man rests and warms to his lord. The leader's luck pulls every man
## up or down.
static func winter_drift(rules: CampaignRules, band: Band, m: Man, fed: bool, seated: bool, log: PackedStringArray) -> void:
	var delta := 0
	var why := PackedStringArray()
	if not fed:
		delta -= rules.loyalty_unfed_per_turn
		why.append("hungry")
	if not seated:
		delta -= rules.loyalty_unseated
		why.append("no bench")
	if fed and seated:
		delta += rules.loyalty_winter_rest
	if band.luck > rules.luck_loyalty_above:
		delta += rules.loyalty_luck_bonus
		why.append("lucky lord")
	elif band.luck < rules.luck_loyalty_below:
		delta -= rules.loyalty_luck_bonus
		why.append("unlucky lord")
	adjust(m, delta)
	if not why.is_empty():
		log.append("%s: loyalty %+d (%s) -> %d" % [m.display_name, delta, ", ".join(why), m.loyalty])


## At the thaw: every living man whose loyalty is below loyalty_leave_below
## leaves (a man who wants to go home goes home). A greedy man or an outlaw
## below loyalty_turn_below turns with turn_chance and steals on the way out.
## Oath brothers who stay lose bond_brother_left loyalty per brother who
## left. Returns the leavers; the caller removes them from the band.
static func departures(rng: SimRng, rules: CampaignRules, band: Band, log: PackedStringArray) -> Array[Man]:
	var leavers: Array[Man] = []
	for m in band.living_men():
		if m.loyalty < rules.loyalty_leave_below:
			leavers.append(m)
	for m in leavers:
		var turncoat := m.loyalty < rules.loyalty_turn_below and (
				m.has_personality(CombatTypes.Personality.GREEDY) or m.origin == CampaignTypes.Origin.OUTLAW)
		if turncoat and rng.randf() < rules.turn_chance:
			var stolen := mini(rules.turn_theft_ounces, band.silver)
			band.silver -= stolen
			log.append("%s turns at the thaw and takes %d oz of silver with him" % [m.display_name, stolen])
			band.log("%s broke his oath and stole %d ounces as he went." % [m.display_name, stolen])
		elif m.ambition == CampaignTypes.Ambition.HOME:
			log.append("%s goes home at the thaw (loyalty %d)" % [m.display_name, m.loyalty])
			band.log("%s went home and did not come back." % m.display_name)
		else:
			log.append("%s leaves the band at the thaw (loyalty %d)" % [m.display_name, m.loyalty])
			band.log("%s left the band at the thaw." % m.display_name)
	for m in leavers:
		for brother in Bonds.oath_brothers(band, m):
			if leavers.has(brother) or brother.is_leader:
				continue
			adjust(brother, -rules.bond_brother_left)
			log.append("%s's oath brother %s left: loyalty -%d (%d)" % [
				brother.display_name, m.display_name, rules.bond_brother_left, brother.loyalty])
	return leavers


## Seating order shows honor: moving one man up past another honors him and
## offends the man passed (a boastful man doubly).
static func seating_offense(rules: CampaignRules, band: Band, moved_up: Man, passed: Man, log: PackedStringArray) -> void:
	var loss := rules.loyalty_seating_passed
	if passed.has_personality(CombatTypes.Personality.BOASTFUL):
		loss *= 2
	adjust(passed, -loss)
	adjust(moved_up, rules.loyalty_seating_honor)
	log.append("%s is seated above %s: %s loyalty +%d (%d), %s loyalty -%d (%d)" % [
		moved_up.display_name, passed.display_name, moved_up.display_name, rules.loyalty_seating_honor,
		moved_up.loyalty, passed.display_name, loss, passed.loyalty])


static func _giver(band: Band) -> String:
	return band.leader.display_name if band.leader != null else "the ring-giver"
