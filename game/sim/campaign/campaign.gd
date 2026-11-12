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
## The grave-ale is the player's (Journey.played_succession): a leader's
## death waits in `pending_death` ({cause, year, name, age, killer}) for
## the death card and the grave-ale instead of passing the high seat at
## once. Off for the sandbox AI and the old callers.
var played_succession := false
var pending_death := {}
var _killer := ""

const MAX_FIGHTERS := 12
const ENEMY_FIRST_ID := 1001
## Ids of the men a friendly house sends to a barred hall (battles-2).
const HELP_FIRST_ID := 4001


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
## `about` (from the map, Journey._offer_fight) says what the fight is over:
## {cause, house, ships_here, can_burn, burning} (FightOffer), from which
## each choice's stake is set (`stake`).
func offer_fight(kind: String, enemy_tier: CombatTypes.Tier, enemy_size: int, attacking: bool, stat_center := -1,
		at_sea := false, cornered := false, ground := "", about := {}) -> FightOffer:
	tally.battles += 1
	var o := FightOffer.new()
	o.kind = kind
	o.ground = ground
	o.cause = str(about.get("cause", ""))
	o.house = str(about.get("house", ""))
	o.ships_here = bool(about.get("ships_here", false))
	o.can_burn = bool(about.get("can_burn", false))
	o.burning = bool(about.get("burning", false))
	o.great = about.get("great", {})
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
	# the other way about; your own raid is your own doing. At your own
	# hall a watchful scout can warn you in time to wait at the gate; nobody
	# is caught on the march there.
	if not at_sea and not cornered and not attacking:
		o.we_know_first = Scouting.spots_first(sr.fork("first"), rules, wits, tier)
		if not o.we_know_first and not foresight:
			o.they_know_first = sr.fork("caught").randf() < rules.caught_chance
	elif ground == "hall":
		o.we_know_first = bool(about.get("warned", false))  # the scout warned you as they came (WinterHall)
	o.report = Scouting.report(sr.fork("report"), rules, wits, tier, o)
	for ch in [FightOffer.Choice.TAKE_THE_FIELD, FightOffer.Choice.WAIT_FOR_THEM, FightOffer.Choice.LAY_AMBUSH, FightOffer.Choice.BURN]:
		o.stakes[ch] = str(stake(o, ch).text)
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
	var st := stake(offer, choice)
	if offer.cause == "strandhogg" and choice == FightOffer.Choice.TAKE_THE_FIELD:
		built = _strandhogg_fight(offer, ours, enemy, seed_in)
	elif not offer.great.is_empty():
		built = _sector_fight(offer, ours, enemy, seed_in)
	elif choice == FightOffer.Choice.BURN:
		built = Scenario.build_hall_burning(seed_in, combat_rules, {"ours": ours, "theirs": enemy})
	elif offer.ground == "hall":
		var how := "meet" if choice == FightOffer.Choice.TAKE_THE_FIELD else ("wait" if choice == FightOffer.Choice.LAY_AMBUSH else "bar")
		built = Scenario.build_hall_defence(seed_in, combat_rules, {"ours": ours, "theirs": enemy, "help": _hall_help(offer, how, seed_in)}, offer.burning, how)
	elif offer.ground == "sea":
		# Both afloat: the hulls lashed together, the side that came on boarding.
		built = Scenario.build_deck(seed_in, combat_rules, {"ours": ours, "theirs": enemy}, int(st.attacker), offer.doctrine)
	elif offer.ground != "" and offer.cause != "" and name != "ambush" and name != "ambushed":
		# What the fight is over (`stake`) sets the objective and the ground.
		pick.objective = int(st.kind)
		pick.attacker = int(st.attacker)
		built = Scenario.build("equal_green", seed_in, combat_rules, true, fighters.size(), str(st.template), {"ours": ours, "theirs": enemy}, pick)
	elif offer.ground != "" and name != "ambush" and name != "ambushed":
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
	if choice == FightOffer.Choice.WAIT_FOR_THEM or choice == FightOffer.Choice.BURN:
		ours_aggressive = false
	if offer.ground == "hall":
		ours_aggressive = choice == FightOffer.Choice.TAKE_THE_FIELD
	battle.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE if ours_aggressive else LeaderAI.Doctrine.STEADY))
	if (offer.they_know_first or choice == FightOffer.Choice.WAIT_FOR_THEM) and choice != FightOffer.Choice.BURN:
		battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	# His luck goes with him into the fight, when he is in it.
	if stallari == null and offer.cause != "":
		battle.set_luck(0, Leader.luck_modifier(rules, band))
	_give_wings(offer, choice, built, fighters)
	built.fighters = fighters
	built.house = offer.house
	built.stake = st
	built.choice = choice
	built.odds = float(fighters.size()) / maxf(1.0, float(offer.enemy_size))  # ours over theirs
	built.war_leader = stallari.id if stallari != null else -1
	return built


## What a choice's fight is over (concept.md, "Raids and skirmishes ...
## with objectives"), from the offer's cause and ground: {kind (an
## Objective.Kind, or -1 for an open field), attacker (the side that must
## come on), template (Field), text (a line for the offer, "" when there is
## nothing to take or hold)}. The ground decides first (your hall at night,
## the deck at sea, the Thing's booths), then the cause: a raid on a
## steading is its silver against the neighbours' coming, the farmers you
## stand with hold their yard, the ship-thieves have your ship, a robbery
## on land is the cargo, a fight on the strand where your ship lies is the
## ships; then the ground you chose to wait on, as before.
func stake(offer: FightOffer, choice: int) -> Dictionary:
	var cr := combat_rules
	var out := {"kind": -1, "attacker": 0, "template": "", "text": ""}
	if offer.they_know_first or (choice == FightOffer.Choice.LAY_AMBUSH and offer.ground != "hall"):
		return out
	var held := choice == FightOffer.Choice.WAIT_FOR_THEM
	if offer.cause == "strandhogg" and choice == FightOffer.Choice.TAKE_THE_FIELD:
		out.kind = Objective.Kind.CATTLE
		out.text = "Round up the cattle and drive them down to the boats before the district gathers: the first of them come in about %d rounds" % cr.strand_first_party
		return out
	if choice == FightOffer.Choice.BURN:
		out.kind = Objective.Kind.ESCAPE
		out.attacker = 1
		out.text = "Ring the hall in the dark and let none of their fighting men through the fire; the women and children go free"
		return out
	match offer.ground:
		"hall":
			out.attacker = 1
			out.kind = Objective.Kind.FIRE if offer.burning else Objective.Kind.THE_HALL
			out.text = ("They come with fire: drive them from the walls before the roof takes (%d rounds of fire)" % cr.fire_rounds) if offer.burning \
					else "They mean to take the hall: hold the door and the yard, %d rounds from contact" % cr.objective_hall_rounds
			return out
		"sea":
			out.kind = Objective.Kind.DECK
			out.attacker = 0 if offer.attacking else 1
			out.text = ("Lash the hulls together, board her and clear her deck from stem to stern, about %d rounds from contact" % cr.objective_deck_rounds) if offer.attacking \
					else "They will lash on and board: keep them off your deck, or cut loose"
			return out
		"thing":
			out.template = "meadow"
			return out
		"strand":
			out.template = "meadow"
		"farm":
			out.template = "farmstead"
		"hills":
			out.template = "hillside"
	if choice == FightOffer.Choice.TAKE_THE_FIELD:
		match offer.cause:
			"raid":
				if offer.ground == "farm":
					out.kind = Objective.Kind.PLUNDER
					out.attacker = 0
					out.text = "Take the hall before their neighbours come: about %d rounds from contact" % cr.objective_plunder_rounds
					return out
			"defend":
				out.kind = Objective.Kind.THE_HALL
				out.attacker = 1
				out.template = "farmstead"
				out.text = "Hold the yard with its farmers, %d rounds from contact" % cr.objective_hall_rounds
				return out
			"thieves":
				out.kind = Objective.Kind.REACH_THE_SHIPS
				out.attacker = 0
				out.template = "meadow"
				out.text = "Your ship is drawn up behind them: win through to her, %d rounds from contact" % cr.objective_ships_rounds
				return out
			"rob":
				out.kind = Objective.Kind.CARGO
				out.attacker = 0
				out.template = "meadow"
				out.text = "Get to the cargo before they make off with it, %d rounds from contact" % cr.objective_ships_rounds
				return out
		if offer.ground == "strand" and offer.ships_here:
			out.kind = Objective.Kind.REACH_THE_SHIPS
			out.attacker = 0 if offer.attacking else 1
			out.text = ("Their ships are drawn up on the strand: get to them, %d rounds from contact" % cr.objective_ships_rounds) if offer.attacking \
					else "Your ship lies on the strand behind you: keep them from her, %d rounds from contact" % cr.objective_ships_rounds
			return out
		return out
	if held:
		out.attacker = 1
		match offer.ground:
			"farm":
				out.kind = Objective.Kind.THE_HALL
				out.text = "Hold the hall, %d rounds from contact" % cr.objective_hall_rounds
			"hills":
				out.kind = Objective.Kind.HOLD_GROUND
				out.text = "Hold the high bank, %d rounds from contact" % cr.objective_ford_rounds
			_:
				out.kind = Objective.Kind.HOLD_GROUND
				out.template = "river"
				out.text = "Keep them off the ford, %d rounds from contact" % cr.objective_ford_rounds
	return out


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
func build_duel(opponent: Warrior, seed_in: int, champion: Man = null) -> Dictionary:
	tally.battles += 1
	tally.duels = tally.get("duels", 0) + 1
	# A champion may stand on the island in the leader's place.
	var who: Man = champion if champion != null else band.leader
	var fighters: Array[Man] = [who]
	var ours: Array[Warrior] = [who.to_warrior(0, rules, 0)]
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


## Out of the band's own burning hall (WinterHall, the roof taken): the
## leader and his men break out through the door into the ring of `left`
## of `against`'s men (Scenario.build_breakout, the escape as a fight of
## the saga: the leader is not spared). Returns `build_fight`'s
## dictionary with its `offer` (at the ground "hall", cause "breakout").
func build_breakout(against: String, left: int, tier: int) -> Dictionary:
	var offer := offer_fight("the fire at the hall", tier as CombatTypes.Tier, left, false, -1, false, true, "hall",
			{"cause": "breakout", "house": against})
	var fighters := band.fighters(rules)
	if fighters.size() > MAX_FIGHTERS:
		fighters = fighters.slice(0, MAX_FIGHTERS)
	var ours: Array[Warrior] = []
	for m in fighters:
		ours.append(m.to_warrior(0, rules, 0))
	var seed_in := offer.seed_value
	var theirs := BandFactory.make_mixed_band(SimRng.new(seed_in).fork("burners"), 1, maxi(1, left - left / 4), left / 4, 0,
			tier as CombatTypes.Tier, combat_rules, CombatTypes.Armor.NONE, 3, ENEMY_FIRST_ID)
	var built := Scenario.build_breakout(seed_in, combat_rules, {"ours": ours, "theirs": theirs, "leader_name": against.trim_suffix("'s kin")})
	(built.battle as Battle).set_luck(0, Leader.luck_modifier(rules, band))
	built.fighters = fighters
	built.choice = FightOffer.Choice.TAKE_THE_FIELD
	built.odds = float(fighters.size()) / maxf(1.0, float(theirs.size()))
	built.house = against
	built.offer = offer
	built.stake = {"kind": Objective.Kind.ESCAPE, "attacker": 0, "template": "", "text": "Get out through their ring into the dark"}
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
	if not is_escape:
		tally["outcome:%d" % outcome] = int(tally.get("outcome:%d" % outcome, 0)) + 1
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
	var told := Aftermath.apply(rules, band, ours, result, SimRng.new(seed_in).fork("aftermath"), on_land, log, room())
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
	# On the map a vengeance is opened against the house the killers belong
	# to, or none (raiders, outlaws: a grudge, not a feud); the plain
	# campaign keeps its old ways (Bonds.on_death).
	var house: String = str(built.get("house", "")) if world != null else Bonds.OLD_WAYS
	for m in fallen:
		Bonds.on_death(rules, band, m, killer, log, house)
		Chronicle.fell(band, m, cal.year)
		if m != band.leader:
			band.remove_man(m)

	# Luck, reputation, plunder. Getting out of the burned hall is none of
	# these: the saga begins there, it is not judged by it.
	if not is_duel and not is_escape:
		var fame_before := band.fame
		var luck_before := band.luck
		var front := led_from_front(built, result)
		Leader.on_battle(rules, band, won, front, built.odds, log, outcome, SimRng.new(seed_in).fork("luck"))
		# Under the war-leader the fight is his as much as the leader's.
		if int(built.get("war_leader", -1)) >= 0 and band.fame > fame_before:
			band.fame -= (band.fame - fame_before) - roundi((band.fame - fame_before) * rules.war_leader_fame_share)
		if offer != null and offer.cause != "" and band.leader != null and band.leader.alive:
			var tl: PackedStringArray = told.lines
			tl.append_array(luck_lines(front, luck_before))
			told.lines = tl
	if won and not is_duel and not is_escape:
		_summer_wins += 1
		tally.wins += 1
		var flat := rules.plunder_per_win if world == null else rules.plunder_per_win_world
		# A raid that had the field but never stood in the hall goes with less.
		flat = roundi(flat * plunder_share(result))
		band.silver += flat
		Loyalty.share_plunder(rules, band, flat, rules.fair_leader_share, log)
		for m in band.living_men():
			if m.ambition == CampaignTypes.Ambition.SILVER or m.ambition == CampaignTypes.Ambition.FAME:
				Loyalty.ambition_progress(rules, band, m, rules.ambition_per_win, log)
	if band.leader != null and not band.leader.alive:
		_killer = killer
		succession("battle")
	return told


## The most men the band can keep (CampaignRules.room_min/room_max): the
## seats of its hall or the crew of its hull, whichever is more. Without a
## map, the plain campaign's `recruit_cap`. A man who would come beyond it
## (a recruit, a hired man, one who saw the fight) is turned away.
func room() -> int:
	if world == null or world_rules == null:
		return rules.recruit_cap
	var seats := rules.hall_base_seats
	if band.hall != null:
		seats = maxi(seats, (band.hall as Hall).seats)
	var crew := band.ship.crew_capacity(world_rules) if band.ship != null else 0
	var most := rules.room_max if band.rank >= WorldTypes.Rank.HERSIR else rules.room_max_karl
	return clampi(maxi(seats, crew), rules.room_min, most)


## Whether the leader stood in the front rank (concept.md, "Your
## character"): in a fight where his men came to blows, he spent
## `front_contact_rounds` rounds at arm's length of the enemy, or struck a
## blow, or went down. When the war-leader leads the wall in his place he
## is honestly not there (his share of the fame is less already), and a
## fight nobody closed in hangs nobody back.
func led_from_front(built: Dictionary, result: BattleResult) -> bool:
	if int(built.get("war_leader", -1)) >= 0 or band.leader == null:
		return true
	var mine: Warrior = null
	var blows := false
	for w: Warrior in built.ours:
		if w.id == band.leader.id:
			mine = w
		if w.contact_rounds > 0 or w.strikes > 0:
			blows = true
	if mine == null or not blows:
		return true
	return mine.is_down() or mine.strikes > 0 or mine.contact_rounds >= rules.front_contact_rounds


## What the men say of their leader's luck after a fight of the saga, in
## the result's words: "the men say his luck holds", or that he hung back.
func luck_lines(front: bool, luck_before: int) -> PackedStringArray:
	var out := PackedStringArray()
	var who := band.leader.display_name if band.leader != null else "The leader"
	if not front:
		out.append("Men saw %s keep back from the shield-wall, and they speak of it." % who)
	if band.luck > luck_before:
		out.append("The men say %s's luck holds." % who if band.luck < rules.luck_high else "The men say %s's luck is a thing to follow." % who)
	elif band.luck < luck_before:
		out.append("The men mutter that %s's luck is turning." % who if band.luck > rules.luck_low else "The men say %s's luck has left him." % who)
	return out


## The share of a won fight's plunder the band carries off: all of it,
## but for a raid on a steading that had the field when the neighbours
## came and never stood in the hall (Objective.Kind.PLUNDER, not taken).
func plunder_share(result: BattleResult) -> float:
	if result.objective_kind == Objective.Kind.PLUNDER and result.winner == 0 and not result.taken \
			and result.how != BattleResult.End.ROUT:
		return rules.raid_late_share
	return 1.0


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
		if ev.get("recruit_request", false) and band.living_men().size() < room():
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
	Family.old_folk_year(rng.fork("old_folk:%d" % cal.year), rules, band, cal, log)
	for m in band.fighters():
		Growth.winter_age(rng.fork("age:%d:%d" % [cal.year, m.id]), rules, m, log)
		Growth.apply_growth(rules, m, log)
	Bonds.winter_drift(rng.fork("bonds:%d" % cal.year), rules, band, log)
	if world != null:
		Leader.winter_drift(rules, band, log)
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
			log.append("%s comes back from %s kin at the thaw." % [m.display_name, m.his()])
		else:
			tally.departures += 1
			log.append("%s stays with %s kin, and does not come back." % [m.display_name, m.his()])
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
		if band.living_men().size() >= room():
			break
		var m := Recruits.random(rng.fork("recruit:%d:%d" % [cal.year, i]), rules, band.next_id())
		band.add_man(m)
		_arm_new_men()
		tally.recruits += 1
		if Potential.is_coal_biter(rules, m):
			tally.coal_biters += 1
		band.log("%s, %s, swears to %s" % [m.display_name, CampaignTypes.a_origin(m.origin), band.leader.display_name])
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
	if played_succession:
		# The player holds the grave-ale (Journey: the death card, then the
		# heir, the feast and the vow): the death waits for it.
		if pending_death.is_empty() and old != null:
			pending_death = {"cause": death_cause, "year": cal.year, "name": old.display_name, "age": old.age,
					"killer": _killer if death_cause == "battle" else "", "winter": cal.is_winter()}
			log.append("%s is dead" % old.display_name)
		_killer = ""
		return
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


# --- Battles 2 (docs/design/notes/battles-2.md) ------------------------------------

## The strandhogg fought (Scenario.build_strandhogg): the first
## `strand_herders` of the enemy are the herders by the farm, their first
## the man who leads them; the rest come in `strand_parties` parties on the
## clock, the district gathering. The leader AI's greed is the band's
## `strand_greed` (CampaignRules).
func _strandhogg_fight(offer: FightOffer, ours: Array[Warrior], enemy: Array[Warrior], seed_in: int) -> Dictionary:
	var h := mini(rules.strand_herders, enemy.size())
	var herders: Array[Warrior] = []
	var rest: Array[Warrior] = []
	for i in enemy.size():
		if i < h:
			herders.append(enemy[i])
		else:
			var w: Warrior = enemy[i]
			w.is_leader = false
			w.is_banner = false
			w.is_horn = false
			rest.append(w)
	# The parties grow as the district gathers: the k-th takes a share of
	# the rest in proportion to k + 1 (Journey._strandhogg sized them so).
	var n := maxi(1, combat_rules.strand_parties)
	var parties: Array = []
	var weights := 0
	for k in n:
		weights += k + 1
	var at := 0
	for k in n:
		var take := rest.size() - at if k == n - 1 else roundi(float(rest.size()) * (k + 1) / weights)
		var party: Array[Warrior] = []
		for i in range(at, mini(rest.size(), at + take)):
			party.append(rest[i])
		at += take
		if not party.is_empty():
			parties.append(party)
	return Scenario.build_strandhogg(seed_in, combat_rules, {"ours": ours, "herders": herders, "parties": parties},
			ours.size(), rules.strand_greed)


## A great battle's sector (Scenario.build_sector) from the offer's
## parameters (FightOffer.great); the enemy's leader AI is the offer's.
func _sector_fight(offer: FightOffer, ours: Array[Warrior], enemy: Array[Warrior], seed_in: int) -> Dictionary:
	var p := offer.great.duplicate()
	if not p.has("doctrine"):
		p.doctrine = offer.doctrine
	return Scenario.build_sector(seed_in, combat_rules, {"ours": ours, "theirs": enemy}, p)


## The barred hall's hope (battles-2, Scenario._bar_the_door): the
## friendliest house the band has (Families: the best standing among the
## houses that are its friends) sends men out of the dark if the door
## holds, `hall_help_men` of them plus one for every `hall_help_per` of
## standing over the friend's mark, up to `hall_help_max`; none when it has
## no friend. Only when the door is barred against fire. {} for none, else
## {men, line, house}.
func _hall_help(offer: FightOffer, how: String, seed_in: int) -> Dictionary:
	if not offer.burning or how != "bar" or world == null or world.families == null or world_rules == null:
		return {}
	var best := ""
	var best_st := -999
	for name in world.families.names():
		if name == offer.house or not Families.is_friend(world_rules, band, name):
			continue
		var st := Families.standing(band, name)
		if st > best_st or (st == best_st and name < best):
			best = name
			best_st = st
	if best == "":
		return {}
	var n := mini(rules.hall_help_max, rules.hall_help_men + maxi(0, best_st - world_rules.standing_friend) / maxi(1, rules.hall_help_per))
	var men := Scenario.hands(SimRng.new(seed_in).fork("hall-help"), 0, n, CombatTypes.Tier.BLOODED, combat_rules, HELP_FIRST_ID, 30)
	return {"men": men, "house": best, "line": "%s's men come out of the dark with torches and spears, {n} of them" % best.trim_suffix("'s kin")}


## The named lieutenants (Wing): in a fight with `wing_min_line` men or
## more in the line, the band's sworn second (and in a band of
## `wing_third_band` men or more, the best of the rest) commands a wing,
## with the word a sensible leader would give for the fight before him
## (Wing.sensible_word); the player may change it on the battle screen's
## sheet (`built.wings`). The enemy's named men do the same, by their
## leader's doctrine, where the enemy is a named house or a king's. Not in
## the fights fought at doors and walls, a ring, a strandhogg or a column
## caught on the march.
func _give_wings(offer: FightOffer, choice: int, built: Dictionary, fighters: Array[Man]) -> void:
	var battle: Battle = built.battle
	if choice == FightOffer.Choice.BURN or offer.ground == "hall" or offer.cause == "strandhogg" or offer.they_know_first:
		return
	var ours: Array[Warrior] = built.ours
	if ours.size() >= combat_rules.wing_min_line:
		var picks: Array[Man] = []
		var second := band.man_by_id(band.sworn_second_id)
		if second != null and fighters.has(second):
			picks.append(second)
		if not picks.is_empty() and band.living_men().size() >= rules.wing_third_band:
			var third: Man = null
			for m in fighters:
				if m == band.leader or picks.has(m) or m.role == CombatTypes.Role.MISSILE:
					continue
				if third == null or [m.tier, m.stat(CombatTypes.Stat.WITS) + m.stat(CombatTypes.Stat.NERVE), -m.id] > [third.tier, third.stat(CombatTypes.Stat.WITS) + third.stat(CombatTypes.Stat.NERVE), -third.id]:
					third = m
			if third != null:
				picks.append(third)
		var lts: Array[Warrior] = []
		var tempers := []
		var words := []
		var lead := battle.sworn_leader(0)
		for m in picks:
			for w in ours:
				if w.id == m.id and w != lead:
					var t := Wing.temper_of(m.personality, m.traits, m.stat(CombatTypes.Stat.WITS))
					lts.append(w)
					tempers.append(t)
					words.append(Wing.sensible_word(offer.doctrine, offer.attacking or choice == FightOffer.Choice.LAY_AMBUSH, t))
		if not lts.is_empty():
			Wing.form(battle, 0, lts, words, tempers)
			built.wings = true
	var theirs: Array[Warrior] = built.theirs
	if (offer.house != "" or not offer.great.is_empty()) and theirs.size() >= combat_rules.wing_min_line:
		var pool := []
		for w in theirs:
			if not w.is_leader and w.role != CombatTypes.Role.MISSILE:
				pool.append([-(w.nerve + w.wits), w.id, w])
		pool.sort()
		var elts: Array[Warrior] = []
		var et := []
		var ew := []
		for i in mini(2 if theirs.size() >= rules.wing_third_band else 1, pool.size()):
			var w: Warrior = pool[i][2]
			var t := Wing.temper_of(w.personality, PackedStringArray(), w.wits)
			elts.append(w)
			et.append(t)
			ew.append(Wing.doctrine_word(offer.doctrine, t))
		if not elts.is_empty():
			Wing.form(battle, 1, elts, ew, et)
