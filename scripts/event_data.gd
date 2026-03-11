class_name EventData
extends RefCounted

## Data class defining a single event scenario.

var id: String
var title: String
var description: String
var choices: Array  # Array of Dictionaries: {text, outcomes, probability}
var act_filter: Array[int]  # Which acts this can appear in (empty = all)

func _init(p_id: String, p_title: String, p_description: String, p_choices: Array, p_act_filter: Array[int] = []) -> void:
	id = p_id
	title = p_title
	description = p_description
	choices = p_choices
	act_filter = p_act_filter

func is_available_in_act(act: int) -> bool:
	return act_filter.is_empty() or act in act_filter
