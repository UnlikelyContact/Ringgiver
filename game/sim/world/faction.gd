class_name Faction
extends RefCounted
## A petty kingdom, jarldom, chieftains' league or town on the map: who leads
## it, what it holds, how many men it can field, what it wants and how it
## stands toward the others and toward the band. Stored in World.factions.

var id := ""
var name := ""
var leader := ""
var kind: WorldTypes.FactionKind = WorldTypes.FactionKind.CHIEFTAINS
var holdings: Array[String] = []
## Men it can field (hird plus levy).
var strength := 0
## "expand" | "hold" | "trade"
var ambition := "hold"
## faction id -> int (-100..100); "band" -> int toward the band.
var relations := {}
var alive := true
## Factions it is allied with (FactionAI keeps this).
var allies: Array[String] = []
## Who swallowed it, once it is no longer alive.
var absorbed_by := ""


## Reads NorwayData.FACTIONS into world.factions and makes every holding's
## place point at its faction.
static func load_all(world: World) -> void:
	world.factions.clear()
	for d in NorwayData.FACTIONS:
		var f := Faction.new()
		f.id = d.id
		f.name = d.name
		f.leader = d.leader
		f.kind = d.kind
		for h in d.holdings:
			f.holdings.append(h)
			var p := world.place(h)
			if p != null:
				p.faction_id = f.id
		f.strength = d.strength
		f.ambition = d.ambition
		f.relations = (d.relations as Dictionary).duplicate()
		world.factions[f.id] = f


func holds(place_id: String) -> bool:
	return holdings.has(place_id)


func describe() -> String:
	return "%s under %s: %d men, %d holdings, %s%s" % [name, leader, strength, holdings.size(), ambition,
			"" if alive else " (absorbed by %s)" % absorbed_by]
