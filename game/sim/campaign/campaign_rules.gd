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
var growth_pool_per_point := 10
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
var drill_effort := 3
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
var marriage_houses := ["the Ladejarl's kin", "a rich bondi of Vik", "the Hordaland jarl's house"]
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
var omen_chance := 0.3
var luck_high := 7
var luck_low := 3
var fame_per_recruit := 20
var recruits_min := 1
var birth_chance := 0.35
var daughter_chance := 0.5
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
}

# --- Campaign loop (Module I) -----------------------------------------------
var battles_per_summer := 3
var enemy_band_size := 8
var plunder_per_win := 30
