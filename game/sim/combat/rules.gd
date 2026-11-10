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

# --- Decision model (decision.gd) -----------------------------------------
## A man weighs his options (sim-architecture.md, "Decision model"). Doing
## what his order says scores dm_order, plus dm_order_active when that
## means a step, a blow or a run; every alternative is scored below and
## the best wins. The ladder is spaced a point or more apart so the green
## blur (a jitter of +-dm_green_blur/2) only settles near-ties.
var dm_order := 10.0
var dm_order_active := 3.0
## The heard order weighs against leaving one's place under Hold, Shield
## wall or To me, for going forward under Push or Break them, and for
## dropping back under Fall back, by this much.
var dm_order_bearing := 1.0
## A man with friends at his shoulders is held in the wall: charging or
## stepping out from it costs this much (a reckless man in a wall leans to
## the blow instead; alone, he goes).
var dm_leave_wall := 6.0
var dm_green_blur := 0.6
## A green man who missed the shout does as the men at his shoulders do
## when this many of them (and all of them) act on one order.
var dm_green_copy_neighbours := 2
## Choosing a mark: the man in front over the man beside over the man at
## a spear's reach; then per wound step; a blooded man also sees a spoiled
## shield and (at reach) each friend the enemy is pressing, up to the cap;
## a boastful man adds dm_boast_mark for the enemy leader or a champion.
var dm_mark_front := 14.0
var dm_mark_beside := 7.0
var dm_mark_wound := 1.0
var dm_mark_shieldless := 1.0
var dm_mark_pressing := 1.0
var dm_mark_pressing_cap := 2
var dm_boast_mark := 11.0
## Covering a beset leader (men of guard_min_tier and better), a bowman
## giving ground when closed with, closing a gap (blooded: where a
## neighbour has just fallen; veteran: any), an end man turning to a
## flanker within sight (blooded 2 hexes, veteran 3).
var dm_cover_leader := 15.0
var dm_give_ground := 14.0
var dm_fill_gap := 12.0
var dm_face_flank := 11.5
var dm_flank_sight_blooded := 2
var dm_flank_sight_veteran := 3
## A hurt man drops back behind a friend: grievous (anyone feels that),
## wounded (blooded and better), more with his shield gone; less if he is
## reckless or grim.
var dm_drop_grievous := 14.0
var dm_drop_wounded := 6.0
var dm_drop_shieldless := 3.0
var dm_reckless_drop := 8.0
var dm_grim_drop := 4.0
## Champions read intentions: they throw the round before the lines meet
## and brace the round before a rush (an enemy two off under Break them or
## Push) lands.
var dm_read_throw := 14.0
var dm_read_brace := 14.0
## Personality. Reckless: charge anything within reckless_charge_radius
## whatever the order, and lean to the blow. Steady and grim: lean to
## holding and covering, and away from charging. Greedy: strip a fallen
## leader or banner man within dm_loot_radius, once. Boastful: step out
## toward the enemy leader within reckless_charge_radius. Superstitious:
## charge when the enemy's banner falls; when his own does, his order is
## worth less to him and running more (most when shaken).
var dm_reckless_charge := 16.0
var dm_reckless_strike := 1.0
var dm_steady_charge := 6.0
var dm_steady_hold := 1.0
var dm_greedy_loot := 14.0
var dm_loot_radius := 3
var dm_boast_step := 11.5
var dm_omen_charge := 16.0
var dm_omen_run := 9.0
var dm_omen_run_shaken := 3.0
## What his order is worth to a superstitious man whose own banner is down.
var dm_omen_order := 2.0
## A loose veteran goes for a hurt enemy two cells off: base plus per wound step.
var dm_wounded_step_base := 8.0
var dm_wounded_step_per := 1.5
## A loose man of the attacking side steps toward the objective rather
## than wherever his order would take him (only when the battle passes it).
var dm_objective_step := 13.5

# --- Personalities in made bands (band_factory.gd) ------------------------
## Chance a man has no personality trait, and that a man with one has a
## second (never one that conflicts, CampaignRules.personality_conflicts).
## Leaders are a little more likely to have one. Weights per trait.
var personality_none_chance := 0.3
var personality_leader_none_chance := 0.2
var personality_second_chance := 1.0 / 7.0
var personality_weights := {
	CombatTypes.Personality.STEADY: 3,
	CombatTypes.Personality.RECKLESS: 3,
	CombatTypes.Personality.GRIM: 2,
	CombatTypes.Personality.BOASTFUL: 2,
	CombatTypes.Personality.GREEDY: 1,
	CombatTypes.Personality.SUPERSTITIOUS: 1,
}

# --- Battle loop (battle.gd) ----------------------------------------------
var max_rounds := 40
## The prototype's field (hexes across and down). The lines deploy five rows
## apart about the middle; a wider field leaves room on the flanks and
## behind for ships, bows and a wheel.
var field_width := 22
var field_height := 16
## The ships lie this many rows behind the defender's front line.
var objective_ships_depth := 3
## The field shrinks with the band (Scenario.field_size): `field_width` by
## `field_height` is the field for a band of `field_band` men; a band of
## `field_small_band` or fewer fights on `field_min_width` by
## `field_min_height`, and the size runs straight between the two (and on
## past the larger, for bigger bands).
var field_band := 12
var field_small_band := 6
var field_min_width := 14
var field_min_height := 12
## How a band of n men is armed (Scenario.band_split): this share shields
## (rounded), the rest split between spears and bows, spears taking the odd
## man. Twelve men are eight, two and two; six are four, one and one.
var band_shield_share := 2.0 / 3.0
## A varied enemy brings your shields to this share more (rounded): an
## eighth at twelve men is eight or nine shields against your eight.
var enemy_more_shields := 0.125
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
## A pushing wall whose enemy is this many wheel steps or more off its front
## (BattleGrid.STATES: eight stances round the clock) wheels toward them
## rather than marching away.
var wall_wheel_min_steps := 3
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
var ai_wheel_min_steps := 3
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
## The AI wheels toward the threat, not the whole band: the nearest
## fraction of the enemy's standing men (or of their wall, weighted toward
## its nearer men), measured from his own wall. He wheels once that is this
## many stances (BattleGrid.STATES, 45 degrees each) off his front, one a
## round, two a round when their nearest man is already behind the plane of
## his line. Never while any of his wall is engaged.
var ai_threat_fraction := 0.34
var ai_threat_wheel_min_steps := 2
## Refusing the flank: an enemy wall member within this many hexes of an
## end of the AI's wall, beside it or behind the line there, makes up to
## `ai_refuse_men` men at that end hinge back one facing toward him.
var ai_refuse_range := 2
var ai_refuse_men := 3
## Weights for counting a side's strength (standing men only).
var ai_strength_shield := 1.0
var ai_strength_spear := 0.9
var ai_strength_bow := 0.6
## Ranks against ranks: a steady or cunning AI holds and taunts rather than
## walk into a ranked enemy, and comes on only when his strength is this
## ratio of theirs or better, when the mean morale of their standing men
## has fallen below `ai_push_when_wavering`, or once the lines are engaged.
var ai_push_advantage := 1.2
var ai_push_when_wavering := 5.0
## A cunning AI reckons a wall marching across his front will be this many
## hexes further along its own facing, and wheels toward there.
var ai_cunning_lead := 3.0

# --- Objectives (objective.gd) ----------------------------------------------
## A varied field (Scenario.build with vary) carries an objective this often;
## the rest are open fights. The player is the attacker in this share of them.
var objective_chance := 0.7
var objective_player_attacks := 0.5
## The side that must come on brings more men: an attacking enemy has this
## many more shield-bearers than his varied draw, a defending one this many
## fewer (your band is always the same twelve).
var objective_attacker_shields := 2
## Hold the ground (the ford): the attacker must have more standing men on
## the patch than the defender at the end of this round; otherwise the
## defender has held it.
var objective_ford_rounds := 16
# --- The ambush (scenario.gd "ambush") -------------------------------------
## The ambushed leader gives no order for this many rounds: his men stand
## where the surprise finds them, strung out along the track, and only the
## green strike back at what is in their faces (Decision, no order).
var ambush_surprise_rounds := 2
## Heart the surprised men lose at the start, never below the break
## threshold. Zero: the surprise itself (no order, no line, your spears in
## their faces) is enough; a point or two and the column runs before it
## has fought at all.
var ambush_morale := 0
## Rows between the track and your line: two, so your spears can be thrown
## at once and your wall is on them in a step.
var ambush_distance := 2
## Every so many places in the column is empty: a band on the march is
## strung out, and a wall that forms from it has gaps to close.
var ambush_gap_every := 3
## A band on the march is at full strength: it brings your shields to this
## share more (half: eight to twelve at twelve), and as many spears and
## bows as you. The ambush is the way to fight a band bigger than yours.
var ambush_more_shields := 0.5

## The objective's clock counts from the round the lines meet; an attacker
## who has not closed by this round has given the day up to the defender.
var objective_approach_rounds := 24
## Reach the ships: the attacker must get this many standing men onto the
## strip along the defender's back edge before the end of this round.
var objective_ships_rounds := 20
var objective_ships_men := 4
## On a field built for a band (Scenario.build), the ships need this share
## of the player's band (rounded up), and never fewer than
## `objective_ships_min_men`: four of twelve, two of four or six.
var objective_ships_fraction := 1.0 / 3.0
var objective_ships_min_men := 2
## The foothold that takes the ford: this share of the band over the
## stream or on the crossing when the clock runs out (three of twelve),
## never fewer than `objective_ships_min_men`. Forcing a held crossing is
## the hardest task on the field; the foothold is smaller than the ships'.
var objective_ford_fraction := 0.25
## The hall: the attacker must stand on at least half its cells for this many
## rounds running before the end of this round.
var objective_hall_rounds := 18
var objective_hall_streak := 2

# --- Fields and terrain (field.gd, battle_grid.gd, push.gd, battle.gd) -----
## A man who ends a step in MUD or a FORD spends this many steps' breath
## (breath_cost_move each) on top of the step itself.
var terrain_breath_extra := 1
## Added to a pushing group's strength, times the share of its men standing
## on SLOPE (the high ground): a line pushing downhill pushes harder.
var slope_push_bonus := 3.0
## The varied field's template in an open fight, by weight (Field.choose):
## meadow, river, farmstead, wood edge, hillside. An objective decides the
## rest: the hall is always fought on a farmstead, the ford on a river, the
## ships on a meadow (three in four, `field_ships_wood` the rest a wood
## edge). With objectives on seven fields in ten these weights bring the
## whole mix to about 30/25/25/10/10.
var field_weights := [40, 5, 5, 15, 35]
var field_ships_wood := 0.25
## Templates draw their features again from the next fork of the seed when a
## draw would leave fewer than two two-wide ways between the lines; after
## this many tries the field is cleared of the template's features.
var field_tries := 8
## The enemy leader looks this many steps along his wall's forward step for
## ground he cannot cross before he picks a way round (LeaderAI.route_target).
var ai_route_lookahead := 3

# --- Post-battle (fate) ----------------------------------------------------
## Downed men roll 2d6 + grit against these: < fate_dead_below -> dead,
## < fate_maimed_below -> maimed, else recover.
var fate_dead_below := 7
var fate_maimed_below := 8
