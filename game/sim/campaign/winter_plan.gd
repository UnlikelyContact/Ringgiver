class_name WinterPlan
extends RefCounted
## What the player (or AI) chose for one winter turn.

var tasks := {}  # man id -> CampaignTypes.Task
var drill_stat := {}  # man id -> CombatTypes.Stat (for DRILL)
var drill_shape := ""  # the learned shape the drilling men practise ("" none)
var feast := false  # Yule only
var vow := ""  # Yule only, "" for none
var gifts := {}  # man id -> ounces (Yule)
## The winter the player plays (WinterHall) settles these itself: whether
## visitors and troubles are drawn this turn (they were met in the hall's
## talk instead), rations the host's board gives each turn (a lord who
## takes the band in feeds it), and a camp in the wilds (cold, no benches).
var events := true
var host_rations := 0
var cold := false


func task_for(id: int) -> CampaignTypes.Task:
	return tasks.get(id, CampaignTypes.Task.IDLE)
