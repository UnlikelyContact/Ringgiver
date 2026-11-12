class_name Warrior
extends RefCounted
## One named man in a battle: his fixed stats, tier, traits and gear, and his
## changing state (position, wound, breath, morale, order heard).
##
## This is the battle-side view. Potential, effort growth, loyalty and bonds
## belong to the campaign layer and are not here yet; `effort` only records
## what this battle would feed into growth.

var id := 0
var display_name := "nobody"
var side := 0

# Fixed for the battle (1-10 scale, see CombatRules).
var might := 3
var skill := 3
var grit := 3
var nerve := 3
var wits := 3
var tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var personality: Array[CombatTypes.Personality] = []

# Gear and place in the formation.
var role: CombatTypes.Role = CombatTypes.Role.SHIELD
var weapon: CombatTypes.Weapon = CombatTypes.Weapon.SPEAR
var javelins := 0  # throwing spears he still carries
var has_shield := true
var shield_hp := 3
var armor: CombatTypes.Armor = CombatTypes.Armor.NONE
var helmet := false

# Roles.
var is_leader := false
var is_banner := false
var is_horn := false

# Battle state.
var pos := Vector2i.ZERO
var facing := Vector2i(0, -1)
## For a leader: the direction his line forms to face. Zero means "his own
## facing". Set by the player (wheel left/right) or the leader AI, never by
## a step or a blow, so the wall does not wheel every time he turns.
var line_facing := Vector2i.ZERO
## For a leader: the formation his band forms on his shout. Null is the plain line.
var formation: FormationTemplate = null
## For a leader: the axis his line runs on (BattleGrid.Axis), or -1 to
## follow his wall facing (level, or plumb facing east or west).
var line_axis := -1
var wound: CombatTypes.Wound = CombatTypes.Wound.UNHURT
var breath := 0
var morale := 0
var broken := false
var fled := false
## The order this man believes he heard most recently (may be misheard).
var heard_order: CombatTypes.Shout = CombatTypes.Shout.NONE
## Rounds of delay before a green man acts on a new order.
var order_lag := 0
## Where the wall he stands in moves him this round, or NO_WALL_MOVE. Set by
## Battle before decisions; a man carried by his wall acts with it.
const NO_WALL_MOVE := Vector2i(-9999, -9999)
var wall_move := NO_WALL_MOVE
var wall_face := Vector2i.ZERO  # the facing he takes with that step (ZERO: keeps his own)
var turned_to_strike := false  # he turned off his wall's front to fight; he turns back once it is over
## What he chose last time Decision weighed his options (Decision.OPT_NAMES,
## or the plain action's name when he did what his order said), and, when
## that was not the plain default for his order, why, in his own voice.
var last_option := ""
var last_reason := ""
## A greedy man has stripped a fallen leader or banner man this battle.
var looted := false
## Men he put down this battle.
var kills := 0
## Drill points by learned shape name (Man.drill): how well he knows it.
var drill := {}
## A berserk: the fury is on him while his breath lasts (CombatRules.fury_*).
var fury := false


## Whether the fury is on him now: a berserk with half his breath or more.
func in_fury(rules: CombatRules) -> bool:
	return fury and breath * 2 >= max_breath(rules)


## How well he knows a shape, 0 to 1: full for a shape every leader knows,
## his drill points over `full` for a learned one.
func familiar(t: FormationTemplate, full: int) -> float:
	if t == null or not t.learned:
		return 1.0
	return clampf(float(drill.get(t.name, 0)) / maxf(1.0, float(full)), 0.0, 1.0)
## Effort gained this battle, by CombatTypes.Stat -> int.
var effort := {}
var fate: CombatTypes.Fate = CombatTypes.Fate.RECOVERED


static func make(p_name: String, p_side: int, stats: Array, p_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN) -> Warrior:
	var w := Warrior.new()
	w.display_name = p_name
	w.side = p_side
	w.might = stats[0]
	w.skill = stats[1]
	w.grit = stats[2]
	w.nerve = stats[3]
	w.wits = stats[4]
	w.tier = p_tier
	return w


func stat(s: CombatTypes.Stat) -> int:
	match s:
		CombatTypes.Stat.MIGHT:
			return might
		CombatTypes.Stat.SKILL:
			return skill
		CombatTypes.Stat.GRIT:
			return grit
		CombatTypes.Stat.NERVE:
			return nerve
	return wits


## The facing a line formed on this man takes.
func wall_facing() -> Vector2i:
	return line_facing if line_facing != Vector2i.ZERO else facing


## The axis a line formed on this man runs on.
func wall_axis() -> int:
	return line_axis if line_axis >= 0 else BattleGrid.default_axis(wall_facing())


## Turns his wall `steps` right-hand stances round (BattleGrid.STATES).
func wheel_wall(steps: int) -> void:
	var s := BattleGrid.wheel_state(wall_axis(), wall_facing(), steps)
	line_axis = s[0]
	line_facing = s[1]
	facing = line_facing


func is_down() -> bool:
	return wound == CombatTypes.Wound.DOWN


## Still on the field and able to act (not down, not fled). Broken men are
## active: they act, but their action is to flee.
func is_active() -> bool:
	return not is_down() and not fled


func has_personality(p: CombatTypes.Personality) -> bool:
	return personality.has(p)


func max_breath(rules: CombatRules) -> int:
	return rules.breath_base + grit * rules.breath_per_grit


func reset_for_battle(rules: CombatRules) -> void:
	breath = max_breath(rules)
	shield_hp = rules.shield_hp if has_shield else 0
	wound = CombatTypes.Wound.UNHURT
	broken = false
	fled = false
	heard_order = CombatTypes.Shout.NONE
	order_lag = 0
	effort = {}
	morale = clampi(int(round(nerve * rules.morale_start_from_nerve)) + rules.morale_start_bonus, 0, 10)


func wound_penalty(rules: CombatRules) -> int:
	return rules.wound_penalty[wound]


func fatigue_penalty(rules: CombatRules) -> int:
	if breath <= 0:
		return rules.fatigue_penalty_empty
	if breath < max_breath(rules) / 2:
		return rules.fatigue_penalty_half
	return 0


## Combined roll penalty from wounds and fatigue (a positive number to subtract).
func condition_penalty(rules: CombatRules) -> int:
	if fury:
		# In the fury he feels no wound and strikes harder; spent, he is weak.
		if in_fury(rules):
			return -rules.fury_bonus
		return wound_penalty(rules) + fatigue_penalty(rules) + rules.fury_spent_penalty
	return wound_penalty(rules) + fatigue_penalty(rules)


func spend_breath(cost: int) -> void:
	breath = maxi(0, breath - cost)


func recover_breath(amount: int, rules: CombatRules) -> void:
	breath = mini(max_breath(rules), breath + amount)


## Advances the wound state by `steps`, never past DOWN. Returns the new state.
func take_wound_steps(steps: int) -> CombatTypes.Wound:
	wound = mini(wound + steps, CombatTypes.Wound.DOWN) as CombatTypes.Wound
	return wound


func shield_usable() -> bool:
	return has_shield and shield_hp > 0


func add_effort(s: CombatTypes.Stat, amount := 1) -> void:
	effort[s] = effort.get(s, 0) + amount


func describe() -> String:
	return "%s (%s, side %d) M%d S%d G%d N%d W%d %s at %s morale %d breath %d" % [
		display_name, CombatTypes.TIER_NAMES[tier], side, might, skill, grit, nerve, wits,
		CombatTypes.WOUND_NAMES[wound], pos, morale, breath,
	]
