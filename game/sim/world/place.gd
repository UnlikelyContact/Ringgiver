class_name Place
extends RefCounted
## One place on the map: a farm, a hall, a town, a Thing site, a fort or a
## bay. Wealth, defenses and alertness change with what happens there.

var id := ""
var display_name := ""
var region: WorldTypes.Region = WorldTypes.Region.VIKEN
var kind: WorldTypes.PlaceKind = WorldTypes.PlaceKind.FARMSTEAD
var pos := Vector2.ZERO
var wealth := 30
## What the place is worth left in peace: it mends toward this each year.
var base_wealth := 30
var defenses := 1
var alertness := 0
var faction_id := ""
## The ruling family, for feuds.
var family := ""
var has_market := false
## Good -> units in stock (markets only; farms hold grain).
var stock := {}
## Year from which the place exists on the map (Iceland opens in 874).
var open_year := 0
## Captives sold here this year, for the glut rule.
var captives_sold := 0


func is_open(year: int) -> bool:
	return year >= open_year


func describe() -> String:
	return "%s (%s, %s): wealth %d, defenses %d, alertness %d, %s" % [
		display_name, WorldTypes.PLACE_KIND_NAMES[kind], WorldTypes.REGION_NAMES[region],
		wealth, defenses, alertness, faction_id]
