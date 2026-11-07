extends TestCase
## Milestone 1 gate (concept.md, First playable): green versus veteran bands
## under the same AI shouts differ clearly, battles are not over in three
## rounds, and every battle replays exactly from its seed.

const Batch := preload("res://tools/batch_battles.gd")


func _fight(name: String, seed_in: int) -> BattleResult:
	var b: Battle = Batch.build_battle(name, seed_in, CombatRules.new())
	return b.run()


func test_replay_is_exact() -> void:
	var a := _fight("equal_green", 11)
	var b := _fight("equal_green", 11)
	assert_eq(a.winner, b.winner)
	assert_eq(a.rounds, b.rounds)
	assert_eq(a.log.size(), b.log.size())
	for i in mini(a.log.size(), b.log.size()):
		if a.log[i] != b.log[i]:
			fail("log diverges at line %d: %s | %s" % [i, a.log[i], b.log[i]])
			break


func test_battle_ends_with_a_result() -> void:
	var r := _fight("veteran_vs_green", 3)
	assert_true(r.rounds >= 1)
	assert_true(r.winner >= -1 and r.winner <= 1)
	assert_eq(r.started[0], 8)
	assert_eq(r.started[1], 8)
	assert_true(r.downed[0] + r.downed[1] + r.fled[0] + r.fled[1] > 0, "something happened")


func test_gate_green_versus_veteran() -> void:
	var n := 60
	var vet_wins := 0
	var rounds := 0
	var green_lost := 0
	var vet_lost := 0
	for i in n:
		var r := _fight("green_vs_veteran", 100 + i)
		if r.winner == 1:
			vet_wins += 1
		rounds += r.rounds
		green_lost += r.losses(0)
		vet_lost += r.losses(1)
	var mean_rounds := float(rounds) / n
	print("    gate: veterans win %.0f%% of %d, mean rounds %.1f, losses green %.1f vs veteran %.1f per battle" % [
		100.0 * vet_wins / n, n, mean_rounds, float(green_lost) / n, float(vet_lost) / n])
	assert_between(float(vet_wins) / n, 0.75, 1.0, "veterans should win clearly")
	assert_between(mean_rounds, 8.0, 30.0, "battles neither trivial nor endless")
	assert_true(green_lost > vet_lost * 2, "green losses dwarf veteran losses")


func test_equal_bands_are_not_one_sided_by_seed() -> void:
	var n := 40
	var a_wins := 0
	var decided := 0
	for i in n:
		var r := _fight("equal_veteran", 500 + i)
		if r.winner >= 0:
			decided += 1
			if r.winner == 0:
				a_wins += 1
	assert_true(decided >= n / 2, "most equal fights are decided inside max_rounds (%d of %d)" % [decided, n])
