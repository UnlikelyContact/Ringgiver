class_name Man
extends RefCounted
## A sworn man across the years. The battle sim sees him as a Warrior built
## by to_warrior(); what comes back (effort, fate) is applied by BattleBridge.

var id := 0
var display_name := "nobody"
var age := 20
var born := 846
var alive := true
var origin: CampaignTypes.Origin = CampaignTypes.Origin.YOUNGER_SON

# Stats (1-10), hidden caps, and effort pools, indexed by CombatTypes.Stat.
var stats: Array[int] = [3, 3, 3, 3, 3]
var potential: Array[int] = [5, 5, 5, 5, 5]
var effort: Array[int] = [0, 0, 0, 0, 0]

var tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var battles_survived := 0
var personality: Array[CombatTypes.Personality] = []
## Free-text earned traits ("blooded at Hafrsfjord", "afraid of water").
var traits: PackedStringArray = []
var maims: Array[CampaignTypes.Maim] = []
var healing_turns := 0
## What a fight leaves on him (Aftermath): men he has put down, times he
## broke and ran, and deeds told of him.
var kills := 0
var broke_count := 0
var deeds: PackedStringArray = []
## This year's part of it, for the ring-giving: fights stood, men put
## down, wounds taken, times he broke, deeds told. Counted by
## Campaign.conclude_fight, cleared at the thaw.
var year_tally := {}
## His place in the line (CombatTypes.Role): a shield-bearer, a spearman
## of the second rank, or a bowman.
var role: CombatTypes.Role = CombatTypes.Role.SHIELD
## Whether he has been given that place (Campaign._arm_new_men); a man
## keeps the place he was given.
var armed := false
## How deep the fury runs in him (0: none; the leader's is set from his
## steps down the berserk's way, Way.refresh).
var fury := 0
## Drill points by learned shape name: how well he knows it (concept.md,
## "Drill, custom formations and custom shouts"), and the last year he
## drilled, for the thaw's decay.
var drill := {}
var drilled_year := 0


## A point of drill in a shape, to `full`.
func learn(shape: String, full: int, year := 0) -> void:
	drill[shape] = mini(full, int(drill.get(shape, 0)) + 1)
	if year > 0:
		drilled_year = year

var ambition: CampaignTypes.Ambition = CampaignTypes.Ambition.SILVER
var ambition_progress := 0
var ambition_met := false
var loyalty := 50

# Gear.
var weapon: CombatTypes.Weapon = CombatTypes.Weapon.SPEAR
var has_shield := true
var armor: CombatTypes.Armor = CombatTypes.Armor.NONE
var helmet := false

# Roles.
var is_leader := false
var is_banner := false
var is_horn := false
var joined_year := 0
## A man hired for pay in summer: his wage every WorldRules.wage_days (0 for
## a sworn man, who takes his share of the plunder), when he was last paid
## (the summer's clock), and what kind of man he was for hire. A man lent
## by a house (`lent_by`, its name) goes home at the summer's end.
var wage := 0
var paid_until := 0.0
var hire_kind := ""
var lent_by := ""
## Men and silver (docs/design/notes/men-silver.md). A woman of the band:
## a shieldmaiden, a rare exception (Shieldmaidens). Nothing in the fight
## differs for her; the saga's words do (`he`, `his`, `him`, `man_word`).
var woman := false
## The leader's nature (Natures keys): two traits chosen at the saga's
## start, or a son's share of his father's. Empty for most men, whose
## nature is their `personality`.
var natures: PackedStringArray = []
## A sword with a name, bought from a great smith (Estate): "" for none.
var sword_name := ""


## The saga's words for this man or woman: "he"/"she", "his"/"her",
## "him"/"her", "man"/"woman", "son"/"daughter"; `cap` raises the first letter.
func he(cap := false) -> String:
	var w := "she" if woman else "he"
	return w.capitalize() if cap else w


func his(cap := false) -> String:
	var w := "her" if woman else "his"
	return w.capitalize() if cap else w


func him() -> String:
	return "her" if woman else "him"


func himself() -> String:
	return "herself" if woman else "himself"


func man_word() -> String:
	return "woman" if woman else "man"


## One of this year's counts (`year_tally`), 0 when none.
func this_year(key: String) -> int:
	return int(year_tally.get(key, 0))


func stat(s: CombatTypes.Stat) -> int:
	return stats[s]


func set_stat(s: CombatTypes.Stat, v: int) -> void:
	stats[s] = clampi(v, 1, 10)


func total_stats() -> int:
	var t := 0
	for v in stats:
		t += v
	return t


func has_personality(p: CombatTypes.Personality) -> bool:
	return personality.has(p)


func has_maim(m: CampaignTypes.Maim) -> bool:
	return maims.has(m)


## The wound he carries now, from the healing he has left (CampaignRules.
## wound_turns): unhurt, bruised, wounded, or grievous.
func current_wound(rules: CampaignRules) -> CombatTypes.Wound:
	if healing_turns <= 0:
		return CombatTypes.Wound.UNHURT
	if healing_turns >= rules.grievous_turns:
		return CombatTypes.Wound.GRIEVOUS
	if healing_turns >= rules.wound_turns[CombatTypes.Wound.WOUNDED]:
		return CombatTypes.Wound.WOUNDED
	return CombatTypes.Wound.BRUISED


## Too hurt to stand in a line: left at the ship.
func too_hurt_to_fight(rules: CampaignRules) -> bool:
	return healing_turns >= rules.grievous_turns


## Builds the battle-side view. Ids are preserved so BattleBridge can map
## warriors back to men. A lost hand means no shield; a bowman has none;
## a shield-bearer carries `javelins` throwing spears. `rules` (campaign)
## puts the wound he carries on him; null sends him unhurt.
func to_warrior(side: int, rules: CampaignRules = null, javelins := 1) -> Warrior:
	var w := Warrior.make(display_name, side, stats.duplicate(), tier)
	w.id = id
	w.personality = personality.duplicate()
	w.role = role
	w.weapon = weapon
	if role == CombatTypes.Role.MISSILE:
		w.weapon = CombatTypes.Weapon.BOW
	elif role == CombatTypes.Role.SPEAR:
		w.weapon = CombatTypes.Weapon.SPEAR
	w.has_shield = has_shield and role != CombatTypes.Role.MISSILE and not has_maim(CampaignTypes.Maim.LOST_HAND) \
			and w.weapon != CombatTypes.Weapon.LONG_AXE and w.weapon != CombatTypes.Weapon.BOW
	if role == CombatTypes.Role.SHIELD:
		w.javelins = javelins
	w.armor = armor
	w.helmet = helmet
	w.is_leader = is_leader
	w.is_banner = is_banner
	w.is_horn = is_horn
	w.drill = drill.duplicate()
	w.fury = fury > 0 or traits.has("berserk")
	w.fury_level = maxi(1, fury)
	if rules != null:
		w.wound = current_wound(rules)
	return w


func describe() -> String:
	return "%s, %d, %s, %s: M%d S%d G%d N%d W%d, loyalty %d, wants %s" % [
		display_name, age, CampaignTypes.ORIGIN_NAMES[origin], CombatTypes.TIER_NAMES[tier],
		stats[0], stats[1], stats[2], stats[3], stats[4], loyalty, CampaignTypes.AMBITION_NAMES[ambition],
	]
