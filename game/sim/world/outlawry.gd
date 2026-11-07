class_name Outlawry
extends RefCounted
## Outlawry (concept.md, Outlawry). Lesser outlawry runs to `outlaw_until`
## (a year); full outlawry is open-ended until lifted. The integrator checks
## `halls_closed` before contracts, winter hospitality and markets.
## See world-architecture.md, Module M.


static func declare(rules: WorldRules, band: Band, cal: Calendar, full: bool, log: PackedStringArray) -> void:
	if full:
		band.outlawry = WorldTypes.Outlawry.FULL
		band.outlaw_until = 0
		log.append("The band is declared full outlaws: any man may kill them without penalty.")
		band.log("Declared full outlaws.")
		return
	if band.outlawry == WorldTypes.Outlawry.FULL:
		log.append("The band is already full outlaws; the lesser sentence changes nothing.")
		return
	band.outlawry = WorldTypes.Outlawry.LESSER
	band.outlaw_until = maxi(band.outlaw_until, cal.year + rules.lesser_outlawry_years)
	log.append("The band is outlawed until %d." % band.outlaw_until)
	band.log("Outlawed until %d." % band.outlaw_until)


static func is_outlawed(band: Band, cal: Calendar) -> bool:
	match band.outlawry:
		WorldTypes.Outlawry.FULL:
			return true
		WorldTypes.Outlawry.LESSER:
			return cal.year < band.outlaw_until
	return false


## No contracts, no winter hospitality, no market will trade.
static func halls_closed(band: Band, cal: Calendar) -> bool:
	return is_outlawed(band, cal)


## Rolled once per voyage: a full outlaw draws hunters with `bounty_chance`.
## Returns {} or a battle request.
static func bounty_hunters(rng: SimRng, rules: WorldRules, band: Band, cal: Calendar, log: PackedStringArray) -> Dictionary:
	if band.outlawry != WorldTypes.Outlawry.FULL or not is_outlawed(band, cal):
		return {}
	if rng.randf() >= rules.bounty_chance:
		return {}
	var text := "Bounty hunters, %d men, come after the outlaw band." % rules.bounty_crew
	log.append(text)
	return {"kind": "bounty_hunters", "attackers": rules.bounty_crew, "tier": rules.bounty_tier, "text": text}


static func lift(band: Band, log: PackedStringArray) -> void:
	if band.outlawry == WorldTypes.Outlawry.NONE:
		return
	band.outlawry = WorldTypes.Outlawry.NONE
	band.outlaw_until = 0
	log.append("The band's outlawry is lifted.")
	band.log("Outlawry lifted.")
