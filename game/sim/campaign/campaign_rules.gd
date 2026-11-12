class_name CampaignRules
extends RefCounted
## Every tunable in the campaign layer, with defaults, sectioned by module.
## Add yours in your module's section. See campaign-architecture.md > Scales.

# --- Core -------------------------------------------------------------------
var start_year := 866
var join_age_min := 15
var join_age_max := 30
var loyalty_start := 50

# --- Growth and recruits (Module E: potential.gd, growth.gd, recruits.gd, bridge.gd)
var growth_pool_per_point := 6
var total_soft_cap := 32
var nature_up := 1.25
var nature_down := 0.75
var age_growth_under_20 := 1.5
var age_growth_20_25 := 1.2
var age_growth_26_35 := 1.0
var age_growth_36_plus := 0.5
var decline_age := 40
var old_age := 50
var decline_chance := 0.2
var tier_blooded_battles := 1
var tier_veteran_battles := 6
var tier_champion_battles := 15
var tier_champion_min_stat := 7
var cap_mean := 5
var cap_spread := 3
var coal_biter_chance := 0.08
var coal_biter_max_stat := 3
var coal_biter_min_cap := 8
var inherit_spread := 2
var drill_effort := 6
var loyalty_fled_penalty := 5
var bond_fought_together := 2
## Maim -> [stat, penalty]; stat is a CombatTypes.Stat.
var maim_penalties := {
	CampaignTypes.Maim.LOST_HAND: [CombatTypes.Stat.SKILL, 2],
	CampaignTypes.Maim.LAME_LEG: [CombatTypes.Stat.GRIT, 2],
	CampaignTypes.Maim.ONE_EYE: [CombatTypes.Stat.WITS, 1],
	CampaignTypes.Maim.BROKEN_RIBS: [CombatTypes.Stat.MIGHT, 1],
	CampaignTypes.Maim.SCARRED_FACE: [CombatTypes.Stat.NERVE, 0],
}
## Personality pairs that never appear on the same man.
var personality_conflicts := [
	[CombatTypes.Personality.RECKLESS, CombatTypes.Personality.STEADY],
	[CombatTypes.Personality.BOASTFUL, CombatTypes.Personality.GRIM],
]
## Hint phrases: stat -> [low, middling, high, great].
var hint_phrases := {
	CombatTypes.Stat.MIGHT: ["slight of frame", "a fair pair of arms", "strong-armed", "bear-strong"],
	CombatTypes.Stat.SKILL: ["clumsy with a blade", "handy enough", "deft", "born to the sword"],
	CombatTypes.Stat.GRIT: ["soon winded", "hardy enough", "tireless", "iron-bodied"],
	CombatTypes.Stat.NERVE: ["faint-hearted", "steady enough", "slow to anger", "fearless"],
	CombatTypes.Stat.WITS: ["slow-witted", "sensible", "sharp", "far-seeing"],
}
## judge_level 0 text; judge_level 1 text [no room above current, room to grow];
## the marker a judge_level 3 hint adds to the man's best stat.
var hint_unknown := "no one can say"
var hint_room_phrases := ["has grown as far as it will", "could grow yet"]
var hint_best_marker := ", his greatest gift"
## Personality -> [stat whose effort goes up, stat whose effort goes down].
var nature_effects := {
	CombatTypes.Personality.RECKLESS: [CombatTypes.Stat.MIGHT, CombatTypes.Stat.WITS],
	CombatTypes.Personality.GRIM: [CombatTypes.Stat.NERVE, CombatTypes.Stat.SKILL],
	CombatTypes.Personality.BOASTFUL: [CombatTypes.Stat.SKILL, CombatTypes.Stat.GRIT],
	CombatTypes.Personality.STEADY: [CombatTypes.Stat.NERVE, CombatTypes.Stat.MIGHT],
	CombatTypes.Personality.GREEDY: [CombatTypes.Stat.WITS, CombatTypes.Stat.NERVE],
	CombatTypes.Personality.SUPERSTITIOUS: [CombatTypes.Stat.GRIT, CombatTypes.Stat.WITS],
}
## Decline and maims also lower the hidden cap, so effort cannot undo them.
var decline_lowers_cap := true
var maim_lowers_cap := true
## Recruit starting stats: base ± spread, plus the origin's bias per stat.
var recruit_stat_base := 3
var recruit_stat_spread := 1
var origin_stat_bias := {
	CampaignTypes.Origin.FISHERMAN: [0, 0, 1, 0, 0],
	CampaignTypes.Origin.YOUNGER_SON: [0, 0, 0, 0, 0],
	CampaignTypes.Origin.OUTLAW: [1, 0, 0, 1, 0],
	CampaignTypes.Origin.FREEDMAN: [-1, -1, 0, -1, -1],
	CampaignTypes.Origin.EXILED_JARLS_SON: [0, 1, 0, 0, 1],
}
## Origin -> [min age, max age] at joining (within join_age_min..join_age_max).
var origin_age_ranges := {
	CampaignTypes.Origin.FISHERMAN: [16, 30],
	CampaignTypes.Origin.YOUNGER_SON: [15, 24],
	CampaignTypes.Origin.OUTLAW: [18, 30],
	CampaignTypes.Origin.FREEDMAN: [17, 30],
	CampaignTypes.Origin.EXILED_JARLS_SON: [15, 22],
}
## The trait each origin brings (appended to Man.traits).
var origin_traits := {
	CampaignTypes.Origin.FISHERMAN: "good at sea",
	CampaignTypes.Origin.YOUNGER_SON: "landless",
	CampaignTypes.Origin.OUTLAW: "outlawed",
	CampaignTypes.Origin.FREEDMAN: "once a thrall",
	CampaignTypes.Origin.EXILED_JARLS_SON: "of jarl's blood",
}
## Starting loyalty by origin; origins not listed use loyalty_start.
var origin_loyalty := {
	CampaignTypes.Origin.OUTLAW: 30,
	CampaignTypes.Origin.FREEDMAN: 70,
}
## How often Recruits.random picks each origin.
var origin_weights := {
	CampaignTypes.Origin.FISHERMAN: 3,
	CampaignTypes.Origin.YOUNGER_SON: 4,
	CampaignTypes.Origin.OUTLAW: 2,
	CampaignTypes.Origin.FREEDMAN: 2,
	CampaignTypes.Origin.EXILED_JARLS_SON: 1,
}
## Origin -> {Ambition -> weight}. The exiled jarl's son wants fame.
var ambition_weights := {
	CampaignTypes.Origin.FISHERMAN: {
		CampaignTypes.Ambition.SILVER: 3, CampaignTypes.Ambition.LAND: 2, CampaignTypes.Ambition.WIFE: 2,
		CampaignTypes.Ambition.HOME: 2, CampaignTypes.Ambition.FAME: 1,
	},
	CampaignTypes.Origin.YOUNGER_SON: {
		CampaignTypes.Ambition.LAND: 4, CampaignTypes.Ambition.SILVER: 2, CampaignTypes.Ambition.FAME: 2,
		CampaignTypes.Ambition.WIFE: 2,
	},
	CampaignTypes.Origin.OUTLAW: {
		CampaignTypes.Ambition.SILVER: 4, CampaignTypes.Ambition.VENGEANCE: 3, CampaignTypes.Ambition.HOME: 1,
	},
	CampaignTypes.Origin.FREEDMAN: {
		CampaignTypes.Ambition.LAND: 3, CampaignTypes.Ambition.WIFE: 3, CampaignTypes.Ambition.SILVER: 2,
	},
	CampaignTypes.Origin.EXILED_JARLS_SON: {
		CampaignTypes.Ambition.FAME: 1,
	},
}
## Chance a recruit has a second personality trait (never a conflicting one).
var second_personality_chance := 0.4

# --- Loyalty, ambitions and bonds (Module F: loyalty.gd, bonds.gd) ---------
var loyalty_per_ounce := 2
var gift_cap := 20
var ring_gift_ounces := 8
var loyalty_ring_bonus := 5
var loyalty_gear_gift := 15
var ambition_gift_bonus := 5
var fair_leader_share := 0.34
var loyalty_fair_share := 4
var loyalty_unfair_share := 8
var ambition_fulfilled := 100
var loyalty_ambition_met := 25
var loyalty_leave_below := 20
var loyalty_turn_below := 10
var turn_chance := 0.5
var turn_theft_ounces := 10
var loyalty_unfed_per_turn := 8
var loyalty_unseated := 6
var loyalty_winter_rest := 1
var luck_loyalty_above := 7
var luck_loyalty_below := 3
var loyalty_luck_bonus := 2
var loyalty_seating_passed := 6
var loyalty_seating_honor := 4
var loyalty_grief := 5
var bond_brother_left := 10
var bond_oath_threshold := 60
var bond_rival_threshold := -40
var bond_clash_drift := 4
var bond_kin_drift := 2
var quarrel_chance := 0.15
var bond_quarrel := 15

# --- Winter hall (Module G: hall.gd, winter.gd, winter_events.gd) ----------
var hall_base_seats := 8
var benches_seats := 6
var food_base_capacity := 60
var storehouse_capacity := 60
var hunt_rations := 3
var hunt_spread := 1
var fish_rations := 4
var byre_rations := 2
var feast_rations_per_man := 2
var events_per_turn := 1
var feud_attack_chance := 0.25
var sickness_men := 2
var sickness_turns := 2
## Healing a battle leaves to do, by the wound a man ends it with
## (CombatTypes.Wound: unhurt, bruised, wounded, grievous, down and
## recovered). A man mends a turn between summer fights
## (`mend_between_fights`) and every winter turn; with
## `grievous_turns` or more left he is left at the ship and does not
## fight (Band.fighters); fewer, he fights hurt (Man.current_wound).
var wound_turns := [0, 1, 2, 4, 4]
var grievous_turns := 4
var mend_between_fights := 1
## A man who breaks and runs loses this loyalty and it is remembered
## (Man.broke_count, a trait the first time).
var loyalty_broke_penalty := 3
## Silver a man strips from a fallen enemy leader or banner-bearer.
var loot_per_man := 8
## After a fight won on land a man may ask to join: the chance after a
## rout, and after a plainer win.
var recruit_after_rout_chance := 0.35
var recruit_after_win_chance := 0.15
## A man who puts down this many in one fight has a deed told of him.
var deed_kills := 2
var building_costs := {
	CampaignTypes.Building.BENCHES: 20,
	CampaignTypes.Building.STOREHOUSE: 30,
	CampaignTypes.Building.SMITHY: 40,
	CampaignTypes.Building.BOATHOUSE: 35,
	CampaignTypes.Building.BYRE: 25,
}
## kind -> weight; see campaign-architecture.md for effects.
var winter_events := {
	"skald": 3, "trader": 3, "outlaw_shelter": 2, "marriage_offer": 1, "envoy": 2,
	"sickness": 2, "storm": 2, "thrall_unrest": 1, "quarrel": 2, "feud_attack": 2, "hall_burning": 1,
}
var rumor_lines := [
	"a rich farm lies unguarded up the fjord",
	"the jarl's levy musters at midsummer",
	"a merchant knarr winters at Kaupang",
	"your enemy's kin gather at the Thing",
]
## Hall-burning fires with this chance when picked (halved by a guard),
## and only while a feud is unsettled.
var hall_burning_chance := 0.15
var feud_attack_men := 6
var feud_attack_spread := 2
var hall_burning_men := 10
var hall_burning_spread := 3
## Event effects. Fame and loyalty changes are reported, not applied.
var skald_fee := 5
var skald_fame := 3
var trader_price := 10
var trader_food := 15
var storm_ship_damage := 1
var thrall_unrest_food := 6
var quarrel_holmgang_chance := 0.3
var envoy_fame := 1
## Houses of the web (Families, NorwayData.HOUSES) whose daughters a winter
## guest may be offered: Norse houses at home, none of them the burners.
var marriage_houses := ["Horda-Kari's kin", "Hrafn's kin", "the Sygna kings"]
## default_plan: ounces given to each of the three lowest-loyalty men at Yule.
var default_gift_ounces := 5

# --- Leader, family and succession (Module H) -------------------------------
var luck_start := 5
var luck_win := 1
var luck_loss := 1
var luck_long_odds := 2
var long_odds := 0.7
var luck_hung_back := 1
var honor_hung_back := 5
var luck_vow_kept := 1
var honor_vow_kept := 5
var fame_vow_kept := 5
var luck_vow_broken := 2
var honor_vow_broken := 10
var luck_oath_broken := 3
var honor_oath_broken := 25
var fame_feast := 3
## Fame from victories (a win against long odds gives fame_long_odds instead).
var fame_win := 1
## A rout is talked of more than a drive-off: this much fame on top.
var fame_rout := 1
## Withdrawing in order before the lines meet again is a choice, not a
## defeat: it costs honor, not luck, and brings no fame. Both sides drawing
## off is nobody's day and costs nothing.
var honor_withdrew := 3
var fame_long_odds := 5
var omen_chance := 0.3
## Luck lost when an ignored omen comes true (rolled with omen_chance).
var luck_omen := 1
var luck_high := 7
var luck_low := 3
## Luck wanders (docs/design/notes/balance.md). A plain win at
## `luck_crest` or more seldom adds luck (a man so lucky is expected to
## win; `luck_crest_chance`); a win against the odds, a vow kept or a sign
## heeded lifts it higher. Each thaw luck drifts a point toward `luck_start` from above
## `luck_drift_high` or below `luck_drift_low`: what a year did not renew
## is forgotten. Burning men in their hall costs `luck_burning`.
var luck_crest := 7
## At the crest a plain win still lifts luck now and then: this chance at
## the crest, its square a point above, and so on.
var luck_crest_chance := 0.25
var luck_drift_high := 6
var luck_drift_low := 4
var luck_burning := 1
var fame_per_recruit := 20

# --- Drill (winter.gd, bridge.gd) ------------------------------------------
## Drill points at which a man knows a learned shape fully (the same as
## CombatRules.drill_points_full). A winter turn of DRILL in the band's
## chosen shape gives a point; standing in a shape through a fight gives
## one; a man who did not drill all winter loses `drill_decay` at the thaw.
var drill_points_full := 3
var drill_decay := 1

# --- Scouting (scouting.gd, fight_offer.gd) ---------------------------------
## The scout's count may be out by this either way at Wits 1, one less a
## point of wits, `scout_veteran_bonus` less for a seasoned scout.
var scout_error := 4
var scout_error_per_wits := 1
var scout_veteran_bonus := 1
## The scout names the enemy's leader from this many wits.
var scout_leader_wits := 3
## The chance the scout sees them before they see him, which makes an
## ambush possible: the base, plus this a point of wits above one, plus
## this for a seasoned scout.
var scout_first_chance := 0.15
var scout_first_per_wits := 0.05
var scout_first_veteran := 0.1
## The chance an enemy who comes for you on land has seen you first, so
## that you are the column: a feud's blades, a levy. Your scout's seeing
## them first forestalls it.
var caught_chance := 0.25
var recruits_min := 1
var birth_chance := 0.35
var daughter_chance := 0.5
var household_skill_max := 5
var son_names := [
	"Thorstein", "Ketil", "Hallbjorn", "Eyvind", "Sigurd", "Thorvald", "Bjorn", "Asgeir",
	"Ulf", "Hrafn", "Kolbein", "Orm", "Gunnar", "Hoskuld", "Steinar", "Vigfus",
]
var daughter_names := [
	"Thorgerd", "Asgerd", "Hallveig", "Gudrun", "Ragnhild", "Thordis", "Sigrid", "Helga",
	"Alfdis", "Vigdis", "Ingunn", "Thurid",
]
var heir_min_age := 15
var foster_returns_at_age := 16
var luck_inherit_fraction := 0.5
var luck_good_death := 1
var luck_shameful_death := 2
var fame_inherit_fraction := 0.5
var stay_threshold := 60
var feast_bonus_per_ounce := 0.5
var challenge_chance := 0.3
var death_lines := {
	"battle": "He fell with his face to the foe, and that was accounted a good death.",
	"old": "He died in his bed, old and honored, which is rarer in those days.",
	"outlaw": "He died an outlaw, and few mourned him.",
	"sickness": "A fever took him, and men said his luck had run out.",
	"oathbreaker": "He died with a broken oath on him, and his luck went into the mound with him.",
}
## Death causes that cost the heir luck_shameful_death.
var shameful_deaths := ["outlaw", "oathbreaker"]

# --- Generations (years.gd, family.gd, succession.gd: the played saga) ------
## Letting the years pass ("Then nothing is told of him for three winters"):
## the most years at once, and what a year at home costs and brings. A man
## at home costs his ale, his share and the small gifts that keep him
## (`years_upkeep_per_man` oz a year, on top of the winter's food); he
## brings in `years_food_per_man` rations from the hay, the nets and the
## hunt over the summer. A man who wants silver or fame sits ill at home
## (`years_idle_loyalty` a summer; the others `years_idle_loyalty_other`),
## and fame fades when nothing is told (`years_fame_fade` a year). A house
## at feud with the band comes against the hall in `years_attack_chance`
## of years for each level of the feud, and that stops the years.
var years_max := 10
var years_upkeep_per_man := 3
var years_food_per_man := 4
var years_idle_loyalty := 6
var years_idle_loyalty_other := 2
var years_fame_fade := 2
var years_attack_chance := 0.2
## The household: a son may be fostered out from `foster_min_age` to
## `foster_max_age` (he comes home at `foster_returns_at_age` with
## `foster_craft_bonus` in his foster-father's craft, the stat his house's
## temper favours); at `son_join_age` he joins the band, is named heir, or
## is left to the farm, and joins with `son_join_loyalty` and a bond of
## `son_join_bond` with his father. A daughter is of an age to marry at
## `daughter_marry_age`.
var foster_min_age := 12
var foster_max_age := 14
var foster_craft_bonus := 1
var son_join_age := 16
var son_join_loyalty := 80
var son_join_bond := 30
var daughter_marry_age := 15
## The craft a foster-father's house teaches, by its temper (CombatTypes.Stat).
var foster_crafts := {"proud": CombatTypes.Stat.NERVE, "grasping": CombatTypes.Stat.WITS,
	"peaceable": CombatTypes.Stat.WITS, "steadfast": CombatTypes.Stat.GRIT}
## Old age: from `step_down_age` a leader with a son of age may step down
## at the spring and sit by the fire as the old man of the hall, who dies
## in his bed in `old_man_death_chance` of winters.
var step_down_age := 48
var old_man_death_chance := 0.2
## The grave-ale, played: an open-handed feast is `grave_ale_open_per_man`
## oz a man (at least `grave_ale_open_min`) and is talked of
## (`grave_ale_open_fame`); a plain one is `grave_ale_ounces`; a mean one
## costs nothing and every man `grave_ale_mean_loyalty`, the heir
## `grave_ale_mean_honor` honor.
var grave_ale_open_per_man := 3
var grave_ale_open_min := 30
var grave_ale_open_fame := 3
var grave_ale_mean_loyalty := 6
var grave_ale_mean_honor := 3
## What a son brings to the high seat beyond what any heir carries: the
## family's luck (`heir_son_luck`), and the houses' regard for his father
## (the standing kept: `standing_inherit_son`, a second `standing_inherit_second`).
var heir_son_luck := 1
var standing_inherit_son := 0.75
var standing_inherit_second := 0.5
## A strong second disputes the high seat with an heir weaker than he is
## (by `challenge_stat_margin` stat points, or a better tier) when his bond
## with the heir is under `challenge_bond`; buying him off costs
## `challenge_buyoff_ounces`; winning the holmgang is worth
## `challenge_won_fame` fame.
var challenge_stat_margin := 2
var challenge_bond := 10
var challenge_buyoff_ounces := 30
var challenge_won_fame := 5
## The heir's honest ways to meet the challenge (docs/design/notes/
## balance.md): a champion of the band may stand for him on the island
## (honor -`challenge_champion_honor`: men say he would not stand
## himself); when `challenge_backing_share` of the men (his rival and his
## oath brothers not counted) hold loyalty `challenge_backing_loyalty` or
## more to a son of the blood, the challenger backs down before them
## (loyalty -`challenge_backed_down`); and the price of his goodwill is
## `challenge_buyoff_ounces` and `challenge_buyoff_per_tier` a tier,
## times `challenge_buyoff_ambition` for what he wants (a man who wants
## fame wants the seat itself).
var challenge_champion_honor := 5
var challenge_backing_loyalty := 60
var challenge_backing_share := 0.6
var challenge_backed_down := 10
var challenge_buyoff_per_tier := 10
var challenge_buyoff_ambition := {
	CampaignTypes.Ambition.SILVER: 0.7, CampaignTypes.Ambition.FAME: 2.0, CampaignTypes.Ambition.LAND: 1.2,
	CampaignTypes.Ambition.VENGEANCE: 1.0, CampaignTypes.Ambition.WIFE: 1.0, CampaignTypes.Ambition.HOME: 0.8,
}

# --- Campaign loop (Module I) -----------------------------------------------
var battles_per_summer := 3
var enemy_band_size := 8  # unused by the loop now; sizes track the band
var enemy_size_spread := 1
var enemy_size_min := 3
var enemy_weaker_chance := 0.3
var enemy_stronger_chance := 0.15
var plunder_per_win := 30
## On the map a fight pays what it was fought for (a raid's plunder, a
## lord's fee, a bounty); the flat win is only what the dead carried.
var plunder_per_win_world := 10
var ambition_per_win := 15
var vow_wins_needed := 2
var grave_ale_ounces := 20
var leader_start_bonus := 1
var recruit_cap := 16
## On the map the band's real ceiling is its benches and its thwarts
## (Campaign.room, docs/design/notes/balance.md): the most men it can keep
## is its hall's seats or its hull's crew, whichever is more, never under
## `room_min` (a lord's or a host's benches take that many) nor over
## `room_max` (a longship's crew). Men who would come beyond it are turned
## away; `recruit_cap` is the plain campaign's ceiling without a map.
var room_min := 8
var room_max := 40
## Below a hersir the ceiling is a snekkja's crew, whatever the benches:
## no hull a karl can buy carries more, and a great band is a lord's.
var room_max_karl := 24
var old_leader_death_chance := 0.15

# --- The winter hall, played (winter_hall.gd) --------------------------------
## The store: rations are bought this many at a time from the house the
## band winters at; a unit of grain in the hold feeds this many.
var hall_buy_lot := 5
var grain_rations := 5
## The ring-giving: what the leader can give a man, smallest first. First
## ounces of silver (the second is an arm-ring at `ring_gift_ounces`),
## then arms the man lacks, at these prices.
var hall_gift_ounces := [3, 8]
var arms_price := {"helmet": 12, "sword": 25, "mail": 45}
## Fine arms given in the hall bind a man this much more than the gear
## gift alone (`loyalty_gear_gift`).
var loyalty_arms_bonus := 5
## A man whose summer was great (a deed told of him, or `great_deed_kills`
## put down in the year) binds tighter for a gift that honours it, and
## takes it ill to be passed over.
var great_deed_kills := 3
var loyalty_deed_honoured := 5
var loyalty_passed_over := 10
## Open-handedness: given at least `open_hand_ounces` a man on average,
## the leader's name for it grows. A miser's hall: under `miser_ounces` a
## man while the chest holds `miser_chest` or more, every man cools and men
## say so.
var open_hand_ounces := 4
var fame_open_hand := 2
var honor_open_hand := 1
var miser_ounces := 1
var miser_chest := 20
## The benches judge by the chest (docs/design/notes/balance.md): no more is
## expected than `miser_chest_share` of what it holds (a thin chest is
## forgiven a thin Yule), and a man of great deeds does not take it ill to
## be given nothing from a chest under `miser_chest`.
var miser_chest_share := 0.1
var loyalty_miser := 6
var honor_miser := 2
## A man sent home for the winter does not eat at the band's board, cools
## a little, and comes back at the thaw if his loyalty is at least
## `sent_home_return_loyalty`, else with `sent_home_return_chance`.
var loyalty_sent_home := 4
var sent_home_return_loyalty := 40
var sent_home_return_chance := 0.5
## What a man who comes to the hall asks to swear, in ounces, by origin
## (a jarl's son wants a ring for it; most ask a seat and their keep).
var recruit_ask := {
	CampaignTypes.Origin.EXILED_JARLS_SON: 10,
	CampaignTypes.Origin.YOUNGER_SON: 3,
}
## The war-leader (stallari): when he leads the wall in the leader's
## place, only this share of the fame of the fight is the leader's.
var war_leader_fame_share := 0.5
## The hall's talk: between these many visitors and troubles a winter.
var hall_talk_min := 1
var hall_talk_max := 3
## A wise-woman sent for when sickness comes: her fee, and the turns of
## sickness she spares each man.
var wise_woman_fee := 4
var wise_woman_turns := 2
## A quarrel judged: the man found for gains, the man found against loses
## `judge_loyalty`; settled with silver both ways it costs
## `settle_quarrel_ounces` a man and warms both and their bond.
var judge_loyalty := 6
var settle_quarrel_ounces := 3
var settle_quarrel_loyalty := 3
var settle_quarrel_bond := 10
## Taking in an outlaw over the winter costs a law-abiding band honor.
var honor_outlaw_taken := 1
## A camp in the wilds: every man cools this much a turn, and the hunt
## brings in this much more a man.
var camp_cold_loyalty := 3
var camp_hunt_bonus := 1
## Timber and pitch to mend the ship after a winter storm, in ounces.
var storm_mend_ounces := 3
## Two of the band's men sent to the island over a quarrel: the turns of
## healing the loser takes away, and what it does to their bond.
var quarrel_island_turns := 2
var quarrel_island_bond := 15

# --- The saga's fights (docs/design/notes/saga-fights.md) -------------------
## A raid that has the field when the neighbours come but never stood in
## the hall (Objective.Kind.PLUNDER, not `taken`) carries off this share of
## what a raid that broke in carries.
var raid_late_share := 0.4
## A leader led from the front when he stood this many rounds with an enemy
## at arm's length (Warrior.contact_rounds) or struck a blow, or went down,
## in a fight his men came to blows in. Otherwise he hung back
## (Leader.on_battle): it costs luck and honor.
var front_contact_rounds := 2
## A hall burning over your head (WinterHall): holding and burning, the
## men this loyal or more stay in the fire with the leader; the rest are let
## out with the household.
var hold_burn_loyalty := 70
## A house's men who take a band's hall (Objective THE_HALL taken) carry
## off this share of its store.
var hall_plundered_food := 0.5

# --- Battles 2 (docs/design/notes/battles-2.md) --------------------------------
## The strandhogg fought (Campaign._strandhogg_fight): the herders by the
## farm when the band comes up from the boats, and the leader AI's greed
## (the share of the herd it waits for before it makes for the boats).
var strand_herders := 2
var strand_greed := 0.6
## The barred hall's hope (Campaign._hall_help): the friendliest house sends
## this many men, one more for every `hall_help_per` of standing over the
## friend's mark, at most `hall_help_max`.
var hall_help_men := 4
var hall_help_per := 10
var hall_help_max := 8
## A band of this many living men has a third named man for a wing.
var wing_third_band := 16
