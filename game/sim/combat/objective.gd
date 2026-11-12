class_name Objective
extends RefCounted
## Something on the field worth fighting over, so that one side must come on
## and the other must stand (concept.md, eighth playtest: on an open field
## the side that waits is favoured). The attacker has a task and a deadline;
## the defender wins by keeping him from it until the time runs out. The
## lines can still break first: Battle checks the objective before its own
## end checks each round, and they stay as they were.
##
##   HOLD_GROUND     the ford: a stream across the field directly before
##                   the defender's line, so his line is the bank; WATER but
##                   for its crossings (fords, and sometimes a bridge), which
##                   are the objective. When the clock runs out the
##                   attacker has it if `ford_men` of his standing men are
##                   on the crossing or over it, on the defender's bank: a
##                   foothold he has not been thrown back from. Fewer, and
##                   the defender keeps it. A man in the ford locks with
##                   nobody, so the bank is the place to hold it from.
##   REACH_THE_SHIPS the ships: a strip behind the defender's line. The
##                   attacker wins the moment `ships_men` of his standing men
##                   are on it; the defender wins if `rounds` pass first.
##   THE_HALL        the hall: a building behind the defender's ranks, its
##                   walls BUILDING and its doors (DOOR) toward the fight;
##                   the objective is the doors and the floor inside. The
##                   attacker wins once he has stood on at least half of them
##                   for `hall_streak` rounds running; else the defender.
##   ESCAPE          the burned hall (Scenario.build_escape): the attacker
##                   is not taking anything but getting out. The cells are
##                   the edge of the dark (the tree line); the fight ends
##                   the round his sworn leader stands on one of them, or
##                   slips away out of contact near it (Battle.withdraw), or
##                   goes down (his men drag him off, or he is left for
##                   dead), or his men all break and scatter into the night.
##                   Every one of those is an escape (BattleResult.End.ESCAPE):
##                   the fight cannot be won here, only left. It has no clock.
##
## The clock: `rounds` are counted from the round the lines meet
## (Battle.lines_met: a man of one side at arm's length of the other), not
## from the first round, so the walk across the field, a green wall's
## hesitations and the ground in the way cost the attacker nothing. An
## attacker who has not closed by `approach_rounds` has given the day up.
##
## Built from a seed and a kind; `place` draws its ground on a grid and
## lists every cell it drew in `features` (Field keeps its own features off
## them). Deterministic like the rest.

enum Kind { HOLD_GROUND, REACH_THE_SHIPS, THE_HALL, ESCAPE }

const NAMES := ["the ford", "the ships", "the hall", "the dark"]
const SHORT := ["ford", "ships", "hall", "the dark"]
## The kinds a varied field may draw (Scenario.build): the escape is only
## ever built on purpose.
const DRAWN_KINDS := 3

var kind: Kind
var attacker := 0
var cells: Array[Vector2i] = []
## Every cell `place` drew, the objective's own and its ground round it
## (the stream's water, the hall's walls).
var features: Array[Vector2i] = []
var rounds := 16
## The round the lines met and the clock started; -1 while they have not.
var clock_start := -1
## The attacker's time to close with the defender before the day is given up.
var approach_rounds := 24
var name := ""
var ships_men := 4
## The foothold over the stream that takes the ford, sized like the ships'.
var ford_men := 4
var ships_depth := 3  # rows behind the defender's front the ships lie
var hall_streak := 2
## Set when `check` decides: the finish line for the log ("side 0 takes the hall").
var reason := ""
## The ford: the stream's row and which way the defender's rear lies from it.
var stream_row := -1
var back := 0
var _seed := 0
var _streak := 0  # rounds running the attacker has held the hall
var _checked_round := -1
var _decision := -1


func _init(p_kind: Kind, p_attacker: int, seed_in: int, rules: CombatRules = null) -> void:
	kind = p_kind
	attacker = p_attacker
	_seed = seed_in
	name = NAMES[kind]
	var r := rules if rules != null else CombatRules.new()
	ships_depth = r.objective_ships_depth
	ships_men = r.objective_ships_men
	ford_men = r.objective_ships_men
	hall_streak = r.objective_hall_streak
	approach_rounds = r.objective_approach_rounds
	match kind:
		Kind.HOLD_GROUND:
			rounds = r.objective_ford_rounds
		Kind.REACH_THE_SHIPS:
			rounds = r.objective_ships_rounds
		Kind.THE_HALL:
			rounds = r.objective_hall_rounds


## Sizes the ships' task and the ford's foothold to a band of `band` men: a
## share of it (`objective_ships_fraction`, rounded up), never fewer than
## `objective_ships_min_men`. The hall scales already: half its cells.
func size_for_band(band: int, rules: CombatRules) -> void:
	ships_men = maxi(rules.objective_ships_min_men, ceili(band * rules.objective_ships_fraction - 0.0001))
	ford_men = maxi(rules.objective_ships_min_men, ceili(band * rules.objective_ford_fraction - 0.0001))


func defender() -> int:
	return 1 - attacker


func short_name() -> String:
	return SHORT[kind]


## Whether the clock has started: the lines have met.
func clock_running() -> bool:
	return clock_start >= 0


## Rounds of the clock run so far; 0 the round the lines meet, -1 before.
func elapsed(battle: Battle) -> int:
	return -1 if clock_start < 0 else battle.round - clock_start


## Rounds the attacker has left: all of them until the lines meet.
func rounds_left(battle: Battle) -> int:
	return rounds if clock_start < 0 else maxi(0, rounds - elapsed(battle))


## Draws the objective on `grid`. `front_row` is the defender's front line
## (offset row), `back` is +1 or -1, the way his rear lies (toward his edge
## of the map), `centre_col` the column his leader stands on. Drawn from the
## seed:
##
## - the ford: a stream across the whole field on the row in front of his
##   line (his line stands on the bank), crossed by one ford four hexes
##   wide or two fords two wide, and two times in five a one-hex bridge out
##   on a flank: four or five crossing hexes, which are the objective.
##   Whoever wants the ford must come through the water to the bank.
## - the ships: a strip of eight to ten hexes `ships_depth` rows behind his
##   front (or on his edge row, if that is nearer).
## - the hall: one or two hexes of floor four rows behind his front (or on
##   his edge row), ringed by its walls; one or two of the ring's hexes on
##   the side toward the fight are doors. Four to six walls, and the doors
##   and floor are the objective. On the smallest fields its front wall
##   stands on his third rank's row; it is drawn before anyone deploys, so
##   the men who would have stood there stand elsewhere.
func place(grid: BattleGrid, front_row: int, p_back: int, centre_col: int) -> void:
	var back := p_back
	var r := SimRng.new(_seed).fork("objective-cells")
	cells.clear()
	features.clear()
	match kind:
		Kind.HOLD_GROUND:
			stream_row = clampi(front_row - back, 0, grid.height - 1)
			self.back = p_back
			_place_ford(grid, r, stream_row, centre_col)
		Kind.REACH_THE_SHIPS:
			var n := r.randi_range(8, 10)
			var left := -(n / 2)
			# A strip objective_ships_depth rows behind the defender's front, or
			# at the field's edge if that is nearer.
			var edge_row := (grid.height - 1) if back > 0 else 0
			var depth := mini(ships_depth, absi(edge_row - front_row))
			for i in n:
				var col := clampi(centre_col + left + i, 0, grid.width - 1)
				_mark(grid, BattleGrid.from_offset(col, front_row + depth * back), CombatTypes.Terrain.FLAT, true)
		Kind.THE_HALL:
			_place_hall(grid, r, front_row, back, centre_col)


## The escape's edge of the dark: every passable hex of offset row `row`.
## The ground itself (the trees beyond, the burning hall) is the
## scenario's to draw.
func place_escape(grid: BattleGrid, row: int) -> void:
	cells.clear()
	features.clear()
	for col in grid.width:
		var c := BattleGrid.from_offset(col, row)
		if grid.is_passable(c):
			cells.append(c)
			features.append(c)


## The escape: hexes from `c` to the nearest edge of the dark.
func dark_distance(c: Vector2i) -> int:
	var best := 99
	for e in cells:
		best = mini(best, BattleGrid.distance(c, e))
	return best


## The escape: hexes from the escaper's sworn leader to the dark, or 99
## when he is not on the field.
func leader_distance(battle: Battle) -> int:
	var l := battle.sworn_leader(attacker)
	if l == null or not l.is_active():
		return 99
	return dark_distance(l.pos)


## The escape: the way to the dark is open when no standing man of the
## burners is nearer it than the escaper's leader: he is through the ring.
func way_open(battle: Battle) -> bool:
	var mine := leader_distance(battle)
	if mine >= 99:
		return false
	for w in battle.active(defender()):
		if not w.broken and dark_distance(w.pos) < mine:
			return false
	return true


## Whether `side` may leave the field in order now (Battle.can_withdraw).
## Only the escape says no: its band slips away only once it is through
## the ring (`way_open`), so the way out is fought for.
func allows_withdraw(battle: Battle, side: int) -> bool:
	if kind != Kind.ESCAPE or side != attacker:
		return true
	return way_open(battle)


func _mark(grid: BattleGrid, c: Vector2i, t: CombatTypes.Terrain, is_objective: bool) -> void:
	if not grid.in_bounds(c) or features.has(c):
		return
	grid.set_terrain(c, t)
	features.append(c)
	if is_objective:
		cells.append(c)


func _place_ford(grid: BattleGrid, r: SimRng, row: int, centre_col: int) -> void:
	var crossing := stream_crossings(r, grid.width, centre_col)
	var cols := crossing.keys()
	cols.sort()
	for col in cols:
		_mark(grid, BattleGrid.from_offset(col, row), crossing[col], true)
	for col in grid.width:
		if not crossing.has(col):
			_mark(grid, BattleGrid.from_offset(col, row), CombatTypes.Terrain.WATER, false)


## Where a stream across a field `width` wide can be crossed, as column ->
## Terrain (FORD or BRIDGE): one ford four hexes wide about `centre_col`, or
## two fords two wide either side of it, and two times in five a one-hex
## bridge out on a flank. Every other column of the stream is WATER.
static func stream_crossings(r: SimRng, width: int, centre_col: int) -> Dictionary:
	var crossing := {}
	if r.randf() < 0.5:
		var start := clampi(centre_col - 2 + r.randi_range(-1, 1), 0, width - 4)
		for i in 4:
			crossing[start + i] = CombatTypes.Terrain.FORD
	else:
		var a := clampi(centre_col - r.randi_range(3, 5), 0, width - 2)
		var b := clampi(centre_col + r.randi_range(2, 4), a + 3, width - 2)
		for col in [a, a + 1, b, b + 1]:
			crossing[col] = CombatTypes.Terrain.FORD
	if r.randf() < 0.4:
		var sgn := -1 if r.randf() < 0.5 else 1
		var col := clampi(centre_col + sgn * r.randi_range(6, 8), 0, width - 1)
		if not crossing.has(col) and not crossing.has(col - 1) and not crossing.has(col + 1):
			crossing[col] = CombatTypes.Terrain.BRIDGE
	return crossing


func _place_hall(grid: BattleGrid, r: SimRng, front_row: int, back: int, centre_col: int) -> void:
	var edge_row := (grid.height - 1) if back > 0 else 0
	var floor_row := front_row + mini(4, absi(edge_row - front_row)) * back
	var shape := hall_shape(grid, r, floor_row, back, centre_col)
	for c in shape.doors:
		_mark(grid, c, CombatTypes.Terrain.DOOR, true)
	for c in shape.floor:
		_mark(grid, c, CombatTypes.Terrain.FLAT, true)
	for c in shape.walls:
		_mark(grid, c, CombatTypes.Terrain.BUILDING, false)


## A hall's ground: one or two hexes of `floor` on `floor_row` about
## `centre_col`, ringed by its `walls`, with one or two `doors` in the ring
## on the row toward the fight (`back` is +1 when the hall's rear is down
## the field). One floor hex has two hexes of its ring toward the fight and
## one or two doors; two have three and two doors: four to six walls on an
## open field, fewer where the ring runs off the edge.
static func hall_shape(grid: BattleGrid, r: SimRng, floor_row: int, back: int, centre_col: int) -> Dictionary:
	var m := r.randi_range(1, 2)
	var floor_cells: Array[Vector2i] = []
	for i in m:
		floor_cells.append(BattleGrid.from_offset(clampi(centre_col - (m - 1) / 2 + i, 0, grid.width - 1), floor_row))
	var ring: Array[Vector2i] = []
	var front_ring: Array[Vector2i] = []
	for f in floor_cells:
		for d in BattleGrid.DIRS:
			var c: Vector2i = f + d
			if floor_cells.has(c) or ring.has(c) or not grid.in_bounds(c):
				continue
			ring.append(c)
			if c.y == floor_row - back:
				front_ring.append(c)
	front_ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var doors: Array[Vector2i] = []
	var n_doors := 2 if m == 2 else r.randi_range(1, 2)
	if front_ring.size() <= n_doors:
		doors = front_ring.duplicate()
	elif n_doors == 1:
		doors.append(front_ring[r.randi_range(0, front_ring.size() - 1)])
	else:
		var skip := r.randi_range(0, front_ring.size() - 1)
		for i in front_ring.size():
			if i != skip and doors.size() < n_doors:
				doors.append(front_ring[i])
	var walls: Array[Vector2i] = []
	for c in ring:
		if not doors.has(c):
			walls.append(c)
	return {"floor": floor_cells, "doors": doors, "walls": walls}


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


## A side's standing men on the crossing or over the stream, on the other
## side's bank. Before `place`, the men on the crossing itself.
func ford_count(battle: Battle, side: int) -> int:
	if stream_row < 0 or back == 0:
		return men_on(battle, side)
	# The defender's bank lies `back` of the stream; the attacker's the other way.
	var over := back if side == attacker else -back
	var n := 0
	for w in battle.active(side):
		if w.broken:
			continue
		if has_cell(w.pos) or (BattleGrid.to_offset(w.pos).y - stream_row) * over > 0:
			n += 1
	return n


## Standing (active, unbroken) men of `side` on the objective's cells.
func men_on(battle: Battle, side: int) -> int:
	var n := 0
	for c in cells:
		var w := battle.grid.occupant(c)
		if w != null and w.side == side and w.is_active() and not w.broken:
			n += 1
	return n


## What it asks of a side, in a line ("Take the hall before round 18").
func brief(side: int) -> String:
	var attacking := side == attacker
	match kind:
		Kind.HOLD_GROUND:
			return ("Get %d men over the ford, %d rounds from contact" % [ford_men, rounds]) if attacking else ("Keep them off the ford, %d rounds from contact" % rounds)
		Kind.REACH_THE_SHIPS:
			return ("Get %d men to the ships, %d rounds from contact" % [ships_men, rounds]) if attacking else ("Keep them from the ships, %d rounds from contact" % rounds)
		Kind.ESCAPE:
			return "Get out: reach the dark beyond their ring" if attacking else "Let none of them out of the fire"
		_:
			return ("Take the hall, %d rounds from contact" % rounds) if attacking else ("Hold the hall, %d rounds from contact" % rounds)


## The clock for the HUD: "12 left" once the lines have met, else how long
## the attacker will have ("16 once they meet").
func clock_text(battle: Battle) -> String:
	if kind == Kind.ESCAPE:
		return ""
	if clock_start < 0:
		return "%d once they meet" % rounds
	return "%d left" % rounds_left(battle)


## The state of play for the HUD ("hall: 2 of 5 held, round 9 of 18").
func progress(battle: Battle) -> String:
	match kind:
		Kind.HOLD_GROUND:
			return "ford %d/%d" % [ford_count(battle, attacker), ford_men]  # attackers on or over the crossing
		Kind.REACH_THE_SHIPS:
			return "ships %d/%d" % [men_on(battle, attacker), ships_men]
		Kind.ESCAPE:
			var d := leader_distance(battle)
			return "the dark: %d away" % d if d < 99 else ""
		_:
			return "hall %d/%d" % [men_on(battle, attacker), cells.size()]


## -1 while undecided, else the winning side. Call once a round, after the
## round is fought (Battle does, before its own end checks); a second call in
## the same round returns the same answer without counting again.
func check(battle: Battle) -> int:
	if battle.round == _checked_round:
		return _decision
	_checked_round = battle.round
	if kind == Kind.ESCAPE:
		_decision = _decide_escape(battle)
		return _decision
	if clock_start < 0 and battle.lines_met():
		clock_start = battle.round
		battle.log.append("the lines meet: %d rounds for side %d to take %s" % [rounds, attacker, name])
	_decision = _decide(battle)
	return _decision


func _decide(battle: Battle) -> int:
	if clock_start < 0:
		if battle.round >= approach_rounds:
			reason = "side %d never comes on: %s is side %d's" % [attacker, name, defender()]
			return defender()
		return -1
	var a := men_on(battle, attacker)
	var left := rounds_left(battle)
	match kind:
		Kind.HOLD_GROUND:
			if left > 0:
				return -1
			if ford_count(battle, attacker) >= ford_men:
				reason = "side %d is over the ford in strength" % attacker
				return attacker
			reason = "the ford is held: side %d keeps it" % defender()
			return defender()
		Kind.REACH_THE_SHIPS:
			if a >= ships_men:
				reason = "side %d reaches the ships" % attacker
				return attacker
		Kind.THE_HALL:
			_streak = _streak + 1 if a * 2 >= cells.size() and a > 0 else 0
			if _streak >= hall_streak:
				reason = "side %d takes the hall" % attacker
				return attacker
	if left <= 0:
		reason = time_up_reason()
		return defender()
	return -1


## The escape (see the header): -1 while the band is still in the ring,
## else the side left holding the field (the defender: the hall is his),
## with `reason` saying how the band got out. Battle ends it as an ESCAPE.
func _decide_escape(battle: Battle) -> int:
	var l := battle.sworn_leader(attacker)
	if l == null:
		return -1
	if l.fled:
		reason = "%s runs for the dark and is gone" % l.display_name
		return defender()
	if l.is_down():
		var carriers := 0
		for w in battle.active(attacker):
			if not w.broken:
				carriers += 1
		if carriers > 0:
			reason = "%s is down: his men drag him off into the dark" % l.display_name
		else:
			reason = "%s is down and left for dead in the yard" % l.display_name
		return defender()
	if has_cell(l.pos) and not l.broken:
		reason = "%s gets out into the dark" % l.display_name
		return defender()
	var standing := 0
	for w in battle.active(attacker):
		if not w.broken:
			standing += 1
	if standing == 0:
		reason = "%s's men break and scatter into the night" % l.display_name
		return defender()
	return -1


## The finish line when the time runs out on the attacker.
func time_up_reason() -> String:
	match kind:
		Kind.HOLD_GROUND:
			return "the ford is held: side %d keeps it" % defender()
		Kind.REACH_THE_SHIPS:
			return "the ships are safe: side %d holds them" % defender()
		Kind.ESCAPE:
			return "nobody comes after them: side %d gets away into the dark" % attacker
		_:
			return "the hall stands: side %d holds it" % defender()


## What an AI leader's men hear when the objective changes his order.
func ai_line(leader_name: String, attacking: bool) -> String:
	if kind == Kind.ESCAPE:
		return "%s will let none of them out of the fire" % leader_name if not attacking else "%s makes for the dark" % leader_name
	if attacking:
		match kind:
			Kind.HOLD_GROUND:
				return "%s will not leave the ford to them" % leader_name
			Kind.REACH_THE_SHIPS:
				return "%s makes for the ships" % leader_name
			_:
				return "%s means to see the hall burn" % leader_name
	return "%s keeps to %s: let them come to him" % [leader_name, name]


## The careful way out of the burned hall, as the tutorial teaches it
## (view/tutorial.gd) and as the dice tell it when the player skips it
## (Journey.skip_escape): the wall on the first round, then push at the
## ring until the way to the dark is open (`way_open`), then fall back
## toward the dark with the shields to the men coming after. The caller
## withdraws whenever Battle.can_withdraw allows it.
static func escape_order(battle: Battle, side: int) -> CombatTypes.Shout:
	var obj := battle.objective
	if battle.round == 0:
		return CombatTypes.Shout.SHIELD_WALL
	if obj != null and obj.kind == Kind.ESCAPE and obj.way_open(battle):
		return CombatTypes.Shout.FALL_BACK
	return CombatTypes.Shout.PUSH
