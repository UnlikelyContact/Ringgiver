class_name Leader
extends RefCounted
## The leader's luck and reputation (concept.md, Luck and reputation). The
## state lives on Band: luck 0-10, fame 0-100, honor 0-100, vows. Every value
## comes from CampaignRules (section "Leader, family and succession").

const LUCK_MIN := 0
const LUCK_MAX := 10
const REP_MIN := 0
const REP_MAX := 100


## After a fight. `odds` is our strength over theirs (1.0 = even); a win at
## odds below long_odds is a win against the odds and is worth more luck and
## fame than an ordinary win. Hanging back costs luck and honor either way.
static func on_battle(rules: CampaignRules, band: Band, won: bool, led_from_front: bool,
		odds: float, log: PackedStringArray) -> void:
	var who := _name(band)
	if won and odds < rules.long_odds:
		_add(band, rules.luck_long_odds, rules.fame_long_odds, 0)
		log.append("%s won against the odds: his luck is talked of" % who)
	elif won:
		_add(band, rules.luck_win, rules.fame_win, 0)
		log.append("%s won the day" % who)
	else:
		_add(band, -rules.luck_loss, 0, 0)
		log.append("%s lost the fight, and some say his luck is waning" % who)
	if not led_from_front:
		_add(band, -rules.luck_hung_back, 0, -rules.honor_hung_back)
		log.append("%s hung back from the shield-wall" % who)


static func on_vow_kept(rules: CampaignRules, band: Band, vow: String, log: PackedStringArray) -> void:
	_mark_vow(band, vow, true)
	_add(band, rules.luck_vow_kept, rules.fame_vow_kept, rules.honor_vow_kept)
	var text := "%s kept his vow: %s" % [_name(band), vow]
	log.append(text)
	band.log(text)


static func on_vow_broken(rules: CampaignRules, band: Band, vow: String, log: PackedStringArray) -> void:
	_mark_vow(band, vow, false)
	_add(band, -rules.luck_vow_broken, 0, -rules.honor_vow_broken)
	var text := "%s broke his vow: %s" % [_name(band), vow]
	log.append(text)
	band.log(text)


static func on_oath_broken(rules: CampaignRules, band: Band, log: PackedStringArray) -> void:
	_add(band, -rules.luck_oath_broken, 0, -rules.honor_oath_broken)
	var text := "%s broke his sworn oath, and men remembered it" % _name(band)
	log.append(text)
	band.log(text)


## A plain feast keeps the hall but wins no fame; a lavish one is talked of.
static func on_feast(rules: CampaignRules, band: Band, lavish: bool, log: PackedStringArray) -> void:
	if not lavish:
		return
	_add(band, 0, rules.fame_feast, 0)
	log.append("%s's feast was talked of far and wide" % _name(band))


## The leader ignored an omen; with omen_chance it comes true and costs luck.
static func on_omen_ignored(rng: SimRng, rules: CampaignRules, band: Band, log: PackedStringArray) -> void:
	if rng.randf() < rules.omen_chance:
		_add(band, -rules.luck_omen, 0, 0)
		log.append("%s ignored the omen, and it came true" % _name(band))
	else:
		log.append("%s ignored the omen, and nothing came of it" % _name(band))


## -1, 0 or +1 for the leader's rolls and the band's events.
static func luck_modifier(rules: CampaignRules, band: Band) -> int:
	if band.luck >= rules.luck_high:
		return 1
	if band.luck <= rules.luck_low:
		return -1
	return 0


## How many men want to join this year.
static func recruits_drawn(rules: CampaignRules, band: Band) -> int:
	return maxi(rules.recruits_min, band.fame / maxi(1, rules.fame_per_recruit))


static func _add(band: Band, d_luck: int, d_fame: int, d_honor: int) -> void:
	band.luck = clampi(band.luck + d_luck, LUCK_MIN, LUCK_MAX)
	band.fame = clampi(band.fame + d_fame, REP_MIN, REP_MAX)
	band.honor = clampi(band.honor + d_honor, REP_MIN, REP_MAX)


## Marks the latest open vow with this text kept or broken; records it if absent.
static func _mark_vow(band: Band, vow: String, kept: bool) -> void:
	for i in range(band.vows.size() - 1, -1, -1):
		var v: Dictionary = band.vows[i]
		if v.get("text", "") == vow and v.get("kept") == null:
			v["kept"] = kept
			return
	band.vows.append({"year": band.year, "text": vow, "kept": kept})


static func _name(band: Band) -> String:
	return band.leader.display_name if band.leader != null else "The leader"
