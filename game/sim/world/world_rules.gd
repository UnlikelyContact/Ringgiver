class_name WorldRules
extends RefCounted
## Every tunable in the world layer, with defaults, sectioned by module.
## See world-architecture.md > Scales and time.

# --- Core -------------------------------------------------------------------
var summer_days := 200
var ship_crew := {
	WorldTypes.ShipKind.KARVE: 12, WorldTypes.ShipKind.SNEKKJA: 24,
	WorldTypes.ShipKind.LONGSHIP: 40, WorldTypes.ShipKind.KNARR: 10,
	WorldTypes.ShipKind.FAERING: 4,
}
var ship_cargo := {
	WorldTypes.ShipKind.KARVE: 6, WorldTypes.ShipKind.SNEKKJA: 10,
	WorldTypes.ShipKind.LONGSHIP: 14, WorldTypes.ShipKind.KNARR: 40,
	WorldTypes.ShipKind.FAERING: 2,
}
## What a hull costs at a hall or a town, in ounces; the old one is taken
## in part payment at `ship_trade_in` of its price.
var ship_price := {
	WorldTypes.ShipKind.FAERING: 15, WorldTypes.ShipKind.KARVE: 60, WorldTypes.ShipKind.KNARR: 110,
	WorldTypes.ShipKind.SNEKKJA: 170, WorldTypes.ShipKind.LONGSHIP: 320,
}
var ship_trade_in := 0.5
## Leagues a day under sail and oar; a band on foot makes `foot_speed`
## over easy ground, less in the hills (MapGrid.COST).
var ship_speed := {
	WorldTypes.ShipKind.FAERING: 5.0, WorldTypes.ShipKind.KARVE: 7.0, WorldTypes.ShipKind.KNARR: 6.0,
	WorldTypes.ShipKind.SNEKKJA: 8.0, WorldTypes.ShipKind.LONGSHIP: 8.0,
}
var foot_speed := 2.0
## The hands a hull needs at the oars before she will go anywhere.
var ship_min_crew := {
	WorldTypes.ShipKind.FAERING: 1, WorldTypes.ShipKind.KARVE: 4, WorldTypes.ShipKind.KNARR: 4,
	WorldTypes.ShipKind.SNEKKJA: 10, WorldTypes.ShipKind.LONGSHIP: 20,
}
var ship_unsailable_damage := 3
var alertness_decay_per_year := 2
var home_region: WorldTypes.Region = WorldTypes.Region.HORDALAND

# --- Voyages, knowledge, encounters (Module J) ------------------------------
var encounter_chance := 0.2
var open_sea_encounter_mult := 2.0
var storm_chance := 0.1
var storm_delay_days := 2
var storm_ship_damage := 1
var wreck_chance := 0.03
var wreck_damage := 3
var wreck_men_lost := 2
var rumor_radius_days := 8
var encounter_weights := {
	"rival_ship": 3, "merchant": 3, "outlaws": 2, "levy": 1, "storm": 2, "whale": 1,
}
var rival_crew := 8
var merchant_discount := 0.7
var merchant_cargo := 6
var outlaw_crew := 5
var outlaw_bounty := 15
var levy_crew := 14
var whale_food := 20
## Share of "whale" encounters that are a whale rather than a drifting wreck (text only).
var whale_not_wreck_chance := 0.5
var route_min_days := 6
var route_max_days := 14
## Each man in mail drowns with this chance in a wreck, beyond wreck_men_lost.
var wreck_mail_drown_chance := 0.5
## Region alertness per step of rival-crew tier (0-2 green, 3-5 blooded, ...).
var rival_alert_per_tier := 3
var merchant_crew := 6
var merchant_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var outlaw_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var levy_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED

# --- Market, trade, raiding (Module K) --------------------------------------
## Base price in ounces per unit.
var base_price := {
	WorldTypes.Good.FURS: 4, WorldTypes.Good.WALRUS_IVORY: 12, WorldTypes.Good.IRON: 3,
	WorldTypes.Good.SOAPSTONE: 2, WorldTypes.Good.AMBER: 8, WorldTypes.Good.FRANKISH_BLADES: 20,
	WorldTypes.Good.WINE: 6, WorldTypes.Good.SILK: 25, WorldTypes.Good.GRAIN: 1,
}
## Region -> {Good -> multiplier}; missing means 1.0. Sources are cheap, far markets dear.
var region_factor := {
	WorldTypes.Region.HALOGALAND: {WorldTypes.Good.FURS: 0.5, WorldTypes.Good.WALRUS_IVORY: 0.5, WorldTypes.Good.GRAIN: 2.0},
	WorldTypes.Region.BALTIC: {WorldTypes.Good.AMBER: 0.5, WorldTypes.Good.FURS: 1.5},
	WorldTypes.Region.DENMARK: {WorldTypes.Good.FURS: 2.0, WorldTypes.Good.WALRUS_IVORY: 2.0, WorldTypes.Good.AMBER: 1.5,
		WorldTypes.Good.FRANKISH_BLADES: 0.7, WorldTypes.Good.WINE: 0.7},
	WorldTypes.Region.WEST: {WorldTypes.Good.FURS: 1.8, WorldTypes.Good.WALRUS_IVORY: 1.8, WorldTypes.Good.WINE: 0.9},
	WorldTypes.Region.VIKEN: {WorldTypes.Good.IRON: 0.7, WorldTypes.Good.SOAPSTONE: 0.7},
	WorldTypes.Region.EAST: {WorldTypes.Good.SILK: 0.4, WorldTypes.Good.FURS: 2.5},
}
## What a market's middlemen take: a stranger buys this much over the
## price and sells this much under it. A trader's `trade_edge` gift cancels
## it (he deals at the price itself), so no round trip is ever free silver.
var market_spread := 0.1
var stock_baseline := 20
var price_floor := 0.5
var price_ceiling := 3.0
var price_rise_min := 1
var drift_fraction := 0.5
## Good -> regions that add supply each year.
var good_sources := {
	WorldTypes.Good.FURS: [WorldTypes.Region.HALOGALAND, WorldTypes.Region.BALTIC],
	WorldTypes.Good.WALRUS_IVORY: [WorldTypes.Region.HALOGALAND],
	WorldTypes.Good.IRON: [WorldTypes.Region.VIKEN, WorldTypes.Region.TRONDELAG],
	WorldTypes.Good.SOAPSTONE: [WorldTypes.Region.VIKEN, WorldTypes.Region.HORDALAND],
	WorldTypes.Good.AMBER: [WorldTypes.Region.BALTIC],
	WorldTypes.Good.FRANKISH_BLADES: [WorldTypes.Region.DENMARK],
	WorldTypes.Good.WINE: [WorldTypes.Region.DENMARK],
	WorldTypes.Good.SILK: [WorldTypes.Region.EAST, WorldTypes.Region.SWEDEN],
	WorldTypes.Good.GRAIN: [WorldTypes.Region.VIKEN, WorldTypes.Region.TRONDELAG, WorldTypes.Region.DENMARK],
}
var source_supply := 10
## Yearly source supply varies by +/- this many units.
var source_supply_spread := 3
## Cargo units a band with no ship can carry on its backs.
var no_ship_cargo := 2
var farm_food_price := 1
var captive_price := 15
var captive_glut := 0.1
var slave_markets := ["hedeby", "birka", "dublin"]
var defenders_base := {
	WorldTypes.PlaceKind.FARMSTEAD: 3, WorldTypes.PlaceKind.HALL: 8, WorldTypes.PlaceKind.TOWN: 12,
	WorldTypes.PlaceKind.THING_SITE: 6, WorldTypes.PlaceKind.FORT: 14, WorldTypes.PlaceKind.BAY: 0,
}
var defenders_per_alert := 1
## Defender tier by place defenses: >= [0] blooded, >= [1] veteran, >= [2] champion, else green.
var defender_tier_defenses := [3, 5, 8]
var plunder_fraction := 0.4
var plunder_spread := 0.1
var loot_fraction := 0.3
var captives_per_win := 2
var captives_spread := 1
var no_captives_defense := 6
var alert_per_raid := 2
var region_alert_per_raid := 1
var beacon_threshold := 6
var raid_feud_chance := 0.5
var strandhogg_food := 12
var strandhogg_silver := 5
var strandhogg_feud_chance := 0.25

# --- Factions, timeline, contracts (Module L) ------------------------------
var war_relation := -20
var conquest_chance := 0.35
var war_relation_hit := 30
var alliance_relation := 50
var marriage_chance := 0.2
var marriage_relation_gain := 15
var absorb_strength := 20
var raid_relation_hit := 25
## Share of a lost holding's men (loser strength / holdings) the conqueror gains.
var conquest_strength_gain := 0.5
## Each year an expander's relation toward weaker, unallied neighbours sours by this.
var expand_hostility := 5
## Chance per year that one of two allies turns on the other; relations fall by the hit.
var betrayal_chance := 0.02
var betrayal_relation_hit := 60
var contract_relation := 0
var contract_relation_gain := 10
var contract_fail_relation_hit := 10
var contract_pay := {"escort": 25, "hunt_outlaws": 20, "levy": 0, "debt": 15, "tribute": 40}
var contract_fame := {"escort": 2, "hunt_outlaws": 4, "levy": 8, "debt": 1, "tribute": 5}
## Days the work is expected to take (the offer's `days`).
var contract_days := {"escort": 12, "hunt_outlaws": 4, "levy": 20, "debt": 6, "tribute": 15}
var contract_pay_spread := 0.2
var contract_offers_max := 3
var contract_outlaws := 5
var contract_outlaw_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var contract_levy_men := 16
var contract_levy_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
var tribute_min_rank: WorldTypes.Rank = WorldTypes.Rank.HERSIR
var rank_progress_per_contract := 10
var rank_thresholds := {WorldTypes.Rank.HERSIR: 50, WorldTypes.Rank.JARL: 150, WorldTypes.Rank.KING: 400}
var harald_min_holdings := 8
## What the band gains or loses by siding with or against a spine event's faction.
var spine_serve_relation := 20
var spine_serve_fame := 3
var spine_serve_rank_progress := 15
var spine_oppose_relation := -30
var spine_battle_fame := 10
var spine_battle_rank_progress := 25
## The historical spine. See world-architecture.md, Module L. `faction` is whose
## event it is (whom "serve" serves); `effects` is the historical outcome, which
## happens on "ignore", on siding with the faction, on opposing it without a
## battle, and when the band opposes it in battle and loses. Effect keys:
## conquer (places to the faction), absorb (factions into it), leader
## ({faction: new leader}), relation ([[a, b, delta]]), ambition, open (place),
## flag (timeline_state key set true), on_defeat ("harald_falls"), battle
## ({attackers, tier}: siding with or opposing the faction is fought out).
var spine := [
	{"year": 866, "id": "harald_vow", "precondition": "harald_alive", "faction": "harald", "options": ["serve", "resist", "ignore"],
		"text": "Harald Halfdansson vows to neither cut nor comb his hair until all Norway is his.",
		"effects": {"ambition": "expand"}},
	{"year": 868, "id": "harald_takes_trondelag", "precondition": "harald_alive", "place": "lade", "faction": "harald", "options": ["serve", "resist", "ignore"],
		"text": "Harald marches north into Trøndelag; Hakon of Lade bends the knee and Lade is the king's.",
		"effects": {"conquer": ["lade"], "battle": {"attackers": 20, "tier": CombatTypes.Tier.BLOODED}}},
	{"year": 870, "id": "harald_takes_west", "precondition": "harald_alive", "place": "avaldsnes", "faction": "harald", "options": ["serve", "resist", "ignore"],
		"text": "Harald's ships come down the west coast and take the royal seat at Avaldsnes.",
		"effects": {"conquer": ["avaldsnes"], "battle": {"attackers": 24, "tier": CombatTypes.Tier.BLOODED}}},
	{"year": 872, "id": "hafrsfjord", "precondition": "harald_alive", "place": "hafrsfjord", "faction": "harald", "options": ["fight_for_harald", "fight_against", "ignore"],
		"text": "At Hafrsfjord the kings of the west meet Harald's fleet; the petty kingdoms fall to him.",
		"effects": {"absorb": ["rogaland", "hordaland", "agder"], "flag": "harald_line", "on_defeat": "harald_falls",
			"battle": {"attackers": 30, "tier": CombatTypes.Tier.VETERAN}}},
	{"year": 874, "id": "iceland_opens", "precondition": "always", "place": "iceland", "options": ["ignore"],
		"text": "Ingolf Arnarson takes land in Iceland; men who will not bow to kings follow him west.",
		"effects": {"open": "iceland"}},
	{"year": 875, "id": "orkney_earldom", "precondition": "always", "place": "orkney", "faction": "orkney", "options": ["serve", "ignore"],
		"text": "Orkney is made an earldom for Rognvald's kin; Sigurd the Mighty holds it.",
		"effects": {"leader": {"orkney": "Sigurd Eysteinsson"}, "relation": [["orkney", "more", 20], ["more", "orkney", 20]]}},
	{"year": 900, "id": "rollo_outlawed", "precondition": "harald_alive", "faction": "harald", "options": ["join_rollo", "ignore"],
		"text": "Harald outlaws Rollo, Rognvald's son, for a strandhögg in Viken; Rollo sails west into exile.",
		"effects": {}},
	{"year": 930, "id": "eric_bloodaxe", "precondition": "harald_line", "faction": "harald", "options": ["back_eric", "betray_eric", "ignore"],
		"text": "Eric Bloodaxe takes his father's high seat and kills his brothers for it.",
		"effects": {"leader": {"harald": "Eric Bloodaxe"}}},
	{"year": 934, "id": "haakon_the_good", "precondition": "harald_line", "place": "frostathing", "faction": "harald", "options": ["acclaim", "ignore"],
		"text": "Haakon, Athelstan's foster-son, is acclaimed king at the Frostathing; Eric flees west.",
		"effects": {"leader": {"harald": "Haakon the Good"}}},
]
var spine_fallback := {"id": "rival_bid", "text": "With Harald gone, a rival jarl takes up the bid for a single crown."}
## Options that side with the event's faction, and those that oppose it.
var spine_side_with := ["serve", "fight_for_harald", "back_eric", "acclaim"]
var spine_oppose := ["resist", "fight_against", "betray_eric", "join_rollo"]
## Options that are fought out when the event has a battle.
var spine_battle_options := ["resist", "fight_for_harald", "fight_against"]

# --- Law: the Thing, feuds, outlawry (Module M) -----------------------------
var fame_per_supporter := 15
var ounces_per_supporter := 10
var faction_support_relation := 30
var their_supporters_base := 3
var procedure_difficulty := {WorldTypes.CaseKind.KILLING: 10, WorldTypes.CaseKind.RAID: 9, WorldTypes.CaseKind.LAND: 11, WorldTypes.CaseKind.INSULT: 8}
var procedure_slip_target := 0.28
var lawman_fee := 10
var arms_weight := 0.5
var standoff_margin := 2
var violence_chance := 0.3
var thing_violence_honor := 15
var lesser_outlawry_years := 3
var full_outlawry_ratio := 2.0
var wergild_by_rank := {WorldTypes.Rank.THRALL: 5, WorldTypes.Rank.FREEDMAN: 15, WorldTypes.Rank.KARL: 40,
	WorldTypes.Rank.HERSIR: 100, WorldTypes.Rank.JARL: 250, WorldTypes.Rank.KING: 600}
var ambush_chance := 0.15
var demand_chance := 0.3
var hired_blades := 4
var feud_level_wergild_mult := [1.0, 1.0, 1.5, 2.0]
var feud_refusal_honor := 5
var bounty_chance := 0.25
var bounty_crew := 6
## Place wealth per supporter the family brings to the Thing.
var family_standing := 15
## The family's supporters vary by up to this many either way.
var their_supporters_spread := 2
## Armed men the family brings to the Thing (its household).
var family_armed_men := 6
## The plaintiff's weight must reach this multiple of the defendant's to win.
var win_ratio := 1.1
## Killings at or above this ratio (below full_outlawry_ratio) bring lesser outlawry;
## raids and land cases at full_outlawry_ratio or more bring lesser outlawry.
var lesser_outlawry_ratio := 1.5
## A man with this trait may argue the band's procedure.
var law_wise_trait := "law-wise"
var thing_brawl_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
## Men in a feud ambush before hired blades.
var feud_ambush_men := 6
var feud_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
var bounty_tier: CombatTypes.Tier = CombatTypes.Tier.VETERAN
## Rank of the dead man when a feud or case does not name one.
var default_victim_rank: WorldTypes.Rank = WorldTypes.Rank.KARL

# --- Sandbox loop (Module N) ------------------------------------------------
var raids_per_summer_max := 4
var home_by_day := 185
var home_margin_days := 10
var start_land := 1
var raid_min_wealth := 15
var raid_avoid_relation := 0
var raid_odds_max := 1.2
## How strongly the planner favours soft targets: score is scaled by
## 1 + (our mean stat - their stat centre) * this, clamped 0.2-2.
var raid_softness_weight := 0.4
## Fights the band did not choose (sea fights, ambushes, levies) are capped at
## the band's size plus this, so a small band is not simply crushed by data.
var forced_fight_max_extra := 2
## Enemy stat centres (1-10) by what the band is fighting: the world has its
## own strength, and the player picks his fights. Farm defenders are farmers.
var defender_stat_by_kind := {
	WorldTypes.PlaceKind.FARMSTEAD: 2, WorldTypes.PlaceKind.HALL: 4, WorldTypes.PlaceKind.TOWN: 4,
	WorldTypes.PlaceKind.THING_SITE: 3, WorldTypes.PlaceKind.FORT: 5, WorldTypes.PlaceKind.BAY: 2,
}
var defender_stat_per_defense := 0.34
var sea_fight_stat := 3
var levy_stat := 4
var spine_stat := 3
var feud_stat_base := 3
var raid_days := 3
var trade_min_silver := 30
var trade_spend_fraction := 0.6
var market_days := 2
var idle_days := 5
var idle_turns_before_roving := 2
var settle_if_fraction := 0.5
## The Thing: sue when the band can spend this much, and spend this share.
var thing_min_silver := 20
var thing_spend_fraction := 0.3
var thing_spend_max := 50
var thing_days := 6
## Iceland: emigrate when fully outlawed, or when Harald rules the home and
## the band's relation with him is below this; the land-take claims this much.
var emigrate_relation := -20
var iceland_land_claim := 3
var land_food_per_unit := 10
var land_silver_per_unit := 5
var pass_years_interrupts := ["feud_attack", "summons", "spine", "son_of_age", "vow_due"]

# --- Ways of life (callings.gd, journey.gd, way.gd) --------------------------
## Counsel: the leader's Wits + 2d6 + his `law` gift against this; a Thing
## site is harder by `counsel_thing_harder` and pays double. Success: the
## fee (`counsel_fee` + the place's wealth over `counsel_wealth_per_oz`,
## times his `counsel_fee` gift), honor, the lord's goodwill and the
## family's standing (Families: `standing_counsel`, and the loser of the
## dispute `standing_counsel_loser`).
## A miss by `counsel_bad_miss` or more costs honor. Once a year a place.
## A place has a dispute worth a stranger's counsel in this share of years
## (a Thing site always has cases).
var counsel_dispute_chance := 0.35
var counsel_difficulty := 11
var counsel_thing_harder := 1
var counsel_fee := 8
var counsel_wealth_per_oz := 10
var counsel_honor := 2
var counsel_relation := 3
var counsel_bad_miss := 4
var counsel_bad_honor := 1
var counsel_days := 3
## A verse before a lord: Wits + 2d6 + fame over `verse_fame_per_point` +
## the `verse` gift against this. Success: a ring worth `verse_ring` + the
## hall's wealth over `verse_wealth_per_oz` (times the `verse_gift` gift),
## fame and the lord's goodwill. A bad miss costs fame. Once a year a hall.
## A lord who has heard a man's praise before is harder to please by
## `verse_heard_harder` for each time: a skald must find new halls.
var verse_difficulty := 11
var verse_heard_harder := 2
var verse_fame_per_point := 25
var verse_ring := 6
var verse_wealth_per_oz := 10
var verse_fame := 1
var verse_relation := 6
var verse_bad_miss := 4
var verse_days := 2
## Holmgang: the stake is this share of the place's wealth (a hall's
## champion fights for less of more). A challenge without a feud behind it
## is overbearing and costs honor; with one, a win settles the feud. A man
## may pay half the stake rather than fight a challenger with `dread`.
## The loser pays `holmgang_ransom` to leave the island alive.
## A man beaten for his goods without cause may take up a feud for it.
var holmgang_stake := {WorldTypes.PlaceKind.FARMSTEAD: 0.5, WorldTypes.PlaceKind.HALL: 0.3}
var holmgang_honor := 3
var holmgang_feud_chance := 0.3
## An overbearing challenge from a man whose honor is already this low is
## more than the district will bear: he is outlawed for a time.
var holmgang_outlaw_honor := 15
var holmgang_win_fame := 2
var holmgang_ransom := 12
var holmgang_days := 2
var holmgang_relation_hit := 8
## Deeds counted toward a way (Way.add_deed).
var deed_raid := 3
var deed_strandhogg := 1
var deed_rob := 2
var deed_contract := 2
var deed_case := 3
var deed_counsel := 2
var deed_settle := 1
var deed_duel := 3
var deed_duel_yielded := 2
var deed_verse := 2
## A trader's deed for every so many ounces of margin on goods he bought.
var deed_trade_margin := 10
## What the wait costs when a man listens for rumours instead of acting.
var listen_days := 5
## A place plundered or taxed by the sword mends this share of the way back
## to what it was worth, each year.
var wealth_mend := 0.34
## A lord has one piece of work for a man in a year.
var work_per_hall := 1
## A bully: in this share of years a berserk has called a farmer out for
## his land, and a man may stand in the farmer's place. He fights a
## seasoned berserk; a win is worth `champion_fee` + the farm's wealth over
## `champion_wealth_per_oz`, honor, fame and the family's friendship.
var bully_chance := 0.25
var champion_fee := 10
var champion_wealth_per_oz := 4
var champion_honor := 4
var champion_fame := 3
var deed_champion := 2
## A man knows the places within this many leagues of where his saga
## begins, and comes to know any place he passes within `sight_leagues` of.
var known_leagues_start := 14.0
var sight_leagues := 8.0

# --- The free-roam map (roam.gd, map_grid.gd) ------------------------------------
## Who else is abroad each summer: merchants plying between the markets,
## raiders prowling the coast, outlaws on the land near the farms, and the
## levy ships that hunt an outlawed man.
var roam_merchants := 4
var roam_raiders := 3
var roam_outlaws := 4
var roam_levy := 2
## Leagues a day: a merchant's knarr, a raider's ship, outlaws on foot.
var merchant_speed := 6.0
var raider_speed := 7.5
var outlaw_speed := 2.2
## Raiders and outlaws go for a band they see within these leagues when
## they like the odds (their men at least the band's); a band they have
## fought, been outrun by or traded with is left alone for `party_rest_days`.
var raider_sight := 7.0
var outlaw_sight := 5.0
var party_rest_days := 15.0
## Two parties meet when they come this near, in leagues.
var contact_leagues := 0.9
## At sea: the chance of a storm in a day's sailing, and of foundering in
## a day on the deep. A hull hurt as badly as `ship_unsailable_damage`
## only limps (`ship_limp_speed`).
var storm_chance_day := 0.03
var wreck_chance_deep_day := 0.006
var ship_limp_speed := 2.0
## Passage on another man's ship, for a band without one of its own: this
## much, and this much more a man for each day of the voyage.
var passage_base := 2
var passage_per_man_day := 0.5
## A guest's lodging for the winter, an ounce a man, where a band has no
## hall of its own.
var guest_winter_per_man := 1
## Days the crew needs to mend one point of the ship's damage on a beach.
var ship_mend_days := 4

# --- Families: the houses, their ties and the band's standing (families.gd) ---
## The band's standing with a house runs from -100 to 100 and is read in
## steps: at or under `standing_blood_enemy` a blood-enemy, at or under
## `standing_ill_wisher` an ill-wisher, under `standing_well_wisher` a
## stranger, then a well-wisher, at `standing_friend` a friend and at
## `standing_sworn` a sworn friend (kin, when the band is tied to the house
## by blood or marriage).
var standing_blood_enemy := -60
var standing_ill_wisher := -20
var standing_well_wisher := 20
var standing_friend := 50
var standing_sworn := 80
## A change in standing with one house moves its tied houses by this share
## of it, one step out along the web: friends and kin the same way, its
## enemies the other way. A pair of houses can have several ties; the
## shares add.
var tie_spread := {"kin": 0.5, "marriage": 0.4, "friend": 0.4, "foster": 0.3, "debt": 0.15, "grudge": -0.2, "feud": -0.4}
## What deeds do to the standing of the house concerned.
var standing_counsel := 15
## The house that loses a judgment resents the judge a little.
var standing_counsel_loser := -5
var standing_verse := 8
var standing_champion := 20
var standing_holmgang_overbearing := -20
var standing_holmgang_lost_to := -8
var standing_raid := -35
var standing_strandhogg := -15
## Trading at a house's market: a little each visit, while the standing is
## under `standing_trade_cap` (repeat custom makes a well-wisher, no more).
var standing_trade := 3
var standing_trade_cap := 30
var standing_contract := 10
## Work that takes from a house (a debt collected, tribute gathered there).
var standing_contract_against := -10
var standing_case_against := -15
var standing_case_for := 20
## Each of a house's men killed in a fight.
var standing_per_kill := -6
## A house whose men were killed by a band it has no feud with takes one up
## in this share of fights.
var kill_feud_chance := 0.5
## A feud between the band and a house that is settled, by silver, the
## Thing or the island, lifts the standing by this much.
var standing_settled := 15
## An open feud with the band holds the house's standing at or under this.
var standing_feud_cap := -25
var standing_marriage := 30
var standing_foster := 20
var standing_refused := -5
var standing_help_won := 25
var standing_help_against := -25
var standing_pledge_broken := -10
## A gift of `gift_ounces` at a house's seat: `standing_gift`, halved for
## every gift given that house this year already (the ring-giver's verb,
## with diminishing returns).
var gift_ounces := 10
var standing_gift := 12
## Days a deed among the families takes: a gift, asking for men, a rest.
var gift_days := 1
## Standing a house gives for the band at the Thing: a well-wisher brings
## this many supporters, a friend more, a sworn friend or kin the most.
var house_support := {"well-wisher": 1, "friend": 2, "sworn": 3}
## The other side's tied houses bring this many each, unless the band is
## their friend (they stay home); a debtor never stands against its
## creditor. A house at feud with the other side stands with the band if
## the band is no ill-wisher of it.
var ally_support := 2
var enemy_of_enemy_support := 2
## Prices at a house's market: a friend lets the band off this much of the
## middlemen's spread (all of it: the true price, as a trader deals); an
## ill-wisher asks `foe_price` times the price and pays its inverse.
var friend_spread_off := 0.1
var foe_price := 1.2
## Shelter, healing and men at a house's seat: a friend gives winter
## lodging free; an ill-wisher shuts the door. A well-wisher or better lets
## the hurt rest (`heal_days`, `heal_turns` of mending, once a year), and a
## friend lends men (`men_lent` by step, once a year).
var heal_days := 4
var heal_turns := 2
var men_lent := {"friend": 1, "sworn": 2}
## Work is not offered at the seat of an ill-wisher.
## A house's war-party on the map leaves a well-wisher alone and hunts a
## blood-enemy whatever the odds. A house at feud with the band sends
## `avenger_men` after it in `avenger_chance` of summers, at most
## `avengers_max` parties.
var avenger_men := 6
var avengers_max := 1
var avenger_chance := 0.5
var avenger_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
## The reckoning: at the seat of the house the band is at feud with, every
## friend of the band among that house's enemies sends this many men, and
## the house brings its strength less theirs.
var friend_men_sent := 3
var reckoning_fame := 5
## What the friends who sent men think of the band after: won, the better;
## lost, the worse.
var standing_reckoning_won := 10
var standing_reckoning_lost := -5
## The world without the band: each year an open feud between houses climbs
## a step in `feud_climb_chance` (plus the tempers of both houses) or
## cools; a grudge breaks into a killing in `grudge_to_feud`; a new grudge
## comes up between neighbours in `new_grudge_chance`; houses marry in
## `house_marriage_chance`; a head dies in `head_death_chance` (more past
## `head_old_age`). At most `tidings_max` tidings a year.
var feud_climb_chance := 0.35
var temper_climb := {"proud": 0.15, "grasping": 0.1, "peaceable": -0.15, "steadfast": -0.05}
var feud_cool_chance := 0.15
var grudge_to_feud := 0.25
var grudge_fade_chance := 0.1
var new_grudge_chance := 0.5
var house_marriage_chance := 0.4
var head_death_chance := 0.04
var head_old_age := 60
var head_old_death_chance := 0.12
## At most this many heads die in a year (the rest live on to the next).
var deaths_max := 2
var tidings_max := 6
## Feud steps between houses, in order. A settlement made at the Thing
## holds in `settlement_hold_chance` of years (plus tempers, the other
## way); one that breaks goes back to killing, and a feud that climbs past
## a second break ends in a burning.
var house_feud_steps: Array[String] = ["an insult", "a killing", "a counter-killing", "a case at the Thing", "a settlement", "a burning"]
var settlement_hold_chance := 0.6
var burning_strength_loss := 0.5
var burning_honor := 10
var feud_honor_loss := 3
## Asked by the houses: at most `asks_per_summer` in a spring, each in
## `ask_chance`, only from houses whose seat the band knows and whose
## standing is no worse than stranger.
var asks_per_summer := 2
var ask_chance := 0.6
## Carrying an offer of settlement between two houses: the leader's Wits +
## 2d6 against this.
var peace_difficulty := 11
var peace_honor := 2
## Men a house sends against its enemy when the band stands with the other.
var house_fight_men := 6
var house_fight_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
var house_fight_stat := 3
## Wergild offered to the band for its dead: the house pays
## `compensation_share` of the dead man's wergild; taking blood instead is fought, and a win ends
## the feud and is spoken of.
var compensation_share := 0.75
var compensation_fame := 3
var blood_fame := 5
## The origins' standing at the start (Origins key -> {place id: standing}):
## the burned hall's kin in Sogn and the burners at Hardanger; the younger
## son's own family; the freedman's old master.
var origin_standing := {
	"burned_hall": {"sogn_farms": 60, "hardanger": -80},
	"younger_son": {"hardanger": 60},
	"freedman": {"fitjar": 10},
}
## Origins' ties to a house by place id: kin by blood.
var origin_kin := {"burned_hall": ["sogn_farms"], "younger_son": ["hardanger"]}
