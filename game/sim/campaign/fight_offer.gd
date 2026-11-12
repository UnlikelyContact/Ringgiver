class_name FightOffer
extends RefCounted
## A fight before it is fought: what the world knows, what the scout says,
## and the choices the leader has (concept.md, "Picking your fights"). The
## campaign makes one for every battle request (Campaign.offer_fight), a
## policy or the player picks a choice, and Campaign.resolve_offer fights
## it, or does not. The prototype's HUD shows the same before round one.
##
## Choices:
##   TAKE_THE_FIELD  fight as the world dealt it: the open field.
##   WAIT_FOR_THEM   choose the ground and let them come: the river, your
##                   line on the bank, and they must come through the ford.
##                   Only when they are coming to you (not your attack) and
##                   not at sea.
##   LAY_AMBUSH      your scout saw them first: they are on the march and
##                   you are in the trees. Only on land, when `we_know_first`.
##   FADE_AWAY       decline: no fight, and it costs honor, not luck. Not
##                   when `cornered` (your hall burning, a brawl at the
##                   Thing, a levy that has you).
## If `they_know_first`, the choice is not yours: you are the column.

enum Choice { TAKE_THE_FIELD, WAIT_FOR_THEM, LAY_AMBUSH, FADE_AWAY }
const CHOICE_NAMES := ["take the field", "wait for them", "lay an ambush", "fade away"]
const CHOICE_TITLES := ["Take the field", "Wait for them", "Lay an ambush", "Fade away"]

var kind := ""
var enemy_size := 0
var enemy_tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
var enemy_shields := 0
var enemy_spears := 0
var enemy_bows := 0
var enemy_leader := ""
var doctrine: LeaderAI.Doctrine = LeaderAI.Doctrine.STEADY
## Who comes to whom: true when the fight is your doing (a raid, a robbery).
var attacking := true
var at_sea := false
var cornered := false
var we_know_first := false
var they_know_first := false
var stat_center := -1
var seed_value := 0
## Your own fighting men, and the odds a careful leader will take (the
## scout's worst count over his men): set by the campaign for its policy.
var our_men := 0
var odds_max := 1.2
## The scout's report (Scouting.report), filled by the campaign.
var report := {}
## The ground under the band where the fight finds it (from the map, by
## Journey): "" (not known: the old drawn field), "sea" (aboard: they
## close and it is fought out on the strand by the ships), "strand" (open
## sand: no cover, nowhere better to stand), "farm" (a steading: the hall
## to hold), "open" (low country: a ford to wait at, a road to lie in
## wait by), "hills" (the uplands: high ground to hold, narrows to wait
## in). It decides which choices there are and the field each makes
## (Campaign.build_fight).
var ground := ""

const GROUND_TEXT := {"sea": "You are aboard, and they will come at you where the ships lie.",
	"strand": "You are on open sand, with nothing to put at your back.",
	"farm": "You are at a steading, with a hall to hold.",
	"open": "You are in the low country, by a ford and a road.",
	"hills": "You are in the hills, where the ground is steep and the ways narrow."}


func options() -> Array[int]:
	var out: Array[int] = []
	if they_know_first:
		return out  # no choice: they have you
	out.append(Choice.TAKE_THE_FIELD)
	# Open sand has no ground worth choosing and nowhere to hide.
	var bare := ground == "strand" or ground == "sea"
	if not attacking and not at_sea and not bare:
		out.append(Choice.WAIT_FOR_THEM)
	if we_know_first and not at_sea and not bare:
		out.append(Choice.LAY_AMBUSH)
	if not cornered:
		out.append(Choice.FADE_AWAY)
	return out


func allows(choice: int) -> bool:
	return options().has(choice)


## The scenario name Scenario.build takes for a choice.
func scenario_for(choice: int) -> String:
	if they_know_first:
		return "ambushed"
	match choice:
		Choice.WAIT_FOR_THEM:
			return "hold"
		Choice.LAY_AMBUSH:
			return "ambush"
		_:
			return "equal_green"


## What a choice is called here, by the ground (the HUD and the map's
## decision list): "Hold the high ground", "Lie in wait by the road".
func title(choice: int) -> String:
	match choice:
		Choice.WAIT_FOR_THEM:
			match ground:
				"hills":
					return "Hold the high ground"
				"farm":
					return "Hold the hall"
				"open":
					return "Wait for them at the ford"
		Choice.LAY_AMBUSH:
			match ground:
				"hills":
					return "Wait for them in the narrows"
				"open", "farm":
					return "Lie in wait by the road"
	return CHOICE_TITLES[choice]


## A line for the log or the HUD: what is coming, as the scout tells it.
func brief() -> String:
	var text: String = report.get("text", "")
	if GROUND_TEXT.has(ground):
		text += " " + str(GROUND_TEXT[ground])
	if they_know_first:
		return text + " They have seen you first: you are caught on the march."
	if we_know_first:
		return text + " Your scout saw them first."
	return text
