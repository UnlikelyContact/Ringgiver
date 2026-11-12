class_name House
extends RefCounted
## One of the world's families (concept.md, "Feud and wergild",
## "Politics"): a named house with a head, the son who will follow him, a
## seat, men it can field, wealth, a temper and its honor. The class is
## called House because `Family` is the band's own household (marriage,
## births and fostering, sim/campaign/family.gd); in everything the player
## reads it is a family or a house.
##
## A house is known by its `name` ("Augvald's kin"), which is what
## `Place.family`, the band's feuds and the band's standing are keyed by.
## Its ties to other houses live in `Families`, which keeps them symmetric.

## The tempers a house can have: how quickly it climbs a feud and how
## readily a settlement made with it holds (WorldRules, "Families").
const TEMPERS: Array[String] = ["proud", "grasping", "peaceable", "steadfast"]

var name := ""
## The head of the house, and the son who will follow him.
var head := ""
var heir := ""
var head_age := 45
## The place id of its hall or farm, and every place it rules.
var seat := ""
var holdings: Array[String] = []
var region: WorldTypes.Region = WorldTypes.Region.HORDALAND
## Men it can put in the field when it comes to blows.
var strength := 10
var wealth := 30
var temper := "steadfast"
## 0..100: what men say of the house. It falls when its settlements break
## and when it is burned out; it rises when it keeps the peace.
var honor := 50
## A house the others owe: debtors never stand against it at the Thing.
var creditor := false
## Authored as one of the western houses the sagas are about.
var western := false


func describe() -> String:
	return "%s of %s, under %s (%s, %d men, honor %d)" % [name, seat, head, temper, strength, honor]


## What the head is called with his house: "Atli of Hardanger".
func head_title(world: World) -> String:
	var p: Place = world.place(seat) if world != null else null
	return head if p == null else "%s of %s" % [head, p.display_name.trim_prefix("the ").trim_suffix(" farms")]
