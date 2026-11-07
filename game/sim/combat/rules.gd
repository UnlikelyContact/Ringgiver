class_name CombatRules
extends RefCounted
## Every tunable number in the combat sim lives here, with its default.
## Modules take a CombatRules in their constructor or static calls so the
## batch runner can sweep values. Add new tunables in the section for your
## module and keep defaults sensible; never hard-code a number in a module.
##
## Stat scale: 1-10. A fresh recruit is 2-5 across the board, a veteran 4-7,
## a champion 6-9. Rolls are stat + modifiers + 2d6, opposed.

# --- Opposed roll (opposed_roll.gd) -------------------------------------
# Tier thresholds live in OpposedRoll as consts (GLANCING_MAX, HIT_MAX).

# --- Warrior / fatigue (warrior.gd) --------------------------------------
## Breath = base + grit * per_grit. Every action costs breath; bracing in a
## lull recovers it.
var breath_base := 6
var breath_per_grit := 2
var breath_cost_attack := 2
var breath_cost_move := 1
var breath_cost_brace := 0
var breath_recover_lull := 3
## Penalty to rolls per step of fatigue: -1 when breath < half, -2 at zero.
var fatigue_penalty_half := 1
var fatigue_penalty_empty := 2
## Roll penalty by wound state: unhurt, bruised, wounded, grievous, down.
## Was [0, 0, 1, 2, 99]; steepened by Module A so two equal unarmored men
## take 4-7 exchanges to a Down (the old table gave about 8.2).
var wound_penalty := [0, 1, 3, 5, 99]
var shield_hp := 3

# --- Melee exchange and absorption (attack.gd) ----------------------------
var shield_defense_bonus := 2
var locked_shields_bonus := 1
var second_rank_support_bonus := 1
var brace_defense_bonus := 1
var flank_attack_bonus := 2
var rear_attack_bonus := 4
var weapon_attack_bonus := {
	CombatTypes.Weapon.SPEAR: 0,
	CombatTypes.Weapon.BEARDED_AXE: 0,
	CombatTypes.Weapon.SWORD: 1,
	CombatTypes.Weapon.LONG_AXE: 2,
	CombatTypes.Weapon.BOW: -2,
}
## Wound steps dealt by tier: glancing 0, hit 1, heavy 2.
var steps_hit := 1
var steps_heavy := 2
## Chance (0-1) that armor absorbs one step of a hit.
var absorb_leather := 0.25
## Mail was 0.6 (x1.6 exchanges to Down); 0.75 gives the gate's "roughly doubles".
var absorb_mail := 0.75
var absorb_helmet_bonus := 0.1
## Shield damage on a glancing or absorbed blow; bearded axe deals extra.
var shield_damage_glancing := 1
var shield_damage_axe_extra := 1
## Breath each man loses when an exchange locks (tie).
var breath_cost_locked := 1
## Reach: a spear may strike at this Chebyshev distance through a friend.
var spear_reach := 2
## Missiles: archer Skill + bow_shot_bonus, -1 per missile_range_penalty_per
## tiles beyond missile_free_range. Rain costs rain_bow_penalty when raining
## (stand-in for battle conditions until those exist).
var bow_shot_bonus := 1
var missile_free_range := 3
var missile_range_penalty_per := 1
var raining := false
var rain_bow_penalty := 2

# --- Morale and the push (morale.gd, push.gd) -----------------------------
var morale_start_from_nerve := 1.0
var morale_leader_adjacent := 1
var morale_ally_down_adjacent := -2
var morale_ally_down_visible := -1
var morale_enemy_down_visible := 1
var morale_flanked := -1
var morale_leader_down := -3
var morale_banner_lost := -2
var morale_break_threshold := 3
var morale_rally_to_me := 2
var push_morale_weight := 0.5
var push_second_rank_bonus := 1

# --- Shouts, hearing and compliance (shout.gd, decision.gd) ---------------
var hear_certain_radius := 2
var hear_falloff_per_tile := 0.15
var hear_horn_radius_bonus := 3
var hear_wits_bonus := 0.05
var hear_fog_penalty := 0.3
var mishear_green := 0.5
var mishear_blooded := 0.25
var mishear_veteran := 0.1
var green_lag_chance := 0.35
var green_panic_ignore_chance := 0.3

# --- Battle loop (battle.gd) ----------------------------------------------
var max_rounds := 30
var missile_range := 6

# --- Post-battle (fate) ----------------------------------------------------
## Downed men roll 2d6 + grit against these: < fate_dead_below -> dead,
## < fate_maimed_below -> maimed, else recover.
var fate_dead_below := 7
var fate_maimed_below := 10
