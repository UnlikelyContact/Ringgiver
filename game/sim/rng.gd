class_name SimRng
extends RefCounted
## Seeded random source for the simulation.
##
## Every battle, voyage and winter gets its own SimRng, so any of them can be
## replayed exactly from its seed (concept.md, Tech: "Seeded, deterministic
## rolls"). Nothing in sim/ may use the global randi()/randf().

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(seed_in: int = 0) -> void:
	seed_value = seed_in
	_rng.seed = seed_in


func d6() -> int:
	return _rng.randi_range(1, 6)


func roll_2d6() -> int:
	return d6() + d6()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


## Returns a child generator whose seed derives from this one, so sub-systems
## (each man's decision, each exchange) can be reseeded independently.
func fork(label: String) -> SimRng:
	return SimRng.new(hash(str(seed_value) + ":" + label))
