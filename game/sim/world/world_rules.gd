class_name WorldRules
extends RefCounted
## Every tunable in the world layer, with defaults, sectioned by module.
## See world-architecture.md > Scales and time.

# --- Core -------------------------------------------------------------------
var summer_days := 200
var ship_crew := {
	WorldTypes.ShipKind.KARVE: 12, WorldTypes.ShipKind.SNEKKJA: 24,
	WorldTypes.ShipKind.LONGSHIP: 40, WorldTypes.ShipKind.KNARR: 10,
}
var ship_cargo := {
	WorldTypes.ShipKind.KARVE: 6, WorldTypes.ShipKind.SNEKKJA: 10,
	WorldTypes.ShipKind.LONGSHIP: 14, WorldTypes.ShipKind.KNARR: 40,
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
var raid_odds_max := 2.0
var raid_days := 3
var trade_min_silver := 30
var trade_spend_fraction := 0.6
var market_days := 2
var contract_days := 10
var idle_days := 5
var idle_turns_before_roving := 2
var settle_if_fraction := 0.5
var land_food_per_unit := 10
var land_silver_per_unit := 5
var pass_years_interrupts := ["feud_attack", "summons", "spine", "son_of_age", "vow_due"]
