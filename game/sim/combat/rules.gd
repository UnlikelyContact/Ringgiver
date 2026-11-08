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
## Locked shields: the full bonus with a shield-bearer on both sides, half
## with one. A locked man is also braced by his neighbours: a glancing blow
## cannot shove him.
var locked_shields_bonus := 2
var locked_braces_against_shove := true
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
## Added to starting morale so a fresh man is not already at the break threshold.
var morale_start_bonus := 3
var morale_leader_adjacent := 2
## The leader's presence reaches further than arm's length: men within
## `morale_leader_near_radius` hexes (but not adjacent) gain this each round.
var morale_leader_near := 1
var morale_leader_near_radius := 2
var morale_ally_down_adjacent := -2
var morale_ally_down_visible := -1
var morale_enemy_down_visible := 1
var morale_flanked := -1
## A man with no friend at his shoulder in his line (BattleGrid.line_neighbors)
## loses heart each round: a mob milling about is still a crowd of lone men.
var morale_alone := -1
var morale_leader_down := -3
var morale_banner_lost := -2
var morale_break_threshold := 3
## Leaders never break: a leader's nerve is a choice (the player's, or the AI's fall back).
var leaders_never_break := true
var morale_rally_to_me := 2
var push_morale_weight := 0.5
var push_second_rank_bonus := 1
## After a won push, winners step into the vacated ground so contact holds.
var push_winners_advance := true
## A push only moves a line when the winner's margin reaches this; smaller
## margins are a heave that gains nothing, which keeps lines from dissolving.
var push_min_margin := 4
## A losing line gives ground all together or holds; winners follow only when it moved.
var push_as_a_line := true
var push_line_fraction := 0.5
## Being pressed back with nowhere to go costs heart as well as breath.
var push_pressed_morale := -1
## An ordered fall back costs no heart; being driven back by a push does,
## and driving the enemy back gives it.
var fall_back_morale := 0
var push_shoved_morale := -1
var push_won_morale := 1
## Chebyshev radius within which a man sees a friend or foe go down.
var morale_visible_radius := 3
## A man at or below the break threshold rolls 2d6 + Nerve + personality
## modifier and must reach this or break.
var morale_check_target := 9
## Added to the break check for STEADY and GRIM men.
var morale_steady_bonus := 2
## Morale change for each friend adjacent to a man who breaks this round.
var morale_panic_spread := -2
## A broken man whose morale is back above the threshold rallies if his
## leader is active and within this Chebyshev radius.
var rally_radius := 2
## Breath lost by a man the push would shove whose cell behind is blocked.
var push_blocked_breath := 2

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
## Men of this tier or better step in when the leader has `guard_threats`
## or more enemies on him (champions always do, at two).
var guard_min_tier := CombatTypes.Tier.VETERAN
var guard_threats := 2
## The wall's one test to move as one is the mean chance to hear, scaled by
## the wall's average tier: green walls hesitate, veteran walls do not.
var wall_test_tier_factor := [0.75, 0.9, 1.0, 1.0]
## A man falling back who finds himself this far from his leader rejoins him instead.
var fall_back_regroup_distance := 3
## An active banner-bearer on the side widens the certain-hearing radius.
var hear_banner_radius_bonus := 2
## A Reckless man charges (behaves as Break them!) when an enemy is this close.
var reckless_charge_radius := 3
## Under Fall back!, green and blooded men at or below this morale waver and
## run for the round instead of stepping back in order.
var fall_back_steady_morale := 4

# --- Battle loop (battle.gd) ----------------------------------------------
var max_rounds := 40
## A side whose leader has called "fall back" and whose men are all at least
## this far from every enemy has left the field and loses.
var withdraw_distance := 4
## A side still falling back after this many rounds without a blow landing
## on either side has given up the field: a pursuit at equal speed never
## catches anyone, and a line that keeps giving ground has lost.
var retreat_stall_rounds := 4
## Once blows have been struck, this many rounds without one ends the fight:
## a side with fewer standing men than this fraction of the other's quits
## and loses, otherwise both draw off.
var stall_rounds := 6
## A pushing wall whose enemy is this many facings (60 degrees each) or more
## off its front wheels toward them rather than marching away.
var wall_wheel_min_steps := 2
## A wall bends: two men stay linked while their facings differ by at most
## this many hex facings, and a man stays in the wall while he faces no more
## than `wall_max_bend` facings off the leader's. Bend further and it breaks.
var wall_link_turn := BattleGrid.DEFAULT_LINK_TURN
var wall_max_bend := BattleGrid.DEFAULT_MAX_BEND
var stall_quit_fraction := 0.5
var missile_range := 6
## Throwing spears: how many a shield-bearer carries, how far he throws
## (hexes), what he adds to Might for the throw, and what a spear stuck in a
## shield does to it.
var javelins_per_man := 1
var javelin_range := 2
var javelin_bonus := 2
var javelin_shield_damage := 1
## A bowman further than this from his leader stops shooting and keeps up.
var missile_keep_distance := 5
## Arrows against a man whose shield is locked with a neighbour's mostly
## rattle off: this is added to his defence against a shot (not a thrown
## spear). A wall is the answer to archers; loose men are their meat.
var arrow_vs_locked_bonus := 3
## LeaderAI doctrine thresholds.
var ai_form_rounds := 2
var ai_hold_rounds_before_push := 2
var ai_fall_back_percent := 35
var ai_break_them_percent := 40
var ai_scatter_mean_distance := 3
## The AI wheels its wall when the enemy is this many facings (60 degrees each) off it.
var ai_wheel_min_steps := 2
var ai_wheel_cooldown := 3
## A STEADY leader waits this many rounds without contact before pushing.
var ai_patience_rounds := 6
## Taunts. A leader's jeer carries this far; every enemy in earshot who is
## standing (his side not driving forward, and nobody of ours at arm's
## length) loses this much heart, never below the break threshold plus
## one: shame shakes a man, it does not rout him. Steady and Grim men do
## not hear it. Our own men in earshot take heart from the jeering.
var taunt_range := 5
var taunt_morale := -1
var taunt_cheer := 1
## A taunted AI leader comes on: always if aggressive, else with this chance
## per taunt once his line is formed. A steady AI taunts a holding enemy
## every taunt_ai_every rounds while nobody is engaged.
var taunt_answer_chance := 0.5
var taunt_ai_every := 3

# --- Post-battle (fate) ----------------------------------------------------
## Downed men roll 2d6 + grit against these: < fate_dead_below -> dead,
## < fate_maimed_below -> maimed, else recover.
var fate_dead_below := 7
var fate_maimed_below := 8
