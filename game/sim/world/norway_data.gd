class_name NorwayData
extends RefCounted
## The map: places, sea lanes and factions of Norway and its near neighbours
## around 866. Positions are in leagues, x east and y south, for display
## only; lanes give days directly. Loaded by World.build_norway.

const R := WorldTypes.Region
const K := WorldTypes.PlaceKind

const PLACES := [
	# Viken and the Opplands
	{"id": "kaupang", "name": "Kaupang", "region": R.VIKEN, "kind": K.TOWN, "pos": Vector2(60, 70), "wealth": 70, "defenses": 4, "faction": "harald", "family": "the Ynglings", "market": true},
	{"id": "borre", "name": "Borre", "region": R.VIKEN, "kind": K.HALL, "pos": Vector2(58, 66), "wealth": 50, "defenses": 5, "faction": "harald", "family": "the Ynglings"},
	{"id": "lier", "name": "the Lier farms", "region": R.VIKEN, "kind": K.FARMSTEAD, "pos": Vector2(55, 60), "wealth": 30, "defenses": 1, "faction": "harald", "family": "Lier-Bjorn's kin"},
	{"id": "eidsvoll", "name": "Eidsvoll Thing", "region": R.VIKEN, "kind": K.THING_SITE, "pos": Vector2(62, 52), "wealth": 10, "defenses": 2, "faction": "harald", "family": "the Ynglings"},
	# Agder
	{"id": "agder_farms", "name": "the Agder farms", "region": R.AGDER, "kind": K.FARMSTEAD, "pos": Vector2(40, 78), "wealth": 25, "defenses": 1, "faction": "agder", "family": "Kjotve's kin"},
	{"id": "lindesnes", "name": "Lindesnes", "region": R.AGDER, "kind": K.BAY, "pos": Vector2(36, 80), "wealth": 0, "defenses": 0, "faction": "agder", "family": "Kjotve's kin"},
	# Rogaland
	{"id": "jaeren", "name": "the Jæren farms", "region": R.ROGALAND, "kind": K.FARMSTEAD, "pos": Vector2(26, 70), "wealth": 35, "defenses": 1, "faction": "rogaland", "family": "Thorir Long-chin's kin"},
	{"id": "hafrsfjord", "name": "Hafrsfjord", "region": R.ROGALAND, "kind": K.BAY, "pos": Vector2(25, 66), "wealth": 0, "defenses": 0, "faction": "rogaland", "family": "Eirik of Hordaland's kin"},
	{"id": "avaldsnes", "name": "Avaldsnes", "region": R.ROGALAND, "kind": K.HALL, "pos": Vector2(24, 60), "wealth": 60, "defenses": 6, "faction": "rogaland", "family": "Augvald's kin"},
	# Hordaland
	{"id": "gulathing", "name": "the Gulathing", "region": R.HORDALAND, "kind": K.THING_SITE, "pos": Vector2(24, 48), "wealth": 10, "defenses": 2, "faction": "hordaland", "family": "Horda-Kari's kin"},
	{"id": "fitjar", "name": "Fitjar", "region": R.HORDALAND, "kind": K.HALL, "pos": Vector2(23, 54), "wealth": 55, "defenses": 5, "faction": "hordaland", "family": "Horda-Kari's kin"},
	{"id": "hardanger", "name": "the Hardanger farms", "region": R.HORDALAND, "kind": K.FARMSTEAD, "pos": Vector2(30, 54), "wealth": 30, "defenses": 1, "faction": "hordaland", "family": "Hardanger-Atli's kin"},
	# Sogn
	{"id": "sogn_hall", "name": "Sogndal", "region": R.SOGN, "kind": K.HALL, "pos": Vector2(30, 44), "wealth": 45, "defenses": 4, "faction": "sogn", "family": "the Sygna kings"},
	{"id": "sogn_farms", "name": "the Sogn farms", "region": R.SOGN, "kind": K.FARMSTEAD, "pos": Vector2(27, 42), "wealth": 25, "defenses": 1, "faction": "sogn", "family": "Ulfar's kin"},
	# Møre
	{"id": "giske", "name": "Giske", "region": R.MORE, "kind": K.HALL, "pos": Vector2(30, 32), "wealth": 50, "defenses": 5, "faction": "more", "family": "Rognvald's kin"},
	{"id": "more_farms", "name": "the Møre farms", "region": R.MORE, "kind": K.FARMSTEAD, "pos": Vector2(34, 30), "wealth": 30, "defenses": 1, "faction": "more", "family": "Hrafn's kin"},
	# Trøndelag
	{"id": "lade", "name": "Lade", "region": R.TRONDELAG, "kind": K.HALL, "pos": Vector2(46, 22), "wealth": 65, "defenses": 6, "faction": "lade", "family": "the Lade jarls", "market": true},
	{"id": "frostathing", "name": "the Frostathing", "region": R.TRONDELAG, "kind": K.THING_SITE, "pos": Vector2(48, 20), "wealth": 10, "defenses": 2, "faction": "lade", "family": "the Lade jarls"},
	{"id": "trondelag_farms", "name": "the Trøndelag farms", "region": R.TRONDELAG, "kind": K.FARMSTEAD, "pos": Vector2(50, 24), "wealth": 40, "defenses": 2, "faction": "lade", "family": "the Trønder chieftains"},
	# Hålogaland
	{"id": "bjarkoy", "name": "Bjarkøy", "region": R.HALOGALAND, "kind": K.HALL, "pos": Vector2(62, 0), "wealth": 40, "defenses": 3, "faction": "halogaland", "family": "the Bjarkøy chieftains", "market": true},
	{"id": "halogaland_farms", "name": "the Hålogaland farms", "region": R.HALOGALAND, "kind": K.FARMSTEAD, "pos": Vector2(58, 4), "wealth": 20, "defenses": 1, "faction": "halogaland", "family": "the Bjarkøy chieftains"},
	{"id": "lofoten", "name": "the Lofoten fishing-steads", "region": R.HALOGALAND, "kind": K.FARMSTEAD, "pos": Vector2(54, 6), "wealth": 25, "defenses": 0, "faction": "halogaland", "family": "the Lofoten fishers"},
	# Denmark, Sweden, the Baltic
	{"id": "hedeby", "name": "Hedeby", "region": R.DENMARK, "kind": K.TOWN, "pos": Vector2(60, 110), "wealth": 90, "defenses": 7, "faction": "danes", "family": "the Danish king's men", "market": true},
	{"id": "ribe", "name": "Ribe", "region": R.DENMARK, "kind": K.TOWN, "pos": Vector2(50, 106), "wealth": 70, "defenses": 5, "faction": "danes", "family": "the Danish king's men", "market": true},
	{"id": "birka", "name": "Birka", "region": R.SWEDEN, "kind": K.TOWN, "pos": Vector2(110, 60), "wealth": 80, "defenses": 6, "faction": "svear", "family": "the Uppsala kings", "market": true},
	{"id": "gotland", "name": "Gotland", "region": R.BALTIC, "kind": K.TOWN, "pos": Vector2(112, 80), "wealth": 60, "defenses": 4, "faction": "gotlanders", "family": "the Gotland farmers", "market": true},
	# The west
	{"id": "orkney", "name": "Orkney", "region": R.WEST, "kind": K.HALL, "pos": Vector2(0, 50), "wealth": 40, "defenses": 3, "faction": "orkney", "family": "the Orkney jarls"},
	{"id": "dublin", "name": "Dublin", "region": R.WEST, "kind": K.TOWN, "pos": Vector2(-30, 80), "wealth": 85, "defenses": 7, "faction": "dublin_norse", "family": "Ivar's kin", "market": true},
	# The raider's prey: rich, and no king's levy near.
	{"id": "iona", "name": "the monastery on Iona", "region": R.WEST, "kind": K.FARMSTEAD, "pos": Vector2(-16, 62), "wealth": 75, "defenses": 0, "faction": "", "family": "the monks of Iona"},
	{"id": "northumbria", "name": "the Northumbrian coast", "region": R.WEST, "kind": K.FARMSTEAD, "pos": Vector2(8, 74), "wealth": 60, "defenses": 1, "faction": "", "family": "the Northumbrians"},
	# Frankia: the host on the Seine, where Rollo goes in his exile, and
	# Rouen up the river (law-land).
	{"id": "seine", "name": "the camp on the Seine", "region": R.FRANKIA, "kind": K.HALL, "pos": Vector2(2, 106), "wealth": 35, "defenses": 4, "faction": "seine", "family": "the Seine host"},
	{"id": "rouen", "name": "Rouen", "region": R.FRANKIA, "kind": K.TOWN, "pos": Vector2(12, 110), "wealth": 80, "defenses": 5, "faction": "", "family": "the Franks of the Seine"},
	{"id": "iceland", "name": "the Iceland land-take", "region": R.ICELAND, "kind": K.FARMSTEAD, "pos": Vector2(-40, 10), "wealth": 10, "defenses": 0, "faction": "", "family": "Ingolf's kin", "open_year": 874},
]

## Rough shores, in the map's leagues (x east, y south): what is land. The
## free-roam map (MapGrid) is cut from these, with a fjord carved in to
## every place that would otherwise stand away from the water.
const SHORES := [
	# Norway and the Swedish lands
	[Vector2(36, 83), Vector2(30, 77), Vector2(24, 73), Vector2(21, 65), Vector2(20, 56), Vector2(21, 48), Vector2(24, 42),
		Vector2(25, 36), Vector2(27, 30), Vector2(33, 26), Vector2(41, 21), Vector2(45, 17), Vector2(51, 10), Vector2(55, 3),
		Vector2(59, -4), Vector2(66, -7), Vector2(74, -5), Vector2(80, 4), Vector2(86, 16), Vector2(92, 30), Vector2(98, 42),
		Vector2(106, 52), Vector2(111, 60), Vector2(110, 68), Vector2(104, 76), Vector2(97, 82), Vector2(91, 91), Vector2(84, 96),
		Vector2(78, 91), Vector2(73, 83), Vector2(68, 76), Vector2(65, 68), Vector2(63, 61), Vector2(61, 64), Vector2(62, 72),
		Vector2(57, 77), Vector2(49, 81), Vector2(42, 82)],
	# Jutland
	[Vector2(47, 101), Vector2(53, 97), Vector2(60, 99), Vector2(64, 105), Vector2(66, 113), Vector2(60, 119), Vector2(52, 119), Vector2(46, 111)],
	# Britain
	[Vector2(-7, 57), Vector2(1, 55), Vector2(6, 61), Vector2(10, 71), Vector2(14, 81), Vector2(12, 97), Vector2(0, 101),
		Vector2(-8, 91), Vector2(-12, 77), Vector2(-13, 66)],
	# Ireland
	[Vector2(-37, 72), Vector2(-28, 70), Vector2(-24, 78), Vector2(-26, 89), Vector2(-35, 93), Vector2(-41, 84)],
	# Iceland
	[Vector2(-51, 6), Vector2(-41, 2), Vector2(-30, 6), Vector2(-32, 14), Vector2(-44, 17)],
	# The Frankish shore, from the Breton capes to the Frisian sands (law-land:
	# the Seine and Rouen stand on it)
	[Vector2(-14, 108), Vector2(-2, 105), Vector2(8, 104), Vector2(20, 106), Vector2(34, 108), Vector2(42, 113),
		Vector2(42, 126), Vector2(-14, 126)],
	# Gotland
	[Vector2(110, 76), Vector2(113, 77), Vector2(114, 83), Vector2(111, 85), Vector2(109, 81)],
]

## [from, to, days, open_sea]
const LANES := [
	["kaupang", "borre", 1, false], ["borre", "lier", 1, false], ["kaupang", "eidsvoll", 2, false],
	["kaupang", "agder_farms", 4, false], ["agder_farms", "lindesnes", 1, false],
	["lindesnes", "jaeren", 3, false], ["jaeren", "hafrsfjord", 1, false], ["hafrsfjord", "avaldsnes", 1, false],
	["avaldsnes", "fitjar", 2, false], ["fitjar", "gulathing", 1, false], ["fitjar", "hardanger", 1, false],
	["gulathing", "sogn_hall", 2, false], ["sogn_hall", "sogn_farms", 1, false], ["sogn_hall", "giske", 3, false],
	["giske", "more_farms", 1, false], ["giske", "lade", 3, false], ["lade", "frostathing", 1, false],
	["lade", "trondelag_farms", 1, false], ["lade", "bjarkoy", 5, false], ["bjarkoy", "halogaland_farms", 1, false],
	["bjarkoy", "lofoten", 2, false],
	["kaupang", "hedeby", 4, true], ["lindesnes", "ribe", 4, true], ["hedeby", "ribe", 2, false],
	["kaupang", "gotland", 7, true], ["gotland", "birka", 3, true],
	["avaldsnes", "orkney", 4, true], ["giske", "orkney", 5, true], ["orkney", "dublin", 4, true],
	["orkney", "iceland", 7, true],
	["orkney", "iona", 3, true], ["northumbria", "seine", 5, true], ["ribe", "seine", 6, true], ["seine", "rouen", 1, false], ["iona", "dublin", 3, false], ["orkney", "northumbria", 4, true],
]

const FACTIONS := [
	{"id": "harald", "name": "Harald Halfdansson's kingdom", "leader": "Harald Fairhair", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["kaupang", "borre", "lier", "eidsvoll"], "strength": 150, "ambition": "expand",
		"relations": {"more": 60, "lade": 60, "rogaland": -30, "hordaland": -30, "agder": -20, "sogn": -10, "danes": -10}},
	{"id": "agder", "name": "the Agder kings", "leader": "Kjotve the Rich", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["agder_farms", "lindesnes"], "strength": 40, "ambition": "hold", "relations": {"rogaland": 30, "hordaland": 20}},
	{"id": "rogaland", "name": "the Rogaland kings", "leader": "Eirik of Hordaland", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["jaeren", "hafrsfjord", "avaldsnes"], "strength": 70, "ambition": "hold", "relations": {"hordaland": 40, "agder": 30}},
	{"id": "hordaland", "name": "the Hordaland kings", "leader": "Sulke of Rogaland", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["fitjar", "gulathing", "hardanger"], "strength": 60, "ambition": "hold", "relations": {"rogaland": 40, "sogn": 20}},
	{"id": "sogn", "name": "the Sygna kings", "leader": "Atli the Slender", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["sogn_hall", "sogn_farms"], "strength": 40, "ambition": "hold", "relations": {"hordaland": 20, "more": -10}},
	{"id": "more", "name": "the Møre jarldom", "leader": "Rognvald Eysteinsson", "kind": WorldTypes.FactionKind.JARL,
		"holdings": ["giske", "more_farms"], "strength": 50, "ambition": "hold", "relations": {"harald": 60, "lade": 30}},
	{"id": "lade", "name": "the Lade jarls", "leader": "Hakon Grjotgardsson", "kind": WorldTypes.FactionKind.JARL,
		"holdings": ["lade", "frostathing", "trondelag_farms"], "strength": 80, "ambition": "hold", "relations": {"harald": 60, "more": 30}},
	{"id": "halogaland", "name": "the Hålogaland chieftains", "leader": "Ohthere's kin", "kind": WorldTypes.FactionKind.CHIEFTAINS,
		"holdings": ["bjarkoy", "halogaland_farms", "lofoten"], "strength": 30, "ambition": "trade", "relations": {"lade": 20}},
	{"id": "danes", "name": "the Danish kings", "leader": "Horik's heirs", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["hedeby", "ribe"], "strength": 300, "ambition": "trade", "relations": {"harald": -10, "svear": -20}},
	{"id": "svear", "name": "the Uppsala kings", "leader": "Bjorn at Haugi", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["birka"], "strength": 200, "ambition": "hold", "relations": {"danes": -20, "gotlanders": 10}},
	{"id": "gotlanders", "name": "the Gotland farmers", "leader": "the Gotland Thing", "kind": WorldTypes.FactionKind.TOWN,
		"holdings": ["gotland"], "strength": 50, "ambition": "trade", "relations": {"svear": 10}},
	{"id": "orkney", "name": "the Orkney jarls", "leader": "Sigurd the Mighty", "kind": WorldTypes.FactionKind.JARL,
		"holdings": ["orkney"], "strength": 40, "ambition": "hold", "relations": {"more": 40, "dublin_norse": 10}},
	{"id": "seine", "name": "the host on the Seine", "leader": "Weland", "kind": WorldTypes.FactionKind.JARL,
		"holdings": ["seine"], "strength": 40, "ambition": "hold", "relations": {"danes": 10}},
	{"id": "dublin_norse", "name": "the Norse of Dublin", "leader": "Ivar's sons", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["dublin"], "strength": 120, "ambition": "trade", "relations": {"orkney": 10}},
]

## The houses the western sagas are about (Families), by the name the
## places carry. `heir` is the son who follows the head; `strength` the men
## the house can put in the field; `creditor` a house the others owe. Every
## other place's family is made a house too, its head and temper drawn
## from the seed (Families.build).
const HOUSES := [
	{"name": "Augvald's kin", "seat": "avaldsnes", "head": "Augvald", "heir": "Ragnvald", "age": 52, "strength": 24, "wealth": 60,
		"temper": "proud", "honor": 60},
	{"name": "Thorir Long-chin's kin", "seat": "jaeren", "head": "Thorir Long-chin", "heir": "Ozur", "age": 44, "strength": 12, "wealth": 35,
		"temper": "grasping", "honor": 40},
	{"name": "Eirik of Hordaland's kin", "seat": "hafrsfjord", "head": "Eirik", "heir": "Thorgils", "age": 48, "strength": 10, "wealth": 30,
		"temper": "steadfast", "honor": 55},
	{"name": "Horda-Kari's kin", "seat": "fitjar", "head": "Horda-Kari", "heir": "Thorleif the Wise", "age": 61, "strength": 20, "wealth": 70,
		"temper": "steadfast", "honor": 70, "creditor": true},
	{"name": "Hardanger-Atli's kin", "seat": "hardanger", "head": "Atli", "heir": "Grjotgard", "age": 50, "strength": 14, "wealth": 40,
		"temper": "grasping", "honor": 35},
	{"name": "the Sygna kings", "seat": "sogn_hall", "head": "Atli the Slender", "heir": "Hallvard", "age": 46, "strength": 18, "wealth": 45,
		"temper": "proud", "honor": 55},
	{"name": "Ulfar's kin", "seat": "sogn_farms", "head": "Ulfar", "heir": "Kolbein", "age": 58, "strength": 8, "wealth": 25,
		"temper": "steadfast", "honor": 60},
	{"name": "Rognvald's kin", "seat": "giske", "head": "Rognvald", "heir": "Thorir the Silent", "age": 40, "strength": 22, "wealth": 50,
		"temper": "proud", "honor": 60},
	{"name": "Hrafn's kin", "seat": "more_farms", "head": "Hrafn", "heir": "Onund", "age": 55, "strength": 7, "wealth": 30,
		"temper": "peaceable", "honor": 65},
]

## The web the sagas begin in: [a, b, kind] with kind kin, marriage,
## foster, friend (sworn friendship), debt (a owes b), grudge or feud. A
## feud carries its ledger: killings by each side and the step it has
## reached (WorldRules.house_feud_steps). Hardanger-Atli's kin, who burned
## the hall of the burned-hall origin and hold for Harald, have Møre and
## Jæren with them; Ulfar's kin in Sogn, who shelter the burned man, have a
## grudge against them that is older than the burning. Hrafn's kin of the
## Møre farms stand alone.
const HOUSE_TIES := [
	["Augvald's kin", "Rognvald's kin", "feud", {"kills_a": 2, "kills_b": 1, "step": 2, "since": 858}],
	["Thorir Long-chin's kin", "Eirik of Hordaland's kin", "feud", {"kills_a": 1, "kills_b": 0, "step": 1, "since": 863}],
	["Ulfar's kin", "Hardanger-Atli's kin", "grudge", {}],
	["Horda-Kari's kin", "Hardanger-Atli's kin", "grudge", {}],
	["Hardanger-Atli's kin", "Rognvald's kin", "marriage", {}],
	["Augvald's kin", "the Sygna kings", "marriage", {}],
	["Horda-Kari's kin", "Eirik of Hordaland's kin", "marriage", {}],
	["Augvald's kin", "Eirik of Hordaland's kin", "kin", {}],
	["Ulfar's kin", "the Sygna kings", "kin", {}],
	["the Sygna kings", "Horda-Kari's kin", "foster", {}],
	["Hardanger-Atli's kin", "Thorir Long-chin's kin", "friend", {}],
	["Rognvald's kin", "the Orkney jarls", "kin", {}],
	["Rognvald's kin", "the Lade jarls", "friend", {}],
	["the Ynglings", "the Lade jarls", "friend", {}],
	["Thorir Long-chin's kin", "Horda-Kari's kin", "debt", {}],
	["the Sygna kings", "Horda-Kari's kin", "debt", {}],
	["Hardanger-Atli's kin", "Horda-Kari's kin", "debt", {}],
	["Ulfar's kin", "Horda-Kari's kin", "debt", {}],
]

## Names for the heads and heirs of houses the data does not name, and for
## the daughters offered in marriage.
const HOUSE_MEN := ["Bard", "Eyvind", "Thorstein", "Hauk", "Gudbrand", "Skeggi", "Arnfinn", "Vemund", "Ketil", "Ottar",
	"Sigurd", "Hogni", "Brand", "Einar", "Grim", "Thorkel", "Hallstein", "Asbjorn", "Bersi", "Ozur"]
const HOUSE_WOMEN := ["Thora", "Gunnhild", "Ragnhild", "Asa", "Bergljot", "Thorgerd", "Ingibjorg", "Hallgerd", "Gudrun", "Sigrid"]
