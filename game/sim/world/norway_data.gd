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
	{"id": "sogn_farms", "name": "the Sogn farms", "region": R.SOGN, "kind": K.FARMSTEAD, "pos": Vector2(27, 42), "wealth": 25, "defenses": 1, "faction": "sogn", "family": "the Sygna kings"},
	# Møre
	{"id": "giske", "name": "Giske", "region": R.MORE, "kind": K.HALL, "pos": Vector2(30, 32), "wealth": 50, "defenses": 5, "faction": "more", "family": "Rognvald's kin"},
	{"id": "more_farms", "name": "the Møre farms", "region": R.MORE, "kind": K.FARMSTEAD, "pos": Vector2(34, 30), "wealth": 30, "defenses": 1, "faction": "more", "family": "Rognvald's kin"},
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
	{"id": "iceland", "name": "the Iceland land-take", "region": R.ICELAND, "kind": K.FARMSTEAD, "pos": Vector2(-40, 10), "wealth": 10, "defenses": 0, "faction": "", "family": "", "open_year": 874},
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
	["orkney", "iona", 3, true], ["iona", "dublin", 3, false], ["orkney", "northumbria", 4, true],
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
	{"id": "dublin_norse", "name": "the Norse of Dublin", "leader": "Ivar's sons", "kind": WorldTypes.FactionKind.KING,
		"holdings": ["dublin"], "strength": 120, "ambition": "trade", "relations": {"orkney": 10}},
]
