class_name Ship
extends RefCounted
## The band's ship. Size sets crew and cargo (concept.md, Ships).

var kind: WorldTypes.ShipKind = WorldTypes.ShipKind.KARVE
var damage := 0


static func make(p_kind: WorldTypes.ShipKind) -> Ship:
	var s := Ship.new()
	s.kind = p_kind
	return s


func crew_capacity(rules: WorldRules) -> int:
	return rules.ship_crew[kind]


func cargo_capacity(rules: WorldRules) -> int:
	return rules.ship_cargo[kind]


func can_sail(rules: WorldRules) -> bool:
	return damage < rules.ship_unsailable_damage


func describe() -> String:
	return "%s, damage %d" % [WorldTypes.SHIP_NAMES[kind], damage]
