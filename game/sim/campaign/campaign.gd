class_name Campaign
extends RefCounted
## The campaign loop: a year is a summer of battles and a winter in the
## hall. Wires the campaign modules (growth, loyalty, bonds, winter, leader,
## succession) to the combat sim. See campaign-architecture.md, Module I.

var rules: CampaignRules
var combat_rules: CombatRules
## Milestone 3: set by Sandbox.setup; null means fixed raids instead of a map.
var world: World = null
var world_rules: WorldRules = null
var rng: SimRng
var band: Band
var cal: Calendar
var log := PackedStringArray()
var over := false
var over_reason := ""
## Keep every battle's own log in `battle_logs` (slow; for debugging).
var debug_battles := false
var battle_logs: Array[PackedStringArray] = []
## Counters for the batch runner.
var tally := {
	"battles": 0, "wins": 0, "deaths": 0, "maimed": 0, "departures": 0,
	"recruits": 0, "successions": 0, "coal_biters": 0, "hall_fights": 0,
	# The choices before fights (FightOffer): fights declined, ambushes
	# laid, grounds chosen, times caught on the march.
	"faded": 0, "ambushes": 0, "waited": 0, "caught": 0,
}
var _pending_vow := ""
var _summer_wins := 0
## How the band answers a fight offer (FightOffer.Choice) when nobody is
## at the helm: a Callable taking the offer and returning a choice. The
## default takes the field; the sandbox sets its own (Sandbox.choose_fight).
var fight_policy: Callable = func(_offer: FightOffer) -> int: return FightOffer.Choice.TAKE_THE_FIELD
## The last offer made, for tools and tests.
var last_offer: FightOffer = null

const MAX_FIGHTERS := 12
const ENEMY_FIRST_ID := 1001


func _init(seed_in: int, p_rules: CampaignRules = null, p_combat_rules: CombatRules = null) -> void:
	rules = p_rules if p_rules != null else CampaignRules.new()
	combat_rules = p_combat_rules if p_combat_rules != null else CombatRules.new()
	rng = SimRng.new(seed_in)
	cal = Calendar.new(rules.start_year)
	band = Band.new()
	band.year = cal.year


## A fresh start: a leader of the given origin and `followers` sworn men.
func start(origin: CampaignTypes.Origin, leader_name: String, followers: int) -> void:
	var r := rng.fork("start")
	var leader := Recruits.make(r.fork("leader"), rules, origin, 22, leader_name, band.next_id())
	leader.is_leader = true
	leader.loyalty = 100
	# The player's man is the hero of the saga: the same edge an enemy leader gets.
	for s in [CombatTypes.Stat.MIGHT, CombatTypes.Stat.SKILL, CombatTypes.Stat.NERVE]:
		leader.set_stat(s, leader.stat(s) + rules.leader_start_bonus)
		leader.potential[s] = maxi(leader.potential[s], leader.stat(s))
	band.leader = leader
	band.luck = rules.luck_start
	for i in followers:
		var m := Recruits.random(r.fork("man:%d" % i), rules, band.next_id())
		if i == 0:
			m.is_banner = true
		elif i == 1:
			m.is_horn = true
		band.add_man(m)
		if Potential.is_coal_biter(rules, m):
			tally.coal_biters += 1
	band.log("%s gathers %d men and swears them to his service" % [leader.display_name, followers])
	_arm_new_men()
	_name_second_if_needed()


## A fresh start from one of the origins (Origins): the man, the few who
## follow him and what silver he has. Where he stands and whom he is at
## feud with are set by Journey.begin, once there is a world.
func start_from(origin_key: String, leader_name: String) -> void:
	var d := Origins.def(origin_key)
	start(d.origin, leader_name, int(d.followers))
	band.origin = str(d.key)
	band.silver = int(d.silver)
	Way.refresh(band)


func run_years(n: int) -> void:
	for i in n:
		if over:
			return
		run_year()


func run_year() -> void:
	if over:
		return
	band.year = cal.year
	summer()
	if over:
		return
	winter()
	if not over:
		cal.next_year()
		band.year = cal.year


# --- Summer -----------------------------------------------------------------

func summer() -> void:
	_summer_wins = 0
	if world != null:
		Sandbox.summer(self, log)
		_settle_vow()
		return
	for i in rules.battles_per_summer:
		if over:
			return
		var er := rng.fork("enemy:%d:%d" % [cal.year, i])
		var tier := _enemy_tier(er.fork("tier"))
		var size := clampi(band.fighters().size() + er.fork("size").randi_range(-rules.enemy_size_spread, rules.enemy_size_spread),
				rules.enemy_size_min, MAX_FIGHTERS)
		fight("raid", tier, size, true)
	_settle_vow()


## The band's mean stat, so enemy bands are built to the same strength.
func _mean_stat(fighters: Array[Man]) -> int:
	var total := 0
	for m in fighters:
		total += m.total_stats()
	return clampi(int(round(float(total) / maxi(1, fighters.size() * 5))), 1, 10)


## Picks an enemy quality relative to the band's own: mostly the same tier,
## sometimes one worse or one better. The player chooses his fights.
func _enemy_tier(r: SimRng) -> CombatTypes.Tier:
	var total := 0
	var fighters := band.fighters()
	for m in fighters:
		total += m.tier
	var base := int(round(float(total) / maxi(1, fighters.size())))
	var roll := r.randf()
	var shift := 0
	if roll < rules.enemy_weaker_chance:
		shift = -1
	elif roll > 1.0 - rules.enemy_stronger_chance:
		shift = 1
	return clampi(base + shift, CombatTypes.Tier.GREEN, CombatTypes.Tier.CHAMPION) as CombatTypes.Tier


## Fights one battle with the band's men as side 0, as `fight_policy`
## answers the offer: the offer first (`offer_fight`), then the choice, then
## `resolve_offer`. `attacking` is whether the fight is the band's doing.
## Returns null when the band faded away.
func fight(kind: String, enemy_tier: CombatTypes.Tier, enemy_size: int, attacking: bool, stat_center := -1,
		at_sea := false, cornered := false) -> BattleResult:
	var offer := offer_fight(kind, enemy_tier, enemy_size, attacking, stat_center, at_sea, cornered)
	var choice: int = fight_policy.call(offer)
	return resolve_offer(offer, choice)


## The fight before it is fought: the enemy as the world has them (their
## arms drawn from the seed, their leader named), the scout's report, and
## whether either side saw the other first. On land, when they come for
## you, your scout seeing them first makes an ambush yours; failing that,
## `caught_chance` makes it theirs.
func offer_fight(kind: String, enemy_tier: CombatTypes.Tier, enemy_size: int, attacking: bool, stat_center := -1,
		at_sea := false, cornered := false, ground := "") -> FightOffer:
	tally.battles += 1
	var o := FightOffer.new()
	o.kind = kind
	o.ground = ground
	o.enemy_size = maxi(1, enemy_size)
	o.enemy_tier = enemy_tier
	o.attacking = attacking
	o.at_sea = at_sea
	o.cornered = cornered
	o.stat_center = stat_center
	o.our_men = mini(line_men().size(), MAX_FIGHTERS)
	if world_rules != null:
		o.odds_max = world_rules.raid_odds_max
	o.seed_value = rng.fork("battle:%d:%d" % [cal.year, tally.battles]).seed_value
	var er := SimRng.new(o.seed_value).fork("enemy-arms")
	var split := Scenario.band_split(o.enemy_size, combat_rules)
	o.enemy_shields = split[0]
	o.enemy_spears = split[1]
	o.enemy_bows = split[2]
	if at_sea:
		o.enemy_shields = o.enemy_size
		o.enemy_spears = 0
		o.enemy_bows = 0
	o.enemy_leader = BandFactory.leader_name(er.fork("name"), 8)
	o.doctrine = LeaderAI.Doctrine.AGGRESSIVE if er.randf() < 0.4 else LeaderAI.Doctrine.STEADY
	if er.randf() < 0.4:
		o.doctrine = LeaderAI.Doctrine.CUNNING
	var scout := Scouting.pick_scout(band.fighters(rules))
	var wits := scout.stat(CombatTypes.Stat.WITS) if scout != null else 1
	var tier := scout.tier if scout != null else CombatTypes.Tier.GREEN
	# Foresight (the law-wise man's gift): his scouts count true, and he is
	# never caught on the march.
	var foresight: bool = band.gift("foresight", false)
	if foresight:
		wits = 10
		tier = CombatTypes.Tier.VETERAN
	var sr := SimRng.new(o.seed_value).fork("scout")
	# Only a band that comes to you can be caught on the march, by you or
	# the other way about; your own raid is your own doing.
	if not at_sea and not cornered and not attacking:
		o.we_know_first = Scouting.spots_first(sr.fork("first"), rules, wits, tier)
		if not o.we_know_first and not foresight:
			o.they_know_first = sr.fork("caught").randf() < rules.caught_chance
	o.report = Scouting.report(sr.fork("report"), rules, wits, tier, o)
	last_offer = o
	return o


## Answers the offer with the leader AIs fighting it out. FADE_AWAY: no
## fight; the band withdrew (`fade`) and null comes back. Otherwise
## `build_fight`, the battle run to its end, and `conclude_fight`.
func resolve_offer(offer: FightOffer, choice: int) -> BattleResult:
	choice = settle_choice(offer, choice)
	if choice == FightOffer.Choice.FADE_AWAY:
		fade(offer)
		return null
	var built := build_fight(offer, choice)
	var battle: Battle = built.battle
	var result := battle.run()
	conclude_fight(offer, built, result)
	return result


## The choice as it will be taken: no choice when they saw you first, and
## the field when the offer does not allow what was asked.
func settle_choice(offer: FightOffer, choice: int) -> int:
	if offer.they_know_first or not offer.allows(choice):
		return FightOffer.Choice.TAKE_THE_FIELD
	return choice


## The band declines the fight: it costs honor, never luck or blood.
func fade(offer: FightOffer) -> void:
	tally.faded += 1
	log.append("%s: %s, %s: the band fades away" % [cal.describe(), offer.kind, offer.brief()])
	# Our strength over theirs, as Leader.on_battle reads it.
	var odds := float(offer.our_men) / maxf(1.0, float(offer.enemy_size))
	Leader.on_battle(rules, band, false, true, odds, log, BattleResult.Outcome.WITHDREW)


## Builds the fight the choice makes (Scenario: the open field, the river
## bank, an ambush either way; the flat deck at sea) with the band's men
## as side 0 and leader AIs on both sides, and returns Scenario's
## dictionary with `fighters`, `choice` and `odds` added. Nothing is fought:
## run `built.battle` (or hand it to the battle view, clearing side 0's AI)
## and give the result to `conclude_fight`.
func build_fight(offer: FightOffer, choice: int) -> Dictionary:
	choice = settle_choice(offer, choice)
	# The days between fights mend a turn; then the men who can stand.
	band.mend(rules.mend_between_fights)
	var fighters := line_men()
	if fighters.size() > MAX_FIGHTERS:
		fighters = fighters.slice(0, MAX_FIGHTERS)
	if offer.they_know_first:
		tally.caught += 1
	elif choice == FightOffer.Choice.LAY_AMBUSH:
		tally.ambushes += 1
	elif choice == FightOffer.Choice.WAIT_FOR_THEM:
		tally.waited += 1
	var seed_in := offer.seed_value
	var ours: Array[Warrior] = []
	for m in fighters:
		ours.append(m.to_warrior(0, rules, combat_rules.javelins_per_man))
	# The war-leader leads the wall in the leader's place: he is its head,
	# its voice and its eyes, and the side's leader AI reads him.
	var stallari := commanding()
	if stallari != null and not ours.is_empty() and ours[0].id == stallari.id:
		ours[0].is_leader = true
	var center := offer.stat_center if offer.stat_center > 0 else _mean_stat(fighters)
	var enemy := BandFactory.make_mixed_band(SimRng.new(seed_in).fork("enemy"), 1, offer.enemy_shields,
			offer.enemy_spears, offer.enemy_bows, offer.enemy_tier, combat_rules, CombatTypes.Armor.NONE, 8, ENEMY_FIRST_ID, center)
	if enemy[0].display_name != offer.enemy_leader:
		enemy[0].display_name = offer.enemy_leader
	var name := offer.scenario_for(choice)
	var pick := {"doctrine": offer.doctrine}
	var built: Dictionary
	var template := ""
	if offer.ground != "" and name != "ambush" and name != "ambushed":
		# The ground the map gives (FightOffer.ground): the field is built
		# from where the band stands.
		var held := choice == FightOffer.Choice.WAIT_FOR_THEM
		match offer.ground:
			"sea":
				# Aboard: they close, and it is fought out on the strand by the
				# ships, the side that came on making for the other's.
				template = "meadow"
				pick.objective = Objective.Kind.REACH_THE_SHIPS
				pick.attacker = 0 if offer.attacking else 1
			"strand":
				template = "meadow"
				pick.objective = -1
			"farm":
				template = "farmstead"
				if held:
					pick.objective = Objective.Kind.THE_HALL
					pick.attacker = 1
				else:
					pick.objective = -1
			"hills":
				template = "hillside"
				if held:
					pick.objective = Objective.Kind.HOLD_GROUND  # the high bank is yours
					pick.attacker = 1
				else:
					pick.objective = -1
			"open":
				if held:
					template = "river"
					pick.objective = Objective.Kind.HOLD_GROUND
					pick.attacker = 1
				else:
					pick.objective = -1
		built = Scenario.build("equal_green", seed_in, combat_rules, true, fighters.size(), template, {"ours": ours, "theirs": enemy}, pick)
	elif offer.at_sea:
		# A deck is flat and narrow: the symmetric field, no ground.
		built = Scenario.build("equal_green", seed_in, combat_rules, false, fighters.size(), "", {"ours": ours, "theirs": enemy}, pick)
	else:
		if name == "equal_green":
			pick.objective = -1  # the open field: nothing to take or hold
		built = Scenario.build(name, seed_in, combat_rules, true, fighters.size(), "", {"ours": ours, "theirs": enemy}, pick)
	var battle: Battle = built.battle
	var ours_aggressive := offer.attacking or choice == FightOffer.Choice.LAY_AMBUSH
	if choice == FightOffer.Choice.WAIT_FOR_THEM:
		ours_aggressive = false
	battle.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE if ours_aggressive else LeaderAI.Doctrine.STEADY))
	if offer.they_know_first or choice == FightOffer.Choice.WAIT_FOR_THEM:
		battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	built.fighters = fighters
	built.choice = choice
	built.odds = float(fighters.size()) / maxf(1.0, float(offer.enemy_size))  # ours over theirs
	built.war_leader = stallari.id if stallari != null else -1
	return built


## The war-leader when he leads the wall in the leader's place: named, the
## leader keeping back, and fit to stand in a line. Null otherwise.
func commanding() -> Man:
	if not band.leader_keeps_back:
		return null
	var m := band.war_leader()
	if m == null or m.too_hurt_to_fight(rules):
		return null
	return m


## The men who stand in the band's line for a fight: the leader and every
## man fit to fight (Band.fighters), or, when the war-leader commands in
## his place (`commanding`), the war-leader first and the leader not at all.
func line_men() -> Array[Man]:
	var men := band.fighters(rules)
	var stallari := commanding()
	if stallari == null:
		return men
	var out: Array[Man] = [stallari]
	for m in men:
		if m != band.leader and m != stallari:
			out.append(m)
	return out


## A holmgang: the leader alone against `opponent`, to first blood
## (Scenario.build_duel). Returns the same dictionary as `build_fight`,
## with `duel` true; `conclude_fight` takes it with a null offer.
func build_duel(opponent: Warrior, seed_in: int) -> Dictionary:
	tally.battles += 1
	tally.duels = tally.get("duels", 0) + 1
	var fighters: Array[Man] = [band.leader]
	var ours: Array[Warrior] = [band.leader.to_warrior(0, rules, 0)]
	var theirs: Array[Warrior] = [opponent]
	var built := Scenario.build_duel(seed_in, combat_rules, ours, theirs)
	(built.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	built.fighters = fighters
	built.choice = FightOffer.Choice.TAKE_THE_FIELD
	built.odds = 1.0
	built.duel = true
	built.seed_value = seed_in
	return built


## The burned hall: the night the saga begins, the leader and his men
## getting out of the ring of the jarl's men (Scenario.build_escape), led
## by `leader_name` (the burning house's head, from Journey.begin). The
## band's men as side 0, the jarl's men drawn here so their ids never meet
## the band's. Returns the same dictionary as `build_fight`, with `escape`
## true and `seed_value`; nobody's AI is set on side 0 (the player fights
## it, or `Journey.skip_escape` gives it one). `conclude_fight` takes it
## with a null offer.
func build_escape(leader_name := "") -> Dictionary:
	tally.battles += 1
	var fighters := band.fighters(rules)
	var seed_in := rng.fork("escape").seed_value
	var ours: Array[Warrior] = []
	for m in fighters:
		ours.append(m.to_warrior(0, rules, combat_rules.javelins_per_man))
	var theirs := BandFactory.make_mixed_band(SimRng.new(seed_in).fork("burners"), 1, combat_rules.escape_enemy_shields + combat_rules.escape_flankers,
			combat_rules.escape_enemy_spears, 0, CombatTypes.Tier.GREEN, combat_rules, CombatTypes.Armor.NONE, 3, ENEMY_FIRST_ID)
	var built := Scenario.build_escape(seed_in, combat_rules, {"ours": ours, "theirs": theirs, "leader_name": leader_name})
	built.fighters = fighters
	built.choice = FightOffer.Choice.TAKE_THE_FIELD
	built.odds = float(fighters.size()) / maxf(1.0, float(theirs.size()))
	built.escape = true
	built.seed_value = seed_in
	return built


## What the fight left: growth, wounds, deaths, loot, a man who asks to
## join (Aftermath); grief and oaths (Bonds); luck, fame and the flat
## plunder of a win (Leader, not for a duel); succession if the leader
## fell. Returns Aftermath's dictionary (`lines` reads it out).
func conclude_fight(offer: FightOffer, built: Dictionary, result: BattleResult) -> Dictionary:
	var battle: Battle = built.battle
	var fighters: Array[Man] = built.fighters
	var ours: Array[Warrior] = built.ours
	var enemy: Array[Warrior] = built.theirs
	var is_duel: bool = built.get("duel", false)
	var is_escape: bool = built.get("escape", false)
	if debug_battles:
		battle_logs.append(battle.log.duplicate())
	var won := result.winner == 0
	var outcome := result.outcome(0)
	var seed_in: int = built.get("seed_value", offer.seed_value if offer != null else 0)
	if is_escape:
		log.append("%s: the burning of the hall, against %d men: %s (%s)" % [cal.describe(), enemy.size(), result.summary(), result.outcome_text(0)])
	elif is_duel:
		log.append("%s: holmgang against %s: %s" % [cal.describe(), enemy[0].display_name, result.outcome_text(0)])
	else:
		log.append("%s: %s (%s) against %d %s men: %s (%s)" % [cal.describe(), offer.kind,
				FightOffer.CHOICE_NAMES[built.choice] if not offer.they_know_first else "caught on the march",
				offer.enemy_size, CombatTypes.TIER_NAMES[offer.enemy_tier], result.summary(), result.outcome_text(0)])

	# Growth, wounds, deaths, loot, a man who asks to join.
	var on_land: bool = is_escape or (not is_duel and not offer.at_sea)
	var told := Aftermath.apply(rules, band, ours, result, SimRng.new(seed_in).fork("aftermath"), on_land, log)
	tally.recruits += told.joined.size()
	_count_the_year(ours)
	_arm_new_men()
	var survivors: Array[Man] = []
	var fallen: Array[Man] = []
	for m in fighters:
		if m.alive:
			survivors.append(m)
		else:
			fallen.append(m)
	tally.deaths += fallen.size()
	for w in ours:
		if w.fate == CombatTypes.Fate.MAIMED:
			tally.maimed += 1
	# The bridge already awarded "fought together"; Bonds.after_battle would
	# award it again, so it runs here only for grief and oath-brother checks.
	var fought := rules.bond_fought_together
	rules.bond_fought_together = 0
	Bonds.after_battle(rules, band, survivors, fallen, log)
	rules.bond_fought_together = fought
	var killer := enemy[0].display_name
	for m in fallen:
		Bonds.on_death(rules, band, m, killer, log)
		if m != band.leader:
			band.remove_man(m)

	# Luck, reputation, plunder. Getting out of the burned hall is none of
	# these: the saga begins there, it is not judged by it.
	if not is_duel and not is_escape:
		var fame_before := band.fame
		Leader.on_battle(rules, band, won, true, built.odds, log, outcome)
		# Under the war-leader the fight is his as much as the leader's.
		if int(built.get("war_leader", -1)) >= 0 and band.fame > fame_before:
			band.fame -= (band.fame - fame_before) - roundi((band.fame - fame_before) * rules.war_leader_fame_share)
	if won and not is_duel and not is_escape:
		_summer_wins += 1
		tally.wins += 1
		var flat := rules.plunder_per_win if world == null else rules.plunder_per_win_world
		band.silver += flat
		Loyalty.share_plunder(rules, band, flat, rules.fair_leader_share, log)
		for m in band.living_men():
			if m.ambition == CampaignTypes.Ambition.SILVER or m.ambition == CampaignTypes.Ambition.FAME:
				Loyalty.ambition_progress(rules, band, m, rules.ambition_per_win, log)
	if band.leader != null and not band.leader.alive:
		succession("battle")
	return told


## This year's part of each man's fight, for the ring-giving: the fight
## stood, men put down, a wound taken, a break, a deed told.
func _count_the_year(ours: Array[Warrior]) -> void:
	for w in ours:
		var m := band.man_by_id(w.id)
		if m == null:
			continue
		var t := m.year_tally
		t["fights"] = int(t.get("fights", 0)) + 1
		t["kills"] = int(t.get("kills", 0)) + w.kills
		if w.wound != CombatTypes.Wound.UNHURT or w.fate == CombatTypes.Fate.MAIMED:
			t["wounds"] = int(t.get("wounds", 0)) + 1
		if w.broken:
			t["broke"] = int(t.get("broke", 0)) + 1
		if w.kills >= rules.deed_kills:
			t["deeds"] = int(t.get("deeds", 0)) + 1


## Gives every man who has no place in the line yet one: a shield-bearer,
## a spearman of the second rank or a bowman, whichever the band is
## shortest of against `Scenario.band_split` (two thirds shields). A man
## keeps the place he was given.
func _arm_new_men() -> void:
	var men := band.fighters()
	var have := [0, 0, 0]
	for m in men:
		if m.armed or m == band.leader:
			have[int(m.role)] += 1
	if band.leader != null:
		band.leader.armed = true
	for m in men:
		if m.armed:
			continue
		var want := Scenario.band_split(have[0] + have[1] + have[2] + 1, combat_rules)
		var role: CombatTypes.Role = CombatTypes.Role.SHIELD
		var short: int = int(want[0]) - int(have[0])
		for r: int in [CombatTypes.Role.SPEAR, CombatTypes.Role.MISSILE]:
			var lack: int = int(want[r]) - int(have[r])
			if lack > short:
				short = lack
				role = r as CombatTypes.Role
		m.role = role
		m.armed = true
		have[int(role)] += 1


func _settle_vow() -> void:
	if _pending_vow == "":
		return
	if _summer_wins >= rules.vow_wins_needed:
		Leader.on_vow_kept(rules, band, _pending_vow, log)
	else:
		Leader.on_vow_broken(rules, band, _pending_vow, log)
	_pending_vow = ""


# --- Winter -----------------------------------------------------------------

## The four winter turns and the thaw. Each turn's plan comes from
## `planner` (a Callable taking the rules, the band and the calendar and
## returning a WinterPlan; Winter.default_plan when none is given). `opts`
## is for the winter the player plays (WinterHall): "recruits" false keeps
## the thaw from drawing men (they came to the hall already), "returning"
## is men sent home for the winter, who come back or not at the thaw.
func winter(planner := Callable(), opts := {}) -> void:
	Hall.ensure(band, rules)
	cal.start_winter()
	var unseated_all := {}
	for t in 4:
		if over:
			return
		var plan: WinterPlan = planner.call(rules, band, cal) if planner.is_valid() else Winter.default_plan(rules, band, cal)
		var report := Winter.run_turn(rng.fork("winter:%d:%d" % [cal.year, t]), rules, band, cal, plan, log)
		_apply_report(plan, report)
		for id in report.men_without_seat:
			unseated_all[id] = true
		if not report.battle_required.is_empty():
			tally.hall_fights += 1
			var br: Dictionary = report.battle_required
			fight(br.kind, br.tier, br.attackers, false, -1, false, true)  # at your own hall: cornered
			if over:
				return
		if cal.winter_turn == CampaignTypes.WinterTurn.THAW:
			_thaw(opts)
		else:
			cal.advance_turn()


func _apply_report(plan: WinterPlan, report: WinterReport) -> void:
	for m in band.living_men():
		var fed: bool = report.fed.get(m.id, true)
		var seated: bool = report.seated.get(m.id, true)
		Loyalty.winter_drift(rules, band, m, fed, seated, log)
	for id in report.drilled:
		var m := band.man_by_id(id)
		if m != null:
			Growth.drill(rules, m, report.drilled[id], log)
	for id in plan.gifts:
		var m := band.man_by_id(id)
		if m != null:
			Loyalty.gift(rules, band, m, plan.gifts[id], log)
	if report.cold:
		for m in band.living_men():
			Loyalty.adjust(m, -rules.camp_cold_loyalty)
		log.append("The cold of the camp gnaws at the men's goodwill.")
	if report.feasted:
		Leader.on_feast(rules, band, true, log)
	if report.vow != "":
		_pending_vow = report.vow
	for ev in report.events:
		# A skald's praise-poem and an envoy's regard are fame.
		if int(ev.get("fame", 0)) != 0:
			band.fame = clampi(band.fame + int(ev.fame), Leader.REP_MIN, Leader.REP_MAX)
		if ev.get("recruit_request", false) and band.living_men().size() < rules.recruit_cap:
			var m := Recruits.make(rng.fork("outlaw:%d:%d" % [cal.year, cal.winter_turn]), rules,
					CampaignTypes.Origin.OUTLAW, 24, Recruits.NAMES[rng.fork("outlaw_name:%d" % cal.year).randi_range(0, Recruits.NAMES.size() - 1)], band.next_id())
			band.add_man(m)
			tally.recruits += 1
		# Where the houses are, a daughter is offered by name, as a choice
		# (WinterHall's talk); the old offer from nowhere is for the plain
		# campaign alone.
		if ev.has("marriage_offer") and band.wife == "" and (world == null or world.families == null):
			var mr := rng.fork("marriage:%d" % cal.year)
			var pot: Array[int] = []
			for s in 5:
				pot.append(clampi(rules.cap_mean + mr.randi_range(-rules.cap_spread, rules.cap_spread), 1, 10))
			var house: String = ev.marriage_offer
			Family.marry(rules, band, "a daughter of %s" % house, pot, mr.randi_range(1, rules.household_skill_max), house, log)
			# A house of the web: the marriage ties the band to it (Families).
			if world != null and world.families != null and world.families.houses.has(house):
				Families._band_tie(band, house, "marriage")
				world.families.shift(world_rules, band, house, world_rules.standing_marriage)


func _thaw(opts := {}) -> void:
	# Land yields; the world moves on.
	if world != null:
		Landtake.thaw_yield(world_rules, band, cal.year, log)
		Sandbox.year_end(self, log)
	# Births, aging and growth, bonds drifting, then who stays.
	Family.winter_births(rng.fork("births:%d" % cal.year), rules, band, cal, log)
	for m in band.fighters():
		Growth.winter_age(rng.fork("age:%d:%d" % [cal.year, m.id]), rules, m, log)
		Growth.apply_growth(rules, m, log)
	Bonds.winter_drift(rng.fork("bonds:%d" % cal.year), rules, band, log)
	# A shape not drilled all winter fades a point in every man who sat it out.
	for m in band.fighters():
		if m.drilled_year != cal.year and not m.drill.is_empty():
			for shape in m.drill.keys():
				m.drill[shape] = maxi(0, int(m.drill[shape]) - rules.drill_decay)
	var leavers := Loyalty.departures(rng.fork("leave:%d" % cal.year), rules, band, log)
	for m in leavers:
		band.remove_man(m)
	tally.departures += leavers.size()
	# Men sent home for the winter come back, or do not.
	var rr := rng.fork("returning:%d" % cal.year)
	for m: Man in opts.get("returning", []):
		m.age += 1
		if m.loyalty >= rules.sent_home_return_loyalty or rr.randf() < rules.sent_home_return_chance:
			band.add_man(m, m.joined_year)
			log.append("%s comes back from his kin at the thaw." % m.display_name)
		else:
			tally.departures += 1
			log.append("%s stays with his kin, and does not come back." % m.display_name)
			band.log("%s went home for the winter and did not come back." % m.display_name)
	# The year's tallies of deeds are told; the next year starts clean.
	for m in band.living_men():
		m.year_tally = {}
	if band.leader != null:
		band.leader.year_tally = {}
	# Old age can take the leader in his bed.
	if band.leader != null and band.leader.age >= rules.old_age \
			and rng.fork("old:%d" % cal.year).randf() < rules.old_leader_death_chance:
		band.leader.alive = false
		band.log("%s dies in his bed, old" % band.leader.display_name)
		succession("old")
		if over:
			return
	_name_second_if_needed()
	# Fame draws new men in spring (unless they came to the hall in winter).
	var wanted := Leader.recruits_drawn(rules, band) if opts.get("recruits", true) else 0
	for i in wanted:
		if band.living_men().size() >= rules.recruit_cap:
			break
		var m := Recruits.random(rng.fork("recruit:%d:%d" % [cal.year, i]), rules, band.next_id())
		band.add_man(m)
		_arm_new_men()
		tally.recruits += 1
		if Potential.is_coal_biter(rules, m):
			tally.coal_biters += 1
		band.log("%s, a %s, swears to %s" % [m.display_name, CampaignTypes.ORIGIN_NAMES[m.origin], band.leader.display_name])
	if band.living_men().is_empty() and band.leader != null and band.leader.alive:
		band.log("%s winters alone" % band.leader.display_name)


## A leader without a living named second names his best man: highest tier,
## then the strongest bond with him.
func _name_second_if_needed() -> void:
	var second := band.man_by_id(band.sworn_second_id)
	if second != null and second.alive and band.men.has(second):
		return
	var best: Man = null
	for m in band.living_men():
		if best == null or m.tier > best.tier or (m.tier == best.tier and band.bond(band.leader, m) > band.bond(band.leader, best)):
			best = m
	if best != null:
		Succession.name_second(band, best, log)


# --- Succession -------------------------------------------------------------

func succession(death_cause: String) -> void:
	var old := band.leader
	var h := Succession.heir(rules, band, cal)
	var heir_man: Man = null
	match h.kind:
		"son":
			var son: Dictionary = h.son
			heir_man = Recruits.son_of(rng.fork("heir:%d" % cal.year), rules, old, son.potential, son.name, band.next_id())
			heir_man.age = cal.year - int(son.born)
			heir_man.born = int(son.born)
			son.alive = false  # he is the leader now, no longer a boy at home
		"second":
			heir_man = h.man
			band.remove_man(heir_man)
		_:
			over = true
			over_reason = "no heir: the band scatters"
			band.log("%s dies with no heir, and the band scatters" % old.display_name)
			return
	tally.successions += 1
	var feast := mini(band.silver, rules.grave_ale_ounces)
	var vow := "to avenge %s" % old.display_name if death_cause == "battle" else "to hold what %s held" % old.display_name
	var leavers := Succession.succeed(rng.fork("succeed:%d" % cal.year), rules, band, cal, heir_man, feast, vow, log, death_cause)
	tally.departures += leavers.size()
	_pending_vow = vow


func summary() -> String:
	return "%d: %s leads %d men | battles %d won %d | dead %d maimed %d left %d joined %d | successions %d | luck %d fame %d honor %d%s" % [
		cal.year, band.leader.display_name if band.leader else "nobody", band.living_men().size(),
		tally.battles, tally.wins, tally.deaths, tally.maimed, tally.departures, tally.recruits,
		tally.successions, band.luck, band.fame, band.honor, (" | OVER: " + over_reason) if over else "",
	]
