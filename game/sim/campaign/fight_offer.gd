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
##   BURN            ring their hall by night and burn them in
##                   (Scenario.build_hall_burning): only at the seat of a
##                   house the band is at feud with (`can_burn`).
## If `they_know_first`, the choice is not yours: you are the column.
##
## At your own hall (`ground` "hall", the winter's feud attacks and
## burnings) the same choices are the hall's: TAKE_THE_FIELD is going out
## to meet them in the yard, WAIT_FOR_THEM barring the door and holding the
## yard, LAY_AMBUSH lying in wait at the gate when the scout warned you.
## At the Thing (`ground` "thing") there is only standing to fight.

enum Choice { TAKE_THE_FIELD, WAIT_FOR_THEM, LAY_AMBUSH, FADE_AWAY, BURN }
const CHOICE_NAMES := ["take the field", "wait for them", "lay an ambush", "fade away", "burn them in"]
const CHOICE_TITLES := ["Take the field", "Wait for them", "Lay an ambush", "Fade away", "Burn them in by night"]

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
## What the fight is about, from the map (Journey._offer_fight's ctx kind):
## "raid", "defend" (a steading's farmers with you), "thieves", "rob",
## "feud", "thing", "reckoning", "hall" ... It chooses the objective
## (Campaign.stake). "" for the old callers: the field as before.
var cause := ""
## The house the enemy's men belong to ("" for raiders, outlaws and the
## like): an oath-brother's vengeance is opened against it (Bonds.on_death).
var house := ""
## The band's own ship lies here (on the strand): what the enemy will make for.
var ships_here := false
## At the seat of a house at feud: the burning may be chosen.
var can_burn := false
## At your own hall: they come with fire (the winter's hall-burning).
var burning := false
## What each choice's fight is over, in a line (Campaign.stake): choice ->
## text, "" for an open fight.
var stakes := {}

const GROUND_TEXT := {"sea": "You are aboard, and they will come at you where the ships lie.",
	"strand": "You are on open sand, with nothing to put at your back.",
	"farm": "You are at a steading, with a hall to hold.",
	"open": "You are in the low country, by a ford and a road.",
	"hills": "You are in the hills, where the ground is steep and the ways narrow.",
	"hall": "It is night, and your hall is at your back.",
	"thing": "It is at the Thing, among the booths."}


func options() -> Array[int]:
	var out: Array[int] = []
	if they_know_first:
		return out  # no choice: they have you
	out.append(Choice.TAKE_THE_FIELD)
	if ground == "thing":
		return out  # a brawl among the booths: stand and fight
	if ground == "hall":
		out.append(Choice.WAIT_FOR_THEM)  # bar the door and hold the yard
		if we_know_first:
			out.append(Choice.LAY_AMBUSH)  # lie in wait at the gate
		return out
	if can_burn:
		out.append(Choice.BURN)
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
		Choice.BURN:
			return "burning"
		_:
			return "equal_green"


## What a choice is called here, by the ground (the HUD and the map's
## decision list): "Hold the high ground", "Lie in wait by the road".
func title(choice: int) -> String:
	if ground == "hall":
		match choice:
			Choice.TAKE_THE_FIELD:
				return "Out, and meet them in the yard"
			Choice.WAIT_FOR_THEM:
				return "Bar the door and hold the walls" if burning else "Bar the door and hold the yard"
			Choice.LAY_AMBUSH:
				return "Lie in wait at the gate"
	if ground == "thing" and choice == Choice.TAKE_THE_FIELD:
		return "Stand and fight"
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
	var over := str(stakes.get(Choice.TAKE_THE_FIELD, ""))
	if over != "" and not they_know_first:
		text += " " + over + "."
	if they_know_first:
		return text + " They have seen you first: you are caught on the march."
	if we_know_first:
		return text + " Your scout saw them first."
	return text
