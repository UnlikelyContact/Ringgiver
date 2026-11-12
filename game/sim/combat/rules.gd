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
# --- The fury and the holmgang (way.gd, scenario.gd) ------------------------
## A berserk (Warrior.fury) strikes this much better while half his breath
## or more is left, feels no wound while it lasts, and is this much worse
## once it has left him. Enemies at arm's length of a man in the fury lose
## heart each round.
var fury_bonus := 2
var fury_spent_penalty := 1
var morale_fury_near := -1
## A holmgang ends at first blood: the first man WOUNDED or worse has lost.
var duel_first_blood: CombatTypes.Wound = CombatTypes.Wound.WOUNDED

# --- Drill (formation_template.gd, custom_shout.gd) -------------------------
## Drill points at which a man knows a learned shape fully (Warrior.drill,
## from Man.drill; CampaignRules.drill_points_full is the same number on
## the campaign side).
var drill_points_full := 3
## The wall's one test is scaled by this at no familiarity with a learned
## shape, straight up to 1 at full: a green band forms a shape it has never
## drilled slowly and raggedly.
var drill_unfamiliar_factor := 0.4
## A man forming a learned shape fumbles for his place (braces instead of
## stepping to his slot) with this chance times his unfamiliarity.
var drill_fumble_chance := 0.5

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

# --- The burned hall (Scenario.build_escape, Objective.Kind.ESCAPE) --------
## The field: small, so three men and the ring round them fill the screen.
var escape_width := 13
var escape_height := 12
## The jarl's men in the ring: shields and spears (no bows at night). More
## than three men can beat: it is a fight to get out of, not to win.
var escape_enemy_shields := 6
var escape_enemy_spears := 2
## Rows between the hall's door and the ring's front, where the thin place is.
var escape_ring_distance := 3
## The jarl's men are watching the roof fall in: their leader gives no
## order for this many rounds after the band comes out of the smoke.
var escape_surprise_rounds := 3
## The ring are the jarl's picked men, not farmers: their hearts are this
## much steadier than a plain band's when the fight begins, so three men
## coming out of the smoke break through the thin place but do not break
## the ring.
var escape_morale_bonus := 4
## and their nerve this much better (the break check, Morale._check_breaks).
var escape_nerve_bonus := 2
## And more of them about the burning: this many more stand off at the
## yard's edges beside the hall, and come up from the flanks as the rounds
## pass, so that a band that lingers in the yard is caught.
var escape_flankers := 4
## The saga's first fight (Objective.first_fight; docs/design/notes/
## first-fight.md). Once the band has pushed this many rounds in all, the
## burners standing between its leader and the dark, within
## `escape_give_radius` hexes of him, give way: the thin place opens for
## anyone who has pushed at all.
var escape_give_rounds := 3
var escape_give_radius := 3
## A leader cut off (an enemy at arm's length and none of his men beside
## him) this many rounds running, or no nearer the dark for
## `escape_stall_rounds` rounds once the push is done, is dragged out
## through the smoke by the nearest of his men, at a cost: the man who
## drags him is hurt (`escape_rescue_wound`), and so is he
## (`escape_rescued_wound`). Only for a band that has given an order.
var escape_rescue_rounds := 3
var escape_stall_rounds := 5
var escape_rescue_wound := CombatTypes.Wound.WOUNDED
var escape_rescued_wound := CombatTypes.Wound.BRUISED
## The night has an end: at this round the escape is told (the smoke and
## the dark cover them), or, for a band that never gave an order, its
## leader is struck down and carried off.
var escape_round_cap := 16

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

# --- The saga's fights (docs/design/notes/saga-fights.md) ----------------
## Every rule here acts only inside the fights it names: the raid's clock
## (Objective.Kind.PLUNDER), the ship fight (SEA, RAIL, Kind.DECK), the hall
## at night (Kind.FIRE, Battle.night) and the leader's luck (Warrior.luck,
## zero in every other fight), so an ordinary field fights as it did.
##
## A raid on a steading: the raiders must stand in the hall (as THE_HALL)
## before their neighbours come, this many rounds from contact. When the
## time runs out with the raiders the stronger in standing men, they have
## the field but not the hall: they go with what they can carry (the
## campaign's `raid_late_share`); otherwise the steading is held.
var objective_plunder_rounds := 16
## The ship fight: the attacker (who boards) has this many rounds from
## contact to clear the other deck from stem to stern; then the other ship
## cuts loose and rows away.
var objective_deck_rounds := 24
## The deck: rows of planking across each hull (three or four men abreast),
## its length the larger crew over `deck_men_per_column` plus room at the
## stem and stern, between `deck_min_length` and `deck_max_length` columns.
var deck_rows := 4
var deck_men_per_column := 2.0
var deck_min_length := 9
var deck_max_length := 16
## Each of the two gangways (at the bow and amidships) is this many hexes
## wide: the front a boarding party has. Two (docs/design/notes/balance.md):
## boarding a defended deck with half as many men again is about even (21
## of 40, AI against AI; 31 at three wide), at even numbers it is a forlorn
## hope (2 of 40; 8 at three).
var deck_gangway := 2
## A man overboard drowns this often; a man in mail far more often, one in
## leather a little more (CombatTypes.Armor). Otherwise he swims and is
## hauled out.
var overboard_drown := 0.2
var overboard_drown_armor := [0.0, 0.1, 0.45]
## The burning of a hall: the burners must keep at least this many men at
## the walls (the hexes along the hall) for this many rounds in all, counted
## from contact, and the roof takes; driven from the walls, the count stops.
var fire_men := 2
var fire_rounds := 6
## The night is this many rounds long: at dawn the burners who have not
## fired the roof draw off before the neighbours see them.
var fire_night_rounds := 30
## The hall at night (Scenario.build_hall_defence, build_hall_burning): the
## field, the rows the hall takes along the bottom and how far up the yard
## the attackers form.
var hall_width := 16
var hall_height := 12
var hall_attack_distance := 5
## The men breaking out of a burning hall (Scenario.build_hall_burning) are
## desperate: heart this much above a plain band's.
var breakout_morale_bonus := 2
## Luck in a fight (Warrior.luck: -1, 0 or +1, the leader's, from
## Leader.luck_modifier through the campaign): his side's men start this
## much the warmer or colder of heart, never more ...
var luck_morale := 1
## ... and his own close calls go his way: a blow on him that lands by
## `luck_close_margin` or less to spare is turned aside (a lucky man) or
## one that would have glanced off bites (an unlucky one), and his fate
## roll if he goes down is `luck_fate` the better or worse.
var luck_close_margin := 3
var luck_fate := 1

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

# --- Battles 2 (docs/design/notes/battles-2.md) ----------------------------
## Named lieutenants (Wing): a wing is about this share of the line's men
## who are not bowmen, never fewer than `wing_min_men`, nearest its end.
var wing_share := 0.34
var wing_min_men := 3
## A lieutenant sees the enemy within this many hexes of his wing's men,
## and his men within this many hexes of him hear his word.
var wing_sight := 4
var wing_voice := 4
## "Press when they waver": the enemy before him waver when one of them has
## broken or their mean heart is at or under this, by his temper (plain,
## rash, steady, cunning): a rash man sees them waver too soon, a steady
## one too late.
var wing_waver := [5.0, 7.0, 4.0, 5.5]
## A pressing (or flanking) wing whose own mean heart falls to this gives
## it up and goes back to the leader's word.
var wing_quit_morale := 3.5
## "Fall back on me": the wing is hard pressed when its mean heart is at or
## under this, by temper (a rash man waits too long, a steady one goes
## early); it gives ground for `wing_fallback_rounds` rounds while he
## rallies it, then stands again, and not again for `wing_fallback_rest`.
var wing_pressed := [6.0, 5.0, 7.0, 6.0]
var wing_fallback_rounds := 2
var wing_fallback_rest := 4
## "Go round their flank": the rest go when the enemy is within
## `wing_flank_range` hexes of the wing and it is not yet in the fight (a
## cunning man only if their line does not reach past his); a steady man
## waits this many rounds of contact; a rash one goes once the wall is
## formed.
var wing_flank_range := 3
var wing_flank_wait := 3
## "Guard the archers": the wing stands within this many hexes of the
## bowmen and goes for any enemy within `wing_guard_radius` of one (a rash
## man farther, `wing_guard_rash`).
var wing_guard_keep := 2
var wing_guard_radius := 3
var wing_guard_rash := 5
## A named man steadies the men of his wing near him (and not near their
## leader): this much heart a round, up to `wing_heart_cap`; holding the
## line in contact, up to `wing_hold_cap`; acting on his word, out of
## their leader's sight, without a cap.
var wing_heart := 1
var wing_heart_cap := 8
## A wing pressing men who waver takes this much heart a round from each
## enemy at arm's length of its men.
var wing_press_dread := -1
var wing_hold_cap := 8
## The lieutenant falls or breaks: every man of his wing loses this much
## heart, and the wing goes back to the leader's word.
var wing_leaderless_morale := -1
## How many men the line needs before the leader gives wings their words.
var wing_min_line := 8

## Men who come onto the field during a fight (Battle.arrivals): the
## district's men at a strandhogg, a friendly house at a barred hall, the
## enemy over a broken neighbour's flank. They come on as Break them.

## The strandhogg (Objective.Kind.CATTLE, Scenario.build_strandhogg): the
## herd's head of cattle, a man in the pasture with nobody at arm's length
## rounds up one beast every `cattle_gather_men` men a round, and the
## district's men come in parties of `strand_party` (at least one) every
## `strand_party_every` rounds from the first at `strand_first_party`,
## `strand_parties` parties in all, scaled by the place's defences.
var cattle_herd := 12
var cattle_gather_men := 2
var strand_first_party := 3
var strand_party_every := 2
var strand_parties := 5
var strand_party := 2
## ... and each party is this many men bigger than the one before: the
## longer the band stays, the more of the district is up.
var strand_party_growth := 1
## The herd slows the drive: a beast is lost for every man of the band who
## goes down or runs, and every `cattle_lost_per_round` ...
var cattle_lost_per_man := 1
## The field: width, height; the boats along the bottom two rows.
var strand_width := 16
var strand_height := 14
var strand_rounds := 30

## The barred hall against fire (Scenario._bar_the_door): the band inside,
## the hall's floor `bar_floor_rows` deep; the burners need `bar_fire_rounds`
## rounds at the walls (the thatch is wet with snow); and the fire is a
## clock: the torches on the roof take it at `bar_smoke_rounds` of smoke
## after the lines meet (two a round while they hold the walls), whatever
## the yard holds. A friendly house's men come `bar_help_round` rounds
## after the lines meet.
var bar_floor_rows := 3
var bar_fire_rounds := 14
var bar_smoke_rounds := 24
var bar_help_round := 4
## The burners' heart when a friendly house's men come out of the dark at
## their backs.
var bar_help_dread := -2

## The great battle's sector (Sector, Scenario.build_sector): the
## neighbours' state moves a step a round with this chance, leaning on the
## kings' strengths and on how the band's own sector goes
## (`sector_weight` of its standing share); a neighbour that breaks lets
## `sector_flank_men` of the enemy onto the band's flank (allied men when
## it wins), the day is `sector_day_rounds` long, and the band's own sector
## counts `sector_own_weight` and the king's banner `sector_banner_weight`
## in the verdict.
var sector_drift := 0.3
var sector_weight := 0.6
var sector_flank_men := 3
var sector_day_rounds := 26
var sector_own_weight := 2.0
var sector_banner_weight := 1.0
