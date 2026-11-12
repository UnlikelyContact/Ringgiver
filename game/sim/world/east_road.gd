class_name EastRoad
extends RefCounted
## The wider world's own doings (docs/design/notes/wider-world.md): the
## river road east and the far places at either end of the map. Journey
## asks `haul(j)` for the band's pace on the rollers, calls `tick(j, dt)`
## as the band moves (the portages: days lost, men worn, a chance of being
## fallen on while hauling), `actions(j)` / `act(j, id)` for what is done
## at the far places (a season in the emperor's guard at Miklagard), and
## `after_fight(j, ctx, result)` when a fight on a portage is over. State
## lives in `Journey.life` (keys "haul" and "guard"), so it saves with the
## summer.


# --- The portages ----------------------------------------------------------------------

## Leagues a day the band's ship is hauled over a portage, by her hull; 0
## when it has no ship.
static func haul(j: Journey) -> float:
	var ship := j.c.band.ship
	if ship == null:
		return 0.0
	return float(j.c.world_rules.portage_haul.get(ship.kind, 0.6))


## The portage the band is hauling over now (its index), or -1.
static func hauling(j: Journey) -> int:
	if j.c.band.ship == null or not j.roam.aboard:
		return -1
	return j.roam.grid.portage_at(j.roam.cell())


## The band has moved `dt` days. On the rollers: the haul begins (told
## once), each day of it has its chance of an ambush, and when the band is
## on the water again the men are worn by it.
static func tick(j: Journey, dt: float) -> void:
	var n := hauling(j)
	var h: Dictionary = j.life.get("haul", {})
	if n < 0:
		if not h.is_empty():
			_haul_done(j, h)
		return
	var wr := j.c.world_rules
	if h.is_empty() or int(h.portage) != n:
		var name := str(NorwayData.PORTAGES[n][0])
		var cells: int = (NorwayData.PORTAGES[n][1] as Array).size()
		h = {"portage": n, "days": 0.0}
		j.life["haul"] = h
		j._say("The crew run the %s up onto the rollers: %s, %d leagues overland, %d days or so with a %s." % [
				WorldTypes.SHIP_NAMES[j.c.band.ship.kind], name, cells, ceili(float(cells) / maxf(0.1, haul(j))), WorldTypes.SHIP_NAMES[j.c.band.ship.kind]])
	h.days = float(h.days) + dt
	if j._fork("haul").randf() < wr.portage_ambush_day * dt:
		var who: Array = wr.portage_ambushers[clampi(n, 0, wr.portage_ambushers.size() - 1)]
		var men := maxi(3, int(who[0]) + j._fork("haul_men").randi_range(-wr.portage_ambush_spread, wr.portage_ambush_spread))
		var tier: CombatTypes.Tier = int(who[1])
		j._offer_fight("outlaws", tier, Sandbox._forced(j.c, men), false, wr.sea_fight_stat, false, false,
				{"kind": "portage", "portage": n}, str(who[2]) % men, true)


## Off the rollers: the men are worn. Some strain their backs (a turn's
## healing), and every man thinks the less of the road.
static func _haul_done(j: Journey, h: Dictionary) -> void:
	j.life.erase("haul")
	var wr := j.c.world_rules
	var r := j._fork("haul_done")
	var strained := PackedStringArray()
	for m in j.c.band.living_men():
		if m.is_leader:
			continue
		m.loyalty = clampi(m.loyalty - wr.portage_loyalty, 0, 100)
		if r.randf() < wr.portage_strain:
			m.healing_turns = maxi(m.healing_turns, 1)
			strained.append(m.display_name)
	var name := str(NorwayData.PORTAGES[clampi(int(h.portage), 0, NorwayData.PORTAGES.size() - 1)][0])
	var line := "The ship is in the water again after %s, %d days at the ropes" % [name, roundi(float(h.days))]
	if not strained.is_empty():
		line += "; %s strained %s back at it" % [", ".join(strained), "his" if strained.size() == 1 else "their"]
	j._say(line + ". The men curse the road.")


## A fight on the rollers is over. Beaten (or fled), the band loses half
## of what its ship carries; winning, it goes on with its haul.
static func after_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	if str(ctx.get("kind", "")) != "portage":
		return
	var band := j.c.band
	if result != null and result.winner == 0:
		j._say("The haul goes on, and the men keep their axes nearer to hand.")
		return
	var lost := PackedStringArray()
	var goods: Array = band.cargo.keys()
	goods.sort()
	for g in goods:
		var n := int(band.cargo[g]) / 2
		if n <= 0:
			continue
		band.cargo[g] = int(band.cargo[g]) - n
		if int(band.cargo[g]) <= 0:
			band.cargo.erase(g)
		lost.append("%d %s" % [n, WorldTypes.GOOD_NAMES[g]])
	if not lost.is_empty():
		j._say("They carry off %s from the ship before they are gone into the country." % ", ".join(lost))


# --- The far places ---------------------------------------------------------------------

## The band has come to `p`: at a great market of the north there is talk
## of the road east, and it learns of Birka where the road begins.
static func arrived(j: Journey, p: Place) -> void:
	var band := j.c.band
	if not j.c.world_rules.east_talk_markets.has(p.id) or band.knows("birka"):
		return
	band.known_places["birka"] = true
	j._say("At %s the talk is of the road east: furs and slaves down the rivers to the Greeks, silk and silver back. It begins at Birka, in the Swedes' land." % p.display_name)

## What a place of the wider world is, in a line or two; "" for the old.
static func about(id: String) -> String:
	return str(NorwayData.ABOUT.get(id, ""))


## The deeds of the far places: at Miklagard, the emperor's guard.
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null or p.id != "miklagard":
		return out
	var wr := j.c.world_rules
	var men := j.c.band.fighters().size()
	var enough := men >= wr.guard_min_men
	out.append({"id": "guard", "label": "Take service in the emperor's guard (%d oz)" % guard_pay(j),
			"enabled": enough and int(j.life.get("guard", -1)) != j.c.cal.year,
			"hint": ("The rest of the summer and the winter in the emperor's pay, here at Miklagard: %d oz, fame, and a line in your saga. You go home next spring, if you go." % guard_pay(j)) if enough \
					else "The emperor's men take no band of fewer than %d." % wr.guard_min_men})
	return out


static func guard_pay(j: Journey) -> int:
	var wr := j.c.world_rules
	return wr.guard_pay + wr.guard_pay_man * j.c.band.fighters().size()


## Does one of `actions`; false when the id is not ours.
static func act(j: Journey, id: String) -> bool:
	if id != "guard":
		return false
	var p := j.here()
	var wr := j.c.world_rules
	var band := j.c.band
	if p == null or p.id != "miklagard" or band.fighters().size() < wr.guard_min_men or int(j.life.get("guard", -1)) == j.c.cal.year:
		return true
	j.life["guard"] = j.c.cal.year
	var pay := guard_pay(j)
	band.silver += pay
	band.fame += wr.guard_fame
	band.honor = clampi(band.honor + wr.guard_honor, 0, 100)
	Way.add_deed(band, Way.Id.KINGS_MAN, wr.guard_deeds)
	if p.faction_id != "":
		FactionAI.shift(j.c.world, p.faction_id, FactionAI.BAND, 20)
	var who := band.leader.display_name
	j._say("%s and his men take the emperor's oath and stand in his guard at Miklagard through the summer's end and the winter: %d oz, and the Greeks know his name." % [who, pay])
	band.log("%s stood in the emperor's guard at Miklagard" % who)
	# The season is the emperor's: no more travelling this year.
	var left := j.days_left()
	if left > 0:
		j._clock(float(left))
	j.wintering = true
	return true
