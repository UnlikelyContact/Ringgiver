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
## A longship (forty at her oars, the band's ceiling: Campaign.room) is
## built only for a man of this rank or better: a great band is a lord's,
## not a pedlar's (docs/design/notes/balance.md).
var longship_rank := WorldTypes.Rank.HERSIR
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
var captive_glut := 0.15
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
## Fame a lord's work brings (halved, 12 Nov 2026: the king's man reached
## fame 100 in four years; his road is service and rank, not renown).
var contract_fame := {"escort": 1, "hunt_outlaws": 2, "levy": 4, "debt": 0, "tribute": 2}
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
	{"year": 874, "id": "iceland_opens", "precondition": "always", "place": "iceland", "options": ["sail_iceland", "send_settlers", "ignore"],
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
	{"year": 930, "id": "althing", "precondition": "always", "place": "iceland", "options": ["hear"],
		"text": "The Icelanders set up the Althing at Thingvellir: one law for all the land, and a lawspeaker to say it.",
		"effects": {"flag": "althing"}},
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
## Days the band rests under a roof to mend a turn of its wounds (the
## "Rest and mend" deed, where there are hurt men): a bruise is gone, a
## wound is half healed, a man carried off the field needs four.
var rest_days := 6
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
## Memory fades at the extremes (docs/design/notes/balance.md): each year
## a house's regard above `standing_fade_from` (or below its negative)
## moves `standing_fade` of the way back toward it, so a friend stays a
## friend and a foe a foe but nobody is pinned at the end of the scale
## and a deed there still counts.
var standing_fade_from := 60
var standing_fade := 0.2
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

# --- Winter quarters (Journey winter, winter_hall.gd) -------------------------
## A lord's hall takes the band in as his men for the winter, lodging and
## board, when his realm thinks this well of it (FactionAI.relation).
var lords_hall_relation := 40
## The king's man's road to his vengeance (docs/design/notes/balance.md):
## a jarl or better whom a king thinks `king_justice_relation` of may ask
## him for justice against the house he has his vengeance on, at one of
## the king's halls once a summer. The king summons them and makes them
## pay `king_justice_ounces` (the king keeps `king_justice_share`); the
## feud is ended, and the favour is spent (`king_justice_cost` regard).
var king_justice_relation := 60
var king_justice_rank := WorldTypes.Rank.JARL
var king_justice_ounces := 60
var king_justice_share := 0.5
var king_justice_cost := 15
var king_justice_days := 10
## At the thaw the band may go this many days by land to begin its summer
## somewhere else; its ship, if it has one with it, stays where it lay.
var spring_days := 6

# --- The world alive in summer (world_life.gd, roam.gd) ----------------------------
## The others abroad live their own summer: raiders fall on merchants and
## on farms, the king's ships hunt raiders and outlaws, houses at feud send
## their men against each other. All of it is reckoned every
## `life_tick_days` of the summer's clock, cheaply: no battle is fought, a
## clash is a strength roll.
var life_tick_days := 0.5
## The king's ships abroad each summer (they hunt raiders and outlaws, and
## ask a band passing through the king's waters for passage money).
var roam_kings_ships := 2
var kings_crew := 12
var kings_tier: CombatTypes.Tier = CombatTypes.Tier.BLOODED
var kings_speed := 7.0
## A hunter (raiders after a merchant, the king's ships after raiders,
## a house's men after its enemy's) goes for prey it sees within these
## leagues, and two parties close enough fall to fighting.
var hunt_sight := 6.0
var clash_leagues := 1.0
## A fight between two parties lasts this many days before it is decided,
## and a band that comes within `contact_leagues` of it in that time may
## take a side. What is left of it (a wreck, loot, survivors) lies where
## it was fought for `wreck_days`.
var clash_days := 1.0
var wreck_days := 12.0
## A party's strength in a clash: its men times this by tier (green,
## blooded, veteran, champion), times a roll of `clash_luck` either way.
var clash_tier_weight := [1.0, 1.3, 1.7, 2.2]
var clash_luck := 0.3
## The beaten side loses this share of its men if it gets away (it gets
## away when its strength was at least `clash_flee_ratio` of the
## winner's); the winner loses `clash_winner_loss` of the beaten side's
## strength in men.
var clash_loser_loss := 0.5
var clash_flee_ratio := 0.6
var clash_winner_loss := 0.3
## Raiders on the farms: a raider ship strikes at a farm or a hamlet near
## its course in this share of days, if one lies within `strike_leagues`;
## the raid lasts `place_raid_days`, and a band at the place (or coming to
## it) may stand with the farmers. The farm's own defenders fight as men
## of `place_defender_tier`. A farm the raiders have plundered loses
## `raided_wealth_share` of its wealth (it mends as any raided place) and
## is not struck again for `raided_rest_days`.
var strike_chance_day := 0.08
var strike_leagues := 10.0
var place_raid_days := 1.5
var place_defender_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var raided_wealth_share := 0.35
var raided_rest_days := 60.0
## Driving the raiders off a house's farm: the house's standing rises by
## this, and the farmers give `defend_fee` oz and their thanks.
var standing_defended := 20
var defend_fee := 8
## A party the band helps in a fight it came upon: the merchant pays this
## share of his cargo's worth; standing with a house whose men were helped.
var rescue_share := 0.25
var standing_rescued := 15
## Houses at feud send men against each other in summer: at most this many
## parties, each of `house_party_men` (the house's strength allowing). A
## clash between them is a killing on the feud's ledger (Families.kill).
var house_parties_max := 2
var house_party_men := 6
var house_party_chance := 0.6
## Tidings: a clash within `hear_leagues` of the band is heard at once;
## the rest is told at the next hall, town or market it comes to, at most
## `news_per_place` at a time and only what happened in the last
## `news_days` days.
var hear_leagues := 10.0
var news_per_place := 2
var news_days := 40.0
## The king's ships ask a band they hail of this much a man for passage
## through the king's waters (not of his sworn men, nor of an outlaw: they
## fight an outlaw). Refusing is a fight in `toll_refused_fight` of
## hailings, else it costs the king's goodwill.
var toll_per_man := 1
var toll_min := 3
var toll_refused_fight := 0.5
var toll_refused_relation := 10
## Escorting a merchant for pay: he pays `escort_pay_base` and this much a
## day of the way, if the band brings him there within the days he gives
## (the way's days times `escort_slack`, and a few).
var escort_pay_base := 6
var escort_pay_day := 1.5
var escort_slack := 1.8
## A beached ship in hostile country (an ill-wisher's land, or raiders or
## outlaws within `ship_thief_sight` leagues of her) is taken in this share
## of days she lies unguarded. At a well-wisher's place, or one where the
## band has paid `ship_watch_ounces` for a watch, she is safe. The thieves
## sail her to their home; she is there to be taken back until the summer
## ends.
var ship_theft_day := 0.04
var ship_theft_day_near := 0.12
var ship_thief_sight := 8.0
var ship_watch_ounces := 2
var ship_thieves_men := 5

# --- The trader's road (trade_road.gd, market.gd) ------------------------------------
## Farms and halls without a market still deal in what they make and what
## they lack (place id -> {Good: "sells" | "buys"}): a small stall with
## `local_stock` units at the baseline, what it makes cheap
## (`local_sell_factor` of the price) and what it lacks dear
## (`local_buy_factor`). The stall mends toward its baseline by
## `local_mend_day` units a day, so a difference lasts long enough to walk
## a load across it, and no faster.
var local_trade := {
	"hardanger": {WorldTypes.Good.IRON: "sells", WorldTypes.Good.FURS: "buys"},
	"sogn_farms": {WorldTypes.Good.FURS: "sells", WorldTypes.Good.IRON: "buys"},
	"fitjar": {WorldTypes.Good.SOAPSTONE: "sells", WorldTypes.Good.FURS: "buys", WorldTypes.Good.WINE: "buys"},
	"sogn_hall": {WorldTypes.Good.IRON: "sells", WorldTypes.Good.SOAPSTONE: "buys"},
	"more_farms": {WorldTypes.Good.SOAPSTONE: "sells", WorldTypes.Good.IRON: "buys"},
	"giske": {WorldTypes.Good.FURS: "buys", WorldTypes.Good.WINE: "buys"},
	"avaldsnes": {WorldTypes.Good.WINE: "buys", WorldTypes.Good.IRON: "buys"},
	"agder_farms": {WorldTypes.Good.IRON: "sells", WorldTypes.Good.SOAPSTONE: "buys"},
	"lier": {WorldTypes.Good.IRON: "sells", WorldTypes.Good.FURS: "buys"},
	"trondelag_farms": {WorldTypes.Good.FURS: "sells", WorldTypes.Good.IRON: "buys"},
	"halogaland_farms": {WorldTypes.Good.WALRUS_IVORY: "sells", WorldTypes.Good.IRON: "buys"},
	"orkney": {WorldTypes.Good.SOAPSTONE: "buys", WorldTypes.Good.FURS: "buys"},
}
var local_stock := 10
var local_sell_factor := 0.5
var local_buy_factor := 2.2
var local_mend_day := 0.3
## What a band on foot carries: `no_ship_cargo` for the leader, and a load
## more for each man with him. A band with a ship carries its hold, or its
## men's loads if they come to more.
var load_per_man := 1
## Passage on another man's ship takes the band's loads too, at this much
## a load.
var passage_per_load := 1
## A félag: a man at a market or a hall gives the band his goods to carry
## and sell elsewhere for a share (`felag_share` of what they fetch). At
## most `felag_units` loads, one partnership a place a year; goods not sold
## by the summer's end cost his house `standing_felag_broken`, sold they
## bring `standing_felag_kept`.
var felag_share := 0.4
var felag_units := 4
var standing_felag_kept := 6
var standing_felag_broken := -10
## A man's first livings, each once a place a year (fishing `fish_max`
## times): labour on a farm (`labour_days`, `labour_pay` and a little for
## each man, rations), herding the summer pastures (`herd_days`, pay,
## rations, and the uplands about it come to be known), fishing from a farm
## on the shore, and a place at another man's oars for a share
## (`crew_pay_day` for each man, for a voyage of up to `crew_max_days`, at
## most `crew_max_men` hands taken).
var labour_days := 6
var labour_pay := 3
var labour_pay_man := 1
var labour_food := 6
var herd_days := 12
var herd_pay := 5
var herd_food := 8
var herd_reveal_leagues := 12.0
var fish_days := 4
var fish_food := 10
var fish_pay := 2
var fish_max := 2
var standing_labour := 4
var crew_pay_day := 0.7
var crew_max_days := 14
var crew_max_men := 4

# --- Men in summer (hiring.gd) ---------------------------------------------------------
## Men for hire at halls, towns and markets (`hire_offers` of them, fewer
## at a farm), rolled once a visit: each has a price to join and a wage
## every `wage_days`. A man not paid loses `unpaid_loyalty`; a man whose
## loyalty is under CampaignRules.loyalty_leave_below takes his leave at
## the next place the band comes to; one whose loyalty is at
## `hire_swear_loyalty` at the summer's end swears himself to the band and
## takes no more wage. Men lent by a house go home at the summer's end, or
## at once if the house turns against the band.
var hire_offers := 3
var hire_offers_farm := 1
var wage_days := 30.0
var unpaid_loyalty := 15
var hire_swear_loyalty := 50
## The kinds of men for hire: key -> {text, tier, price, wage, loyalty,
## bias (stat bonuses: might, skill, grit, nerve, wits), honor (what taking
## him costs), weight (how often he is about)}.
var hire_kinds := {
	"farmers_son": {"text": "a farmer's son who wants to see more than his father's fields", "tier": CombatTypes.Tier.GREEN,
		"price": 4, "wage": 1, "loyalty": 55, "bias": [0, 0, 0, 0, 0], "honor": 0, "weight": 4},
	"fisher": {"text": "a fisherman's lad, good at an oar", "tier": CombatTypes.Tier.GREEN,
		"price": 3, "wage": 1, "loyalty": 50, "bias": [0, 0, 1, 0, 0], "honor": 0, "weight": 2},
	"outlaw": {"text": "an outlaw from the uplands who asks no questions and answers none", "tier": CombatTypes.Tier.BLOODED,
		"price": 3, "wage": 1, "loyalty": 30, "bias": [1, 0, 0, 0, 0], "honor": 2, "weight": 2},
	"shipless": {"text": "a Dane who lost his ship and his lord in the same storm", "tier": CombatTypes.Tier.BLOODED,
		"price": 9, "wage": 2, "loyalty": 45, "bias": [0, 1, 0, 0, 0], "honor": 0, "weight": 2},
	"berserk": {"text": "a berserk of ill fame, whom the farmers are glad to see go", "tier": CombatTypes.Tier.BLOODED,
		"price": 12, "wage": 3, "loyalty": 35, "bias": [2, 0, 0, 2, -1], "honor": 3, "weight": 1},
	"old_hand": {"text": "an old hand who has stood in a king's wall", "tier": CombatTypes.Tier.VETERAN,
		"price": 20, "wage": 3, "loyalty": 50, "bias": [0, 1, 1, 0, 0], "honor": 0, "weight": 1},
}
## Captives: ransomed at a hall or a town for this much a head by their
## kin, or freed for honor (a point a head, at most `free_honor_max`).
var captive_ransom := 7
var free_honor_max := 3

# --- The vengeance (families.gd, journey.gd) -----------------------------------------
## The burners stand with their allies: each house allied to them sends
## `ally_men_sent` to a reckoning. They offer wergild for the burning, and
## answer it at the Thing, only once the band's backing (its own men and
## the men its friends among their enemies would send) is this share of
## their strength with their allies'.
var ally_men_sent := 3
var vengeance_backing_ratio := 0.8
## The wergild the burners offer, once they must, is this many times the
## dead man's: they pay dearly or not at all.
var vengeance_wergild_mult := 1.5
## The burners' men in the field (a reckoning at their seat, blood taken
## for silver refused) fight at this stat centre: the jarl's picked men,
## not the farmers of the place.
var vengeance_stat := 5
## A house abroad (outside Norway's own regions) does not offer marriage or
## fostering, and is not brought to a reckoning as a Norse house is.

# --- The saga's fights (docs/design/notes/saga-fights.md) --------------------
## The burning of a house in its hall by the band (Families.burned): the
## band's honor lost, unless that house had burned the band's own first
## (the one burning the sagas half forgive: `burning_avenged_honor` then);
## the standing lost with every house tied to the burned one; the chance
## the burned house's kin and friends get the band outlawed at the Thing;
## the fame of it either way (it is talked of).
var burning_band_honor := 20
var burning_avenged_honor := 3
var burning_ally_standing := -25
var burning_outlaw_chance := 0.5
var burning_fame := 4
## A feud's ambush beaten off cools the feud a step; one that took the band's
## men warms it a step (the feud's `level`, 1 to 3). Every man killed either
## way is on the feud's ledger (`kills_ours`, `kills_theirs`).
var feud_ambush_cools := 1
## A brawl at the Thing won: the other side's case loses footing, and the
## band's standing with them rises this much (they have seen it fight);
## lost, it falls this much and the feud rises a step.
var thing_brawl_won_standing := 5
var thing_brawl_lost_standing := -5
## A ship taken at sea (Objective.Kind.DECK: her deck cleared from stem to
## stern) is the band's: kept when she is a better hull than its own (or it
## has none, and the old one goes at `ship_trade_in`), else sold off for
## `prize_sale_share` of her price (a prize sold in haste on a strange
## shore fetches little). What hull a party's ship is, by its kind.
var prize_sale_share := 0.2
var prize_hulls := {"merchant": WorldTypes.ShipKind.KNARR, "rival_ship": WorldTypes.ShipKind.KARVE,
	"levy": WorldTypes.ShipKind.SNEKKJA, "the king's ships": WorldTypes.ShipKind.SNEKKJA, "avengers": WorldTypes.ShipKind.KARVE}

# --- Law, land and the unfree (thing_play, outlawry, landtake, thralls, omens) -----
## The Thing played (ThingPlay). Silver spent on oath-helpers, in steps of
## `ounces_per_supporter` (one supporter each): the choices offered.
var thing_spend_steps := [0, 10, 20, 40]
## Houses that stand with neither side and can be won over before the case
## is heard, at most this many shown.
var waverers_max := 2
## A law-man hired for one case: his fee and his Wits; for `lawman_keep_fee`
## he stays in the band as a law-wise man of its own.
var lawman_hire_fee := 15
var lawman_wits := 7
var lawman_keep_fee := 45
## The law-men of the Things: who pleads for hire where.
var lawmen := {"gulathing": "Thorleif the Wise", "frostathing": "Thorir Hound", "eidsvoll": "Arnfinn the Law-skilled",
	"iceland": "Ulfljot"}
## A man of the band who sits through this many cases beside the pleader
## (the band's best Wits after him) learns the law: he is law-wise.
var law_sat_cases := 2
## A favour promised for a house's backing: called in the next spring for
## this much, and refusing it costs this much standing.
var favour_ounces := 15
var favour_refused_standing := -15
## The standoff (a verdict against the side with more spears): pressing
## makes the other side yield in about this share at even spears, rising
## with the spears' odds; otherwise it comes to blows. Pressing at all is
## overbearing (honor).
var press_yield_base := 0.35
var press_honor := 5
## Arbitration by the house every house owes (Horda-Kari's kin): its fee,
## and the wergild it awards as a share of the full claim.
var arbiter_house := "Horda-Kari's kin"
var arbiter_fee := 10
var arbitration_share := 0.5
## The verdict asked for: a fair one (wergild) is honor; outlawry is the
## harder verdict and the other house's kin resent it along the ties; a
## verdict asked beyond what the weight of the case carries is refused and
## resented anyway.
var fair_verdict_honor := 3
var harsh_verdict_standing := -15
var overreach_standing := -10
## Losing: an appeal to the king (his man, at a Thing in his realm) turns
## outlawry into wergild for this much silver and some of his regard.
var appeal_relation := 30
var appeal_ounces := 20
var appeal_relation_cost := 10
## Summons in spring: a house the band has wronged takes it to the Thing.
var summons_chance := 0.25
## A skald's verse taken for níð by a house that has come to think ill of him.
var nid_chance := 0.35
## A land quarrel with a neighbour of the band's land, a spring in this many.
var land_quarrel_chance := 0.15

## Outlawry (Outlawry). A lesser outlaw must be out of Norway by the winter
## or he is a full outlaw. A full outlaw draws bounty hunters each spring in
## Norway: `hunters_base` men and one more for each `hunters_per_fame` of
## fame, at most `hunters_parties` parties; the price on his head is
## `bounty_base` plus fame / 2.
var hunters_chance := 0.7
var hunters_base := 5
var hunters_per_fame := 20
var hunters_parties := 2
var hunters_tier: CombatTypes.Tier = CombatTypes.Tier.VETERAN
var hunters_stat := 4
var bounty_base := 20
## A sworn friend may shelter a full outlaw for the winter, secretly; word
## gets out in this share of winters and costs that house with its lord.
var secret_shelter_risk := 0.25
var shelter_found_relation := -15
## The king's pardon: silver (`pardon_base` plus fame), or service: a fight
## for the king against his enemies.
var pardon_base := 60
var pardon_service_men := 8
## Killing other outlaws earns a full outlaw his peace (the Grettir clause).
var grettir_kills := 3
## The outlaw's road: robbing travellers in the wilds.
var rob_road_silver := 6
var rob_road_honor := 2
var rob_road_days := 2

## Land (Landtake). A farm bought of a house that will sell (a
## well-wisher or better), a unit at a time; a friend sells cheaper.
var land_price := 55
var land_price_friend := 45
var land_buy_max := 2
## Every unit wants this many hands to work it; a unit nobody works yields
## `land_untended_share` of its worth (the tenants' due).
var land_hands_per_unit := 2
var land_untended_share := 0.25
## A household (a wife) works this many units' worth with her people; each
## man left to keep the farm is a hand and a guard.
var household_hands := 2
var keepers_max := 3
## Held this many years, land is odal: it yields a fifth more and no king
## can take it.
var odal_years := 20
var odal_bonus := 0.2
## A hersir is granted this much land by his lord; the lord's summons each
## spring after: go (days) or pay.
var hersir_grant_units := 2
var levy_duty_ounces := 20
var levy_duty_days := 8
## A steading left empty by a house the band has ended by the sword.
var claim_units := 1
var claim_standing := -10
## Raiders who come to the band's farm while it is away: the keepers, the
## household and the thralls hold it, or they lose half the year's yield
## and some of the unfree.
var farm_raid_loss := 0.5
## Iceland: a household and its stock want a knarr, or passage on a
## settler's knarr for this much.
var iceland_passage := 40
var iceland_fire_base := 2
var iceland_buy_units := 1
var iceland_buy_price := 30
## The settler houses that come to Iceland (Families): [year, house, head, temper].
var iceland_settlers := [
	[875, "Ketilbjorn's kin", "Ketilbjorn the Old", "steadfast"],
	[878, "Skallagrim's kin", "Skallagrim", "proud"],
	[884, "Thorolf Mostur-beard's kin", "Thorolf", "steadfast"],
	[892, "Aud the Deep-minded's kin", "Aud", "peaceable"],
	[900, "Geirmund's kin", "Geirmund Dark-skin", "grasping"],
]
var iceland_wealth_per_house := 6
## Men's ambitions, in steps of `ambition_fulfilled` (CampaignRules): land
## held, a marriage made, a feud settled, a home settled.
var ambition_land := 60
var ambition_wife := 50
var ambition_vengeance := 50
var ambition_home := 60

## The unfree (Thralls). A named person of a house among the captives is
## ransomed for this much, and the house is glad of it; a plain captive
## for `captive_ransom`.
var named_ransom := 30
var ransom_standing := 6
## Selling a house's people abroad: standing with it a head, and honor for
## a named freeborn person sold.
var sell_standing := -3
var sell_named_standing := -20
var sell_named_honor := 3
## Dublin pays more for captives than any other market.
var captive_price_dublin := 18
## Slaving pays, but it is not the best living (docs/design/notes/
## balance.md). A market's want of people is a stock like any good's: each
## head sold lowers the next one's price by `captive_glut` (Market) and
## the glut mends a head every `captive_mend_days`, so a market buys a
## few a season, not every captive of the summer. Captives held are a
## burden: every `captive_load` of them take a load of the band's room,
## each slips away on a day with `captive_flight_day` (twice that when
## there are more than `captives_per_guard` of them to a man), and more
## captives than men slow the march by `captive_slow` each over, to at
## least `captive_slow_floor` of the pace. Every `sell_honor_heads` heads
## sold, honor -1: men know where a slaver's silver comes from.
var captive_mend_days := 15
var captive_load := 2
var captive_flight_day := 0.006
var captives_per_guard := 2
var captive_slow := 0.03
var captive_slow_floor := 0.7
var sell_honor_heads := 4
## Thralls eat this much of the store a winter, and each is a hand.
var thrall_food := 2
## Unrest among the thralls, 0..10: rises with their number past the
## watch, with the band away, with a hard hand; falls with a free man's
## word and manumission.
var unrest_per_unwatched := 1
var unrest_away := 2
var unrest_pressed := 2
var unrest_revolt := 6
## Freeing a thrall: honor, and in `freedman_house_years` the freedmen on
## the band's land are a house of their own, the band's friends.
var manumit_honor := 2
var freedman_house_years := 5
## A man of the band taken by slavers after a fight lost abroad: in this
## share of such fights; his price at the market where he is held is
## `taken_price` and `taken_per_tier` a tier; after `taken_years` he is
## sold on east, beyond finding.
var taken_chance := 0.5
var taken_price := 30
var taken_per_tier := 10
var taken_years := 2

## Omens (Omens). A spring has an omen in this share; a raid in this
## share. Heeding: `omen_wait_days`, or a sacrifice of `sacrifice_ounces`.
var spring_omen_chance := 0.35
var raid_omen_chance := 0.2
var omen_wait_days := 3
var sacrifice_ounces := 5
var omen_nerve := 3
## A seer in the hall at winter, asked for this much: her word is true.
var volva_chance := 0.35
var volva_fee := 8
## Her early winter: the summer is this many days short.
var early_winter_days := 25

# --- The wider world (east_road.gd, roam.gd, market.gd; notes/wider-world.md) ---
## The Baltic markets at the western end of the river road: the east's
## own merchants ply between them and the eastern towns.
const EAST_ROAD_MARKETS := ["birka", "gotland"]
## Leagues east beyond which a point is on the river road: its tidings are
## told at its own towns, the home waters' at home (WorldLife.hear_news).
const EAST_FROM_X := 128.0
## The east's own parties (Roam._populate_wider): Rus merchants on the
## river road, carrying one of `east_merchant_goods`; and a viking ship
## out of one of `wider_raider_lairs` in the west, that first goes about
## the places within `wider_raider_reach` leagues of it.
## At these markets there is talk of the road east: a band that comes
## there hears of Birka, where it begins (EastRoad.arrived).
var east_talk_markets := ["kaupang", "lade", "bjarkoy", "hedeby", "ribe", "dublin"]
var roam_east_merchants := 2
var east_merchant_goods := [WorldTypes.Good.FURS, WorldTypes.Good.AMBER, WorldTypes.Good.SILK, WorldTypes.Good.WALRUS_IVORY]
var roam_wider_raiders := 1
var wider_raider_lairs := ["shetland", "hebrides", "skye"]
var wider_raider_reach := 25.0
## Place -> {Good -> multiplier}: where a town's prices differ from its
## region's (`region_factor`). Going east, furs, amber and walrus ivory
## fetch more at every stage and silk costs less; Holmgard is the fur
## market itself; the Greeks make wine and want no Frankish blades.
var place_factor := {
	"aldeigjuborg": {WorldTypes.Good.FURS: 1.0, WorldTypes.Good.AMBER: 1.3, WorldTypes.Good.WALRUS_IVORY: 1.4, WorldTypes.Good.SILK: 0.8,
		WorldTypes.Good.FRANKISH_BLADES: 1.6, WorldTypes.Good.WINE: 1.6},
	"holmgard": {WorldTypes.Good.FURS: 0.8, WorldTypes.Good.AMBER: 1.4, WorldTypes.Good.WALRUS_IVORY: 1.5, WorldTypes.Good.SILK: 0.75,
		WorldTypes.Good.FRANKISH_BLADES: 1.8, WorldTypes.Good.WINE: 1.7},
	"koenugard": {WorldTypes.Good.FURS: 1.6, WorldTypes.Good.AMBER: 1.8, WorldTypes.Good.WALRUS_IVORY: 2.0, WorldTypes.Good.SILK: 0.6,
		WorldTypes.Good.FRANKISH_BLADES: 2.0, WorldTypes.Good.WINE: 1.4},
	"miklagard": {WorldTypes.Good.FURS: 2.4, WorldTypes.Good.AMBER: 2.4, WorldTypes.Good.WALRUS_IVORY: 2.4, WorldTypes.Good.SILK: 0.35,
		WorldTypes.Good.FRANKISH_BLADES: 1.0, WorldTypes.Good.WINE: 0.6, WorldTypes.Good.IRON: 1.3},
}
## Place -> the goods whose stock it makes good each year, in place of its
## region's (`good_sources`): the eastern towns are markets, not sources,
## save Holmgard for the forest furs. Silk at Miklagard stays at its price
## by the drift alone, so a year's buying there is felt the next.
var place_sources := {
	"aldeigjuborg": [], "holmgard": [WorldTypes.Good.FURS], "koenugard": [], "miklagard": [],
}
## Place -> a market's stock at its mean prices, in place of
## `stock_baseline`: the Great City is a deep market, where a knarr's hold
## of silk bought or of furs sold moves the price a third as much.
var place_depth := {"miklagard": 60}
## Place -> the middlemen's take there, in place of `market_spread`: the
## princes' tithe on the river road, the emperor's at Miklagard.
var place_spread := {"aldeigjuborg": 0.15, "holmgard": 0.15, "koenugard": 0.15, "miklagard": 0.2}
## Where captives are bought besides `slave_markets`, and what a head
## fetches there before the glut: dearer the further east.
var place_captive_price := {"holmgard": 16, "koenugard": 18, "miklagard": 26}
## The western isles' own stalls (TradeRoad.open_stalls, as `local_trade`):
## Shetland quarries soapstone and lacks iron; Ketil's hall wants iron and
## wine; Skye wants iron. (Not ivory: a hall's want is dear, and ivory is
## dear already in the west, so the Isles would be a gold mine for it.)
var wider_local_trade := {
	"shetland": {WorldTypes.Good.SOAPSTONE: "sells", WorldTypes.Good.IRON: "buys"},
	"hebrides": {WorldTypes.Good.IRON: "buys", WorldTypes.Good.WINE: "buys"},
	"skye": {WorldTypes.Good.IRON: "buys"},
}
## The portages (EastRoad, MapGrid.PORTAGES): leagues a day a hull is
## hauled on rollers (a small boat goes quickly, a laden knarr or a
## longship slowly); the chance a day of hauling that the band is fallen
## on, by whom ([men, tier, words] per portage, men give or take
## `portage_ambush_spread`); after a haul each man has this chance of a
## strained back (a turn's healing) and every man's loyalty drops so much.
var portage_haul := {
	WorldTypes.ShipKind.FAERING: 2.0, WorldTypes.ShipKind.KARVE: 1.2, WorldTypes.ShipKind.SNEKKJA: 0.9,
	WorldTypes.ShipKind.KNARR: 0.6, WorldTypes.ShipKind.LONGSHIP: 0.5,
}
var portage_ambush_day := 0.025
var portage_ambushers := [
	[6, CombatTypes.Tier.GREEN, "Men of the forest come out of the trees while your ship is on the rollers, %d of them, and want what she carries."],
	[8, CombatTypes.Tier.BLOODED, "Pecheneg riders come down on the haul round the rapids, %d of them, while your men are bent to the ropes."],
]
var portage_ambush_spread := 2
var portage_strain := 0.15
var portage_loyalty := 2
## A season in the emperor's guard at Miklagard (EastRoad): the rest of
## the summer and the winter in his service, for `guard_pay` and
## `guard_pay_man` a man, fame, honor and a lord's deeds; a band of fewer
## than `guard_min_men` is not taken on.
var guard_pay := 40
var guard_pay_man := 6
var guard_fame := 8
var guard_honor := 2
var guard_deeds := 3
var guard_min_men := 3
