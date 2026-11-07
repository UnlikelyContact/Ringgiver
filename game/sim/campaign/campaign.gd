class_name Campaign
extends RefCounted
## The campaign loop: a year is a summer of battles and a winter in the
## hall. Wires the campaign modules (growth, loyalty, bonds, winter, leader,
## succession) to the combat sim. See campaign-architecture.md, Module I.

var rules: CampaignRules
var combat_rules: CombatRules
var rng: SimRng
var band: Band
var cal: Calendar
var log := PackedStringArray()
var over := false
var over_reason := ""
## Counters for the batch runner.
var tally := {
	"battles": 0, "wins": 0, "deaths": 0, "maimed": 0, "departures": 0,
	"recruits": 0, "successions": 0, "coal_biters": 0, "hall_fights": 0,
}
var _pending_vow := ""
var _summer_wins := 0

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
	for i in rules.battles_per_summer:
		if over:
			return
		var tier := _enemy_tier(rng.fork("enemy_tier:%d:%d" % [cal.year, i]))
		fight("raid", tier, rules.enemy_band_size, true)
	_settle_vow()


## Picks an enemy quality: mostly matched to the band, sometimes worse or better.
func _enemy_tier(r: SimRng) -> CombatTypes.Tier:
	var roll := r.randf()
	if roll < 0.35:
		return CombatTypes.Tier.GREEN
	if roll < 0.8:
		return CombatTypes.Tier.BLOODED
	if roll < 0.95:
		return CombatTypes.Tier.VETERAN
	return CombatTypes.Tier.CHAMPION


## Fights one battle with the band's men as side 0. `attacking` sets who
## has the aggressive leader. Applies growth, bonds, luck, plunder and
## deaths, and handles the leader's death.
func fight(kind: String, enemy_tier: CombatTypes.Tier, enemy_size: int, attacking: bool) -> BattleResult:
	tally.battles += 1
	var seed_in := rng.fork("battle:%d:%d" % [cal.year, tally.battles]).seed_value
	var battle := Battle.new(combat_rules, seed_in)
	var fighters := band.fighters()
	if fighters.size() > MAX_FIGHTERS:
		fighters = fighters.slice(0, MAX_FIGHTERS)
	var ours: Array[Warrior] = []
	for m in fighters:
		ours.append(m.to_warrior(0))
	var enemy := BandFactory.make_band(SimRng.new(seed_in).fork("enemy"), 1, enemy_size, enemy_tier,
			CombatTypes.Armor.NONE, 8, ENEMY_FIRST_ID)
	BandFactory.deploy_column(battle.grid, ours, 5, Vector2i(1, 0), combat_rules)
	BandFactory.deploy_column(battle.grid, enemy, 10, Vector2i(-1, 0), combat_rules)
	battle.add_band(ours)
	battle.add_band(enemy)
	battle.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE if attacking else LeaderAI.Doctrine.STEADY))
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.STEADY if attacking else LeaderAI.Doctrine.AGGRESSIVE))
	var result := battle.run()
	var won := result.winner == 0
	var odds := float(enemy_size) / maxf(1.0, fighters.size())
	log.append("%s: %s against %d %s men: %s" % [cal.describe(), kind, enemy_size,
			CombatTypes.TIER_NAMES[enemy_tier], result.summary()])

	# Growth, wounds, deaths.
	BattleBridge.after_battle(rules, band, ours, result, log)
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
	Bonds.after_battle(rules, band, survivors, fallen, log)
	var killer := enemy[0].display_name
	for m in fallen:
		Bonds.on_death(rules, band, m, killer, log)
		if m != band.leader:
			band.remove_man(m)

	# Luck, reputation, plunder.
	Leader.on_battle(rules, band, won, true, odds, log)
	if won:
		_summer_wins += 1
		tally.wins += 1
		band.silver += rules.plunder_per_win
		Loyalty.share_plunder(rules, band, rules.plunder_per_win, rules.fair_leader_share, log)
		for m in band.living_men():
			if m.ambition == CampaignTypes.Ambition.SILVER or m.ambition == CampaignTypes.Ambition.FAME:
				Loyalty.ambition_progress(rules, band, m, rules.ambition_per_win, log)
	if band.leader != null and not band.leader.alive:
		succession("battle")
	return result


func _settle_vow() -> void:
	if _pending_vow == "":
		return
	if _summer_wins >= rules.vow_wins_needed:
		Leader.on_vow_kept(rules, band, _pending_vow, log)
	else:
		Leader.on_vow_broken(rules, band, _pending_vow, log)
	_pending_vow = ""


# --- Winter -----------------------------------------------------------------

func winter() -> void:
	Hall.ensure(band, rules)
	cal.start_winter()
	var unseated_all := {}
	for t in 4:
		if over:
			return
		var plan := Winter.default_plan(rules, band, cal)
		var report := Winter.run_turn(rng.fork("winter:%d:%d" % [cal.year, t]), rules, band, cal, plan, log)
		_apply_report(plan, report)
		for id in report.men_without_seat:
			unseated_all[id] = true
		if not report.battle_required.is_empty():
			tally.hall_fights += 1
			var br: Dictionary = report.battle_required
			fight(br.kind, br.tier, br.attackers, false)
			if over:
				return
		if cal.winter_turn == CampaignTypes.WinterTurn.THAW:
			_thaw()
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
	if report.feasted:
		Leader.on_feast(rules, band, true, log)
	if report.vow != "":
		_pending_vow = report.vow


func _thaw() -> void:
	# Births, aging and growth, bonds drifting, then who stays.
	Family.winter_births(rng.fork("births:%d" % cal.year), rules, band, cal, log)
	for m in band.fighters():
		Growth.winter_age(rng.fork("age:%d:%d" % [cal.year, m.id]), rules, m, log)
		Growth.apply_growth(rules, m, log)
	Bonds.winter_drift(rng.fork("bonds:%d" % cal.year), rules, band, log)
	var leavers := Loyalty.departures(rng.fork("leave:%d" % cal.year), rules, band, log)
	for m in leavers:
		band.remove_man(m)
	tally.departures += leavers.size()
	# Old age can take the leader in his bed.
	if band.leader != null and band.leader.age >= rules.old_age \
			and rng.fork("old:%d" % cal.year).randf() < rules.old_leader_death_chance:
		band.leader.alive = false
		band.log("%s dies in his bed, old" % band.leader.display_name)
		succession("old")
		if over:
			return
	# Fame draws new men in spring.
	var wanted := Leader.recruits_drawn(rules, band)
	for i in wanted:
		if band.living_men().size() >= rules.recruit_cap:
			break
		var m := Recruits.random(rng.fork("recruit:%d:%d" % [cal.year, i]), rules, band.next_id())
		band.add_man(m)
		tally.recruits += 1
		if Potential.is_coal_biter(rules, m):
			tally.coal_biters += 1
		band.log("%s, a %s, swears to %s" % [m.display_name, CampaignTypes.ORIGIN_NAMES[m.origin], band.leader.display_name])
	if band.living_men().is_empty() and band.leader != null and band.leader.alive:
		band.log("%s winters alone" % band.leader.display_name)


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
	var leavers := Succession.succeed(rng.fork("succeed:%d" % cal.year), rules, band, cal, heir_man, feast, vow, death_cause, log)
	tally.departures += leavers.size()
	_pending_vow = vow


func summary() -> String:
	return "%d: %s leads %d men | battles %d won %d | dead %d maimed %d left %d joined %d | successions %d | luck %d fame %d honor %d%s" % [
		cal.year, band.leader.display_name if band.leader else "nobody", band.living_men().size(),
		tally.battles, tally.wins, tally.deaths, tally.maimed, tally.departures, tally.recruits,
		tally.successions, band.luck, band.fame, band.honor, (" | OVER: " + over_reason) if over else "",
	]
