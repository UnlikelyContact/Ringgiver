class_name Aftermath
extends RefCounted
## What a fight leaves behind (concept.md, "After battle"): the bridge's
## growth, deaths, maims, wounds and flight; the silver a greedy man
## stripped from a fallen leader; and, after a fight won on land, a man who
## saw it and asks to join. The campaign and the prototype's roster both
## call it, so three fights in a row are one saga either way.


## Applies the fight to the band's `warriors` (side 0). `rng` is the
## battle's own stream forked, so the recruit replays with the battle.
## Returns {dead, maimed, wounded, grievous, fled, broke, deeds, tiers,
## loot, joined, lines}: the bridge's lists, the silver taken, the names
## of men who joined, and `lines` ready to read out.
static func apply(rules: CampaignRules, band: Band, warriors: Array[Warrior], result: BattleResult,
		rng: SimRng, on_land: bool, log: PackedStringArray) -> Dictionary:
	var told := BattleBridge.after_battle(rules, band, warriors, result, log)
	var won := result.won(0)
	var outcome := result.outcome(0)
	# Loot: what the greedy stripped from the fallen, if the field was kept.
	var loot := 0
	if won:
		for w in warriors:
			if w.looted:
				loot += rules.loot_per_man
	if loot > 0:
		band.silver += loot
		log.append("the men strip the fallen: %d oz" % loot)
	told.loot = loot
	# A man who saw it asks to join.
	told.joined = []
	if won and on_land:
		var chance := rules.recruit_after_rout_chance if outcome == BattleResult.Outcome.ROUTED_THEM else rules.recruit_after_win_chance
		if rng.fork("join").randf() < chance:
			var m := Recruits.random(rng.fork("recruit"), rules, band.next_id())
			band.add_man(m)
			band.log("%s saw the fight and asked to join" % m.display_name)
			log.append("%s asks to join the band" % m.display_name)
			told.joined.append(m.display_name)
	told.lines = lines(told)
	return told


## The aftermath in plain words, one line a kind, for the screen and the
## chronicle: "Grim is dead. Ketil lived, but with a lost eye. ..."
static func lines(told: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if not told.dead.is_empty():
		out.append("%s %s dead." % [_names(told.dead), "is" if told.dead.size() == 1 else "are"])
	for line in told.maimed:
		out.append(line + ".")
	if not told.grievous.is_empty():
		out.append("%s %s carried to the ship, too hurt to fight for a while." % [_names(told.grievous), "is" if told.grievous.size() == 1 else "are"])
	if not told.wounded.is_empty():
		out.append("%s %s wounded and will fight hurt." % [_names(told.wounded), "is" if told.wounded.size() == 1 else "are"])
	if not told.fled.is_empty():
		out.append("%s fled the field; it is remembered." % _names(told.fled))
	if not told.broke.is_empty():
		out.append("%s broke and ran, and came back shamed." % _names(told.broke))
	for line in told.deeds:
		out.append(line + ".")
	for line in told.tiers:
		out.append(line + ".")
	if told.get("loot", 0) > 0:
		out.append("The men strip the fallen: %d oz of silver." % told.loot)
	if not told.get("joined", []).is_empty():
		out.append("%s saw the fight and asks to join." % _names(told.joined))
	return out


static func _names(names: Array) -> String:
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]
