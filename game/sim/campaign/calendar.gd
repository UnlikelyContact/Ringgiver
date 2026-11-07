class_name Calendar
extends RefCounted
## Year and season. Summer is continuous for the map; winter is four turns.

var year := 866
var season: CampaignTypes.Season = CampaignTypes.Season.SUMMER
var winter_turn: CampaignTypes.WinterTurn = CampaignTypes.WinterTurn.EARLY


func _init(p_year := 866) -> void:
	year = p_year


func is_winter() -> bool:
	return season == CampaignTypes.Season.WINTER


func start_winter() -> void:
	season = CampaignTypes.Season.WINTER
	winter_turn = CampaignTypes.WinterTurn.EARLY


## Moves to the next winter turn; after the thaw, starts the next year's summer.
func advance_turn() -> void:
	if not is_winter():
		start_winter()
		return
	if winter_turn == CampaignTypes.WinterTurn.THAW:
		next_year()
	else:
		winter_turn = (winter_turn + 1) as CampaignTypes.WinterTurn


func next_year() -> void:
	year += 1
	season = CampaignTypes.Season.SUMMER
	winter_turn = CampaignTypes.WinterTurn.EARLY


func describe() -> String:
	if is_winter():
		return "%d, %s" % [year, CampaignTypes.WINTER_TURN_NAMES[winter_turn]]
	return "%d, summer" % year
