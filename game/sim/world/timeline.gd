class_name Timeline
extends RefCounted
## The historical spine (WorldRules.spine): Harald's vow and conquests,
## Hafrsfjord, Iceland, Orkney, Rollo, Eric and Haakon. Events fire once on
## the traditional timeline unless their preconditions fail; the player can
## side with them, oppose them, or let them pass. If Harald falls, his later
## events no longer fire and the fallback (a rival jarl's bid) fires once.
## Battles are not fought here: `fire` returns `battle_required` and the
## caller reports the outcome through `resolve`.

const HARALD := "harald"


## Spine events due this year whose preconditions hold and whose place (if
## any) is open, plus the fallback once Harald is gone or one of his due
## events cannot happen.
static func pending(rules: WorldRules, world: World, year: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var harald_blocked := false
	for e in rules.spine:
		var ev: Dictionary = e
		if ev.year != year or world.timeline_state.get(ev.id, false):
			continue
		if ev.has("place"):
			var p := world.place(ev.place)
			if p == null or not p.is_open(year):
				continue
		if _holds(world, ev.precondition):
			out.append(ev.duplicate(true))
		elif (ev.precondition as String).begins_with(HARALD):
			harald_blocked = true
	var fb_id: String = rules.spine_fallback.id
	if not world.timeline_state.get(fb_id, false):
		var harald: Faction = world.factions.get(HARALD, null)
		if harald_blocked or (harald != null and not harald.alive):
			out.append({"year": year, "id": fb_id, "text": rules.spine_fallback.text, "precondition": "always",
					"options": ["serve", "resist", "ignore"], "fallback": true, "effects": {"ambition": "expand"}})
	return out


static func outcome_options(event: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for o in event.get("options", ["ignore"]):
		out.append(o)
	return out


## Fires an event with the player's choice. Returns {id, text, choice,
## battle_required?: {kind, attackers, tier, text, side}, place_opened?,
## conquests: Array, absorbed: Array, exile?: bool}. When a battle is
## required nothing else happens until `resolve` is called with the outcome.
static func fire(_rng: SimRng, rules: WorldRules, world: World, band: Band, event: Dictionary, player_choice: String,
		log: PackedStringArray) -> Dictionary:
	var choice := player_choice
	if not outcome_options(event).has(choice):
		log.append("no such choice as %s; the band stands aside" % choice)
		choice = "ignore"
	world.timeline_state[event.id] = true
	var result := {"id": event.id, "text": event.text, "choice": choice, "conquests": [], "absorbed": []}
	if event.get("fallback", false):
		_ready_rival(world, log)
		event["faction"] = world.timeline_state.get("rival", "")
	log.append(event.text)
	world.log(event.text)
	var effects: Dictionary = event.get("effects", {})
	if effects.has("battle") and rules.spine_battle_options.has(choice):
		var side := HARALD if rules.spine_side_with.has(choice) else "against"
		var b: Dictionary = effects.battle
		result["battle_required"] = {"kind": "spine", "event": event.id, "attackers": b.attackers, "tier": b.tier,
				"side": side, "text": "%s: the band fights %s" % [event.text, "for Harald" if side == HARALD else "against Harald"]}
		return result
	_apply_effects(rules, world, event, log, result)
	_band_side(rules, world, band, event, choice, log)
	if choice == "join_rollo":
		result["exile"] = true
		log.append("%s sails west with Rollo, outlaws from Harald's Norway" % _band_name(band))
	return result


## The caller fought the battle `fire` asked for; `won` is the band's side
## carrying the field. Siding with the event: history goes ahead and the band
## shares the glory. Opposing it: a win stops it (at Hafrsfjord Harald falls),
## a loss lets it go ahead.
static func resolve(rules: WorldRules, world: World, band: Band, event: Dictionary, player_choice: String, won: bool,
		log: PackedStringArray) -> Dictionary:
	var result := {"id": event.id, "choice": player_choice, "won": won, "conquests": [], "absorbed": []}
	var effects: Dictionary = event.get("effects", {})
	_band_side(rules, world, band, event, player_choice, log)
	if won:
		band.fame += rules.spine_battle_fame
		band.rank_progress += rules.spine_battle_rank_progress
	if rules.spine_side_with.has(player_choice) or not won:
		_apply_effects(rules, world, event, log, result)
		result["text"] = event.text
		return result
	if effects.get("on_defeat", "") == "harald_falls":
		_harald_falls(world, effects, log, result)
	else:
		var line := "the band turns Harald's men back; history goes otherwise this year"
		log.append(line)
		world.log(line)
		result["text"] = line
	return result


static func _holds(world: World, precondition: String) -> bool:
	var harald: Faction = world.factions.get(HARALD, null)
	if precondition == "always":
		return true
	if precondition == "harald_alive":
		return harald != null and harald.alive
	if precondition == "harald_line":
		return world.timeline_state.get("harald_line", false)
	if precondition.begins_with("harald_holds:"):
		var p := world.place(precondition.trim_prefix("harald_holds:"))
		return harald != null and harald.alive and p != null and p.faction_id == HARALD
	return false


static func _apply_effects(rules: WorldRules, world: World, event: Dictionary, log: PackedStringArray, result: Dictionary) -> void:
	var effects: Dictionary = event.get("effects", {})
	var f: Faction = world.factions.get(event.get("faction", ""), null)
	var f_ok := f != null and f.alive
	if effects.has("ambition") and f_ok:
		f.ambition = effects.ambition
	if f_ok:
		for place_id in effects.get("conquer", []):
			if FactionAI.conquer(rules, world, place_id, f.id, log):
				result.conquests.append(place_id)
		for fid in effects.get("absorb", []):
			var g: Faction = world.factions.get(fid, null)
			if g != null and g.alive and g != f:
				FactionAI.absorb(world, g, f, log)
				result.absorbed.append(fid)
	var leaders: Dictionary = effects.get("leader", {})
	for fid in leaders:
		var g: Faction = world.factions.get(fid, null)
		if g != null and g.alive:
			g.leader = leaders[fid]
	for r in effects.get("relation", []):
		FactionAI.shift(world, r[0], r[1], r[2])
	if effects.has("open"):
		var p := world.place(effects.open)
		if p != null:
			p.open_year = mini(p.open_year, world.year)
			result["place_opened"] = p.id
	if effects.has("flag"):
		world.timeline_state[effects.flag] = true


static func _band_side(rules: WorldRules, world: World, band: Band, event: Dictionary, choice: String, log: PackedStringArray) -> void:
	var fid: String = event.get("faction", "")
	var f: Faction = world.factions.get(fid, null)
	if f == null:
		return
	if rules.spine_side_with.has(choice):
		FactionAI.shift(world, fid, FactionAI.BAND, rules.spine_serve_relation)
		band.fame += rules.spine_serve_fame
		band.rank_progress += rules.spine_serve_rank_progress
		log.append("%s stands with %s" % [_band_name(band), f.name])
	elif rules.spine_oppose.has(choice):
		FactionAI.shift(world, fid, FactionAI.BAND, rules.spine_oppose_relation)
		log.append("%s stands against %s" % [_band_name(band), f.name])


## Harald is killed with his kingdom: the strongest of the kings who fought
## him takes his holdings, and a rival jarl takes up the bid.
static func _harald_falls(world: World, effects: Dictionary, log: PackedStringArray, result: Dictionary) -> void:
	var harald: Faction = world.factions.get(HARALD, null)
	if harald == null or not harald.alive:
		return
	var heir: Faction = null
	for fid in effects.get("absorb", []):
		var g: Faction = world.factions.get(fid, null)
		if g != null and g.alive and (heir == null or g.strength > heir.strength):
			heir = g
	if heir == null:
		heir = _strongest(world, -1)
	if heir != null:
		FactionAI.absorb(world, harald, heir, log)
	else:
		harald.alive = false
	harald.ambition = "hold"
	world.timeline_state["harald_line"] = false
	world.timeline_state["harald_fell"] = world.year
	var line := "Harald Fairhair falls at Hafrsfjord and his kingdom with him"
	log.append(line)
	world.log(line)
	result["text"] = line
	result["harald_fell"] = true
	_ready_rival(world, log)
	result["rival"] = world.timeline_state.get("rival", "")


## Picks (once) the rival who takes up the bid for a single crown: the
## strongest living jarldom, or failing that the strongest faction.
static func _ready_rival(world: World, log: PackedStringArray) -> void:
	if world.timeline_state.has("rival"):
		return
	var rival := _strongest(world, WorldTypes.FactionKind.JARL)
	if rival == null:
		rival = _strongest(world, -1)
	if rival == null:
		return
	rival.ambition = "expand"
	world.timeline_state["rival"] = rival.id
	log.append("%s of %s means to be king over all Norway" % [rival.leader, rival.name])


static func _strongest(world: World, kind: int) -> Faction:
	var best: Faction = null
	for v in world.factions.values():
		var f: Faction = v
		if not f.alive or f.id == HARALD or (kind >= 0 and f.kind != kind):
			continue
		if best == null or f.strength > best.strength:
			best = f
	return best


static func _band_name(band: Band) -> String:
	return band.leader.display_name + "'s band" if band != null and band.leader != null else "the band"
