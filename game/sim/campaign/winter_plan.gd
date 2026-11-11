class_name WinterPlan
extends RefCounted
## What the player (or AI) chose for one winter turn.

var tasks := {}  # man id -> CampaignTypes.Task
var drill_stat := {}  # man id -> CombatTypes.Stat (for DRILL)
var drill_shape := ""  # the learned shape the drilling men practise ("" none)
var feast := false  # Yule only
var vow := ""  # Yule only, "" for none
var gifts := {}  # man id -> ounces (Yule)


func task_for(id: int) -> CampaignTypes.Task:
	return tasks.get(id, CampaignTypes.Task.IDLE)
