class_name ExchangeResult
extends RefCounted
## The outcome of one melee exchange or one missile shot (MeleeExchange).
##
## The exchange applies wounds, breath, shield damage and effort itself. It
## does not move anyone: a shove is reported in `shove_to` and the battle loop
## applies it.

const NO_CELL := Vector2i(-1, -1)

## The two men involved (for a shot: a = archer, b = target).
var a: Warrior = null
var b: Warrior = null
## Null on a lock (tie) or when the exchange could not happen.
var winner: Warrior = null
var loser: Warrior = null
var tier: OpposedRoll.Tier = OpposedRoll.Tier.LOCKED
## Positive: `a` won. Negative: `b` won.
var margin := 0
var is_shot := false
## False when the pair could not fight (out of reach, out of range).
var happened := false
## Wound steps actually applied to the loser after absorption.
var wound_steps_dealt := 0
## Armor took one step off a hit.
var absorbed := false
## Damage done to the loser's shield this exchange.
var shield_damage := 0
var shield_broke := false
## Cell the loser should be shoved to, or NO_CELL (no shove, or blocked).
var shove_to := NO_CELL
## True when a glancing win wanted to shove but the cell was not free.
var shove_blocked := false
var went_down := false


func is_locked() -> bool:
	return happened and winner == null


func describe() -> String:
	if not happened:
		return "%s and %s cannot reach each other" % [_n(a), _n(b)]
	if winner == null:
		return "%s and %s lock, neither gives ground" % [_n(a), _n(b)]
	var verb := "shoots" if is_shot else "beats"
	var s := "%s %s %s (%s, margin %d)" % [_n(winner), verb, _n(loser), OpposedRoll.tier_name(tier), absi(margin)]
	var parts := PackedStringArray()
	if wound_steps_dealt > 0:
		parts.append(CombatTypes.WOUND_NAMES[loser.wound])
	if absorbed:
		parts.append("armor takes a step")
	if shield_damage > 0:
		parts.append("shield takes %d%s" % [shield_damage, ", splintered" if shield_broke else ""])
	if shove_to != NO_CELL:
		parts.append("shoved to %s" % shove_to)
	elif shove_blocked:
		parts.append("shove blocked")
	if went_down:
		parts.append("DOWN")
	if parts.is_empty():
		parts.append("no harm")
	return s + ": " + ", ".join(parts)


static func _n(w: Warrior) -> String:
	return w.display_name if w != null else "?"
