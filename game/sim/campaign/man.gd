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


## Builds the battle-side view. Ids are preserved so BattleBridge can map
## warriors back to men. A lost hand means no shield.
func to_warrior(side: int) -> Warrior:
	var w := Warrior.make(display_name, side, stats.duplicate(), tier)
	w.id = id
	w.personality = personality.duplicate()
	w.weapon = weapon
	w.has_shield = has_shield and not has_maim(CampaignTypes.Maim.LOST_HAND) \
			and weapon != CombatTypes.Weapon.LONG_AXE and weapon != CombatTypes.Weapon.BOW
	w.armor = armor
	w.helmet = helmet
	w.is_leader = is_leader
	w.is_banner = is_banner
	w.is_horn = is_horn
	return w


func describe() -> String:
	return "%s, %d, %s, %s: M%d S%d G%d N%d W%d, loyalty %d, wants %s" % [
		display_name, age, CampaignTypes.ORIGIN_NAMES[origin], CombatTypes.TIER_NAMES[tier],
		stats[0], stats[1], stats[2], stats[3], stats[4], loyalty, CampaignTypes.AMBITION_NAMES[ambition],
	]
